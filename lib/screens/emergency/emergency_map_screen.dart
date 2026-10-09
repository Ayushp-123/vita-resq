import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/emergency_model.dart';
import '../../models/responder_model.dart';
import '../../models/communication_mode.dart';
import '../../models/hospital_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status.dart';
import '../../services/emergency_service.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../../services/hospital_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/responder_reliability_monitor.dart';
import '../../services/local_database_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/app_state_widgets.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/common/app_status_badge.dart';
import '../../widgets/emergency_timeline_widget.dart';
import '../../widgets/responder_profile_card.dart';
import '../../widgets/victim_feedback_dialog.dart';
import '../../widgets/emergency_type_sheet.dart';
import '../../services/impact_reward_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_feedback.dart';
import '../../core/navigation/app_navigator.dart';

class EmergencyMapScreen extends StatefulWidget {
  final String emergencyId;
  final EmergencyModel? initialEmergency;
  final String? currentUserId;

  const EmergencyMapScreen({
    super.key,
    required this.emergencyId,
    this.initialEmergency,
    this.currentUserId,
  });

  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  final LocationService _locationService = LocationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ResponderReliabilityMonitor _reliabilityMonitor = ResponderReliabilityMonitor();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final EmergencyContactsService _contactsService = EmergencyContactsService();

  final MapController _mapController = MapController();

  String get _currentUserId {
    if (widget.currentUserId != null) return widget.currentUserId!;
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? 'offline_user';
    } catch (_) {
      return 'offline_user';
    }
  }

  List<LatLng> _routePolyline = [];
  double _currentDistanceMeters = 0.0;
  String _etaText = '-- min';
  bool _isLocationUpdatesStarted = false;
  CommunicationMode _mode = CommunicationMode.online;
  StreamSubscription<EmergencyModel>? _offlineUpdateSubscription;
  StreamSubscription<Position>? _devicePositionSubscription;
  LatLng? _currentDeviceLatLng;

  // Auto-SMS Fallback state (3-Minute Timeout = 180s)
  Timer? _fallbackSmsTimer;
  bool _smsFallbackTriggered = false;
  int _secondsRemainingForFallback = 180;
  bool _isCallingVictim = false;

  // Route calculation cache
  LatLng? _lastOrigin;
  LatLng? _lastDestination;
  DateTime? _lastRouteFetchTime;
  bool _isFetchingRoute = false;
  bool _hasShownVictimFeedback = false;

  // Dynamic emergency classification override (for immediate feedback)
  String? _overriddenEmergencyType;

  // Hybrid hospital discovery & routing state
  IHospitalService get _hospitalService => HospitalService.instance;
  List<HospitalModel> _nearbyHospitals = [];
  bool _isLoadingHospitals = false;
  String? _lastDiscoveredEmergencyId;
  HospitalModel? _selectedHospital;
  bool _isNavigatingToHospital = false;
  List<LatLng> _hospitalRoutePolyline = [];
  double _hospitalDistanceMeters = 0.0;
  String _hospitalEtaText = '-- min';
  LatLng? _lastHospitalOrigin;
  DateTime? _lastHospitalRouteFetchTime;
  bool _isFetchingHospitalRoute = false;

  @override
  void initState() {
    super.initState();
    try {
      _connectivityService.initialize();
      _mode = _connectivityService.currentMode;
      _connectivityService.modeStream.listen((m) {
        if (mounted) setState(() => _mode = m);
      });
    } catch (_) {}

    // Stream live device GPS hardware updates with 1-meter precision
    try {
      _devicePositionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _currentDeviceLatLng = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (_) {}

    if (!widget.emergencyId.startsWith('JS-OFF-')) {
      try {
        _reliabilityMonitor.startMonitoring(widget.emergencyId);
      } catch (_) {}
    } else {
      // Listen to reactive local updates for offline emergency state sync
      try {
        _offlineUpdateSubscription = LocalDatabaseService.emergencyUpdatesStream.listen((updatedEmergency) {
          if (updatedEmergency.id == widget.emergencyId && mounted) {
            setState(() {});
          }
        });
      } catch (_) {}
    }
  }

  void _handleSafeHomeNavigation(EmergencyModel emergency) {
    try {
      LocalDatabaseService.broadcastUpdate(emergency);
      LocalDatabaseService().saveEmergencyLocally(emergency);
    } catch (_) {}

    final isVictim = emergency.isVictim(_currentUserId);
    final message = isVictim
        ? 'Your emergency is still active. Track your responder from Home.'
        : 'Emergency response is still active. Return to navigation from Home.';
    AppSnackbar.showInfo(context, message);

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      AppNavigator.navigateToHome(context);
    }
  }

  void _checkAndStartFallbackTimer(EmergencyModel emergency, bool isVictim) async {
    if (!isVictim) return;

    if (emergency.isTerminal || emergency.status != EmergencyStatus.SEARCHING) {
      _fallbackSmsTimer?.cancel();
      _fallbackSmsTimer = null;
      return;
    }

    final alreadyDispatched = await EmergencyContactsService.hasDispatchedSmsFallback(emergency.id);
    if (alreadyDispatched) {
      if (mounted && !_smsFallbackTriggered) {
        setState(() {
          _smsFallbackTriggered = true;
          _secondsRemainingForFallback = 0;
        });
      }
      _fallbackSmsTimer?.cancel();
      _fallbackSmsTimer = null;
      return;
    }

    final now = DateTime.now();
    final elapsedSeconds = now.difference(emergency.createdAt).inSeconds;
    final remaining = (180 - elapsedSeconds).clamp(0, 180);

    if (mounted && _secondsRemainingForFallback != remaining) {
      setState(() {
        _secondsRemainingForFallback = remaining;
      });
    }

    if (elapsedSeconds >= 180) {
      _fallbackSmsTimer?.cancel();
      _fallbackSmsTimer = null;
      _dispatchEmergencySMS(emergency, isAuto: true);
      return;
    }

    if (_fallbackSmsTimer == null || !_fallbackSmsTimer!.isActive) {
      _fallbackSmsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (emergency.isTerminal || emergency.status != EmergencyStatus.SEARCHING) {
          timer.cancel();
          _fallbackSmsTimer = null;
          return;
        }

        final currentElapsed = DateTime.now().difference(emergency.createdAt).inSeconds;
        final currentRemaining = (180 - currentElapsed).clamp(0, 180);

        if (currentRemaining > 0) {
          setState(() {
            _secondsRemainingForFallback = currentRemaining;
          });
        } else {
          timer.cancel();
          _fallbackSmsTimer = null;
          setState(() {
            _secondsRemainingForFallback = 0;
          });
          _dispatchEmergencySMS(emergency, isAuto: true);
        }
      });
    }
  }

  void _dispatchEmergencySMS(EmergencyModel emergency, {bool isAuto = false}) async {
    _fallbackSmsTimer?.cancel();
    _fallbackSmsTimer = null;

    if (await EmergencyContactsService.hasDispatchedSmsFallback(emergency.id)) {
      if (mounted) setState(() => _smsFallbackTriggered = true);
      return;
    }

    if (emergency.isTerminal || emergency.status != EmergencyStatus.SEARCHING) {
      return;
    }

    await EmergencyContactsService.markSmsFallbackDispatched(emergency.id);
    if (mounted) setState(() => _smsFallbackTriggered = true);

    bool sent = await _contactsService.sendEmergencySMS(
      latitude: emergency.latitude,
      longitude: emergency.longitude,
      type: _overriddenEmergencyType ?? emergency.type,
    );

    if (mounted) {
      if (sent) {
        AppSnackbar.showSuccess(
          context,
          isAuto
              ? '3-minute rule: Trusted-contact SMS ready to send.'
              : 'Opening SMS app with details & live map for contacts.',
        );
      } else {
        AppSnackbar.showWarning(
          context,
          'No emergency contacts configured. Add contacts in Profile to enable Auto-SMS.',
        );
      }
    }
  }

  void _showWhatsAppFallbackDialog(EmergencyModel emergency) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.emergencyRed),
            SizedBox(width: 8),
            Text('WhatsApp Unavailable', style: AppTypography.subheading),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Could not open WhatsApp for this contact. Ensure WhatsApp is installed on this device and the contact has an active WhatsApp account.',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to open your device SMS composer with emergency details and coordinates instead?',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Note: Standard carrier SMS charges may apply depending on your mobile plan.',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.sms_rounded, size: 16),
            label: const Text('OPEN SMS COMPOSER'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _dispatchEmergencySMS(emergency, isAuto: false);
            },
          ),
        ],
      ),
    );
  }

  void _handleWhatsAppDispatch(EmergencyModel emergency) async {
    List<EmergencyContact> contacts = await _contactsService.getContacts();
    if (!mounted) return;

    if (contacts.isEmpty) {
      AppSnackbar.showWarning(
        context,
        'No emergency contacts found. Add contacts in Profile to enable WhatsApp dispatch.',
      );
      return;
    }

    if (contacts.length == 1) {
      bool sent = await _contactsService.sendEmergencyWhatsApp(
        latitude: emergency.latitude,
        longitude: emergency.longitude,
        type: _overriddenEmergencyType ?? emergency.type,
        specificPhoneNumber: contacts.first.phoneNumber,
      );
      if (!sent && mounted) {
        _showWhatsAppFallbackDialog(emergency);
      }
      return;
    }

    // If multiple contacts exist, show quick 1-tap contact chooser
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfacePureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.radiusLg)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Send WhatsApp Alert To:',
                  style: AppTypography.subheading.copyWith(fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Requires an active WhatsApp account on recipient device. Standard carrier SMS rates apply if using SMS fallback.',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            ...contacts.map((c) {
              final formatted = EmergencyContactsService.formatWhatsAppNumber(c.phoneNumber);
              final displayPhone = formatted.isNotEmpty ? '+$formatted' : c.phoneNumber;
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF25D366),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${c.relationship} • $displayPhone'),
                trailing: const Icon(Icons.send_rounded, color: Color(0xFF25D366)),
                onTap: () async {
                  Navigator.pop(ctx);
                  bool sent = await _contactsService.sendEmergencyWhatsApp(
                    latitude: emergency.latitude,
                    longitude: emergency.longitude,
                    type: _overriddenEmergencyType ?? emergency.type,
                    specificPhoneNumber: c.phoneNumber,
                  );
                  if (!sent && mounted) {
                    _showWhatsAppFallbackDialog(emergency);
                  }
                },
              );
            }),
            const SizedBox(height: 8),
            const Divider(color: AppColors.borderSubtle),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sms_rounded, color: AppColors.brandBlue, size: 20),
              ),
              title: const Text('Open SMS Composer Instead', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Direct device SMS intent to all emergency contacts', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
              onTap: () {
                Navigator.pop(ctx);
                _dispatchEmergencySMS(emergency, isAuto: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fallbackSmsTimer?.cancel();
    _offlineUpdateSubscription?.cancel();
    _devicePositionSubscription?.cancel();
    _reliabilityMonitor.stopMonitoring();
    _locationService.stopEmergencyLocationUpdates();
    _connectivityService.dispose();
    super.dispose();
  }

  void _initEmergencyLocationStream(bool isVictim) {
    if (!_isLocationUpdatesStarted) {
      _isLocationUpdatesStarted = true;
      _locationService.startEmergencyLocationUpdates(
        emergencyId: widget.emergencyId,
        isVictim: isVictim,
      );
    }
  }

  bool _shouldRecalculateRoute(LatLng origin, LatLng destination) {
    if (_isFetchingRoute) return false;
    if (_lastOrigin == null || _lastDestination == null) return true;

    double originDelta = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      _lastOrigin!.latitude,
      _lastOrigin!.longitude,
    );
    double destDelta = Geolocator.distanceBetween(
      destination.latitude,
      destination.longitude,
      _lastDestination!.latitude,
      _lastDestination!.longitude,
    );

    if (originDelta >= 8.0 || destDelta >= 8.0) return true;

    if (_routePolyline.isEmpty &&
        (_lastRouteFetchTime == null || DateTime.now().difference(_lastRouteFetchTime!).inSeconds >= 15)) {
      return true;
    }

    return false;
  }

  void _updateRouteIfNeeded(LatLng origin, LatLng destination) {
    if (_mode == CommunicationMode.offline || widget.emergencyId.startsWith('JS-OFF-')) {
      return;
    }

    double directDist = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (directDist <= 30.0) {
      if (_currentDistanceMeters != directDist || _routePolyline.length != 2 || _etaText != 'Arriving') {
        if (mounted) {
          setState(() {
            _routePolyline = [origin, destination];
            _currentDistanceMeters = directDist;
            _etaText = 'Arriving';
          });
        }
      }
      return;
    }

    if (!_shouldRecalculateRoute(origin, destination)) {
      return;
    }

    _lastOrigin = origin;
    _lastDestination = destination;
    _lastRouteFetchTime = DateTime.now();
    _isFetchingRoute = true;

    RoutingService.instance.fetchRoadRoute(origin, destination).then((res) {
      _isFetchingRoute = false;
      if (!mounted) return;

      if (res != null && res.polylinePoints.length >= 2) {
        setState(() {
          _routePolyline = res.polylinePoints;
          _currentDistanceMeters = res.distanceMeters;
          _etaText = res.etaText;
        });
      } else {
        setState(() {
          _routePolyline = [origin, destination];
          _currentDistanceMeters = directDist;
          int mins = (directDist / 80).round();
          if (mins < 1) mins = 1;
          _etaText = '$mins mins';
        });
      }
    }).catchError((_) {
      _isFetchingRoute = false;
      if (mounted) {
        setState(() {
          _routePolyline = [origin, destination];
          _currentDistanceMeters = directDist;
          int mins = (directDist / 80).round();
          if (mins < 1) mins = 1;
          _etaText = '$mins mins';
        });
      }
    });
  }

  void _discoverHospitalsIfNeeded(EmergencyModel emergency) {
    if (_lastDiscoveredEmergencyId == emergency.id) return;
    _lastDiscoveredEmergencyId = emergency.id;
    _isLoadingHospitals = true;

    _hospitalService
        .discoverNearbyHospitals(
      location: LatLng(emergency.latitude, emergency.longitude),
      emergencyId: emergency.id,
    )
        .then((hospitals) {
      if (mounted) {
        setState(() {
          _nearbyHospitals = hospitals;
          _isLoadingHospitals = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() => _isLoadingHospitals = false);
      }
    });
  }

  void _selectHospitalForRouting(HospitalModel hospital, LatLng currentPos) {
    setState(() {
      _selectedHospital = hospital;
      _isNavigatingToHospital = true;
      _lastHospitalOrigin = null;
      _lastHospitalRouteFetchTime = null;
    });
    _updateHospitalRouteIfNeeded(currentPos, hospital.location);
    try {
      _mapController.move(currentPos, 15.0);
    } catch (_) {}
  }

  void _clearHospitalSelection() {
    setState(() {
      _selectedHospital = null;
      _isNavigatingToHospital = false;
      _hospitalRoutePolyline = [];
      _hospitalDistanceMeters = 0.0;
      _hospitalEtaText = '-- min';
      _lastHospitalOrigin = null;
      _lastHospitalRouteFetchTime = null;
    });
  }

  bool _shouldRecalculateHospitalRoute(LatLng origin, LatLng destination) {
    if (_isFetchingHospitalRoute) return false;
    if (_lastHospitalOrigin == null || _lastHospitalRouteFetchTime == null) return true;

    double originDelta = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      _lastHospitalOrigin!.latitude,
      _lastHospitalOrigin!.longitude,
    );

    if (originDelta >= 8.0) return true;

    if (_hospitalRoutePolyline.isEmpty &&
        DateTime.now().difference(_lastHospitalRouteFetchTime!).inSeconds >= 15) {
      return true;
    }

    return false;
  }

  void _updateHospitalRouteIfNeeded(LatLng origin, LatLng destination) {
    double directDist = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    int mins = (directDist / 500).round();
    if (mins < 1) mins = 1;
    final String fallbackEta = mins <= 1 ? '1 min' : '$mins mins';

    if (_mode == CommunicationMode.offline || widget.emergencyId.startsWith('JS-OFF-')) {
      if (mounted) {
        setState(() {
          _hospitalRoutePolyline = [origin, destination];
          _hospitalDistanceMeters = directDist;
          _hospitalEtaText = fallbackEta;
        });
      }
      return;
    }

    if (directDist <= 30.0) {
      if (_hospitalDistanceMeters != directDist ||
          _hospitalRoutePolyline.length != 2 ||
          _hospitalEtaText != 'Arriving') {
        if (mounted) {
          setState(() {
            _hospitalRoutePolyline = [origin, destination];
            _hospitalDistanceMeters = directDist;
            _hospitalEtaText = 'Arriving';
          });
        }
      }
      return;
    }

    if (!_shouldRecalculateHospitalRoute(origin, destination)) {
      return;
    }

    _lastHospitalOrigin = origin;
    _lastHospitalRouteFetchTime = DateTime.now();
    _isFetchingHospitalRoute = true;

    RoutingService.instance.fetchRoadRoute(origin, destination).then((res) {
      _isFetchingHospitalRoute = false;
      if (!mounted) return;

      if (res != null && res.polylinePoints.length >= 2) {
        setState(() {
          _hospitalRoutePolyline = res.polylinePoints;
          _hospitalDistanceMeters = res.distanceMeters;
          _hospitalEtaText = res.etaText;
        });
      } else {
        setState(() {
          _hospitalRoutePolyline = [origin, destination];
          _hospitalDistanceMeters = directDist;
          _hospitalEtaText = fallbackEta;
        });
      }
    }).catchError((_) {
      _isFetchingHospitalRoute = false;
      if (mounted) {
        setState(() {
          _hospitalRoutePolyline = [origin, destination];
          _hospitalDistanceMeters = directDist;
          _hospitalEtaText = fallbackEta;
        });
      }
    });
  }

  void _showReportProblemDialog() {
    AppDialogs.showReportProblemDialog(
      context: context,
      onReport: (reason, isFatal) async {
        final result = await _emergencyService.reportProblem(
          emergencyId: widget.emergencyId,
          userId: _currentUserId,
          reason: reason,
          isFatal: isFatal,
        );

        if (mounted) {
          if (isFatal) {
            if (result.hasNewPrimary) {
              AppSnackbar.showWarning(
                context,
                'Handover complete: Promoted ${result.newPrimaryName} to Primary. You are on Standby.',
              );
            } else {
              AppSnackbar.showWarning(
                context,
                'Handover complete: No standby helper was available. Emergency reset to searching.',
              );
            }
          } else {
            AppSnackbar.showInfo(
              context,
              'Delay reported ($reason). Victim and dispatch network notified.',
            );
          }
        }
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  void _handleArrivedPressed(EmergencyModel emergency) async {
    LatLng? deviceLatLng = _currentDeviceLatLng;
    ResponderModel? myResponder = emergency.responders[_currentUserId];

    double currentLat = deviceLatLng?.latitude ??
        (myResponder != null && myResponder.latitude != 0.0 ? myResponder.latitude : _lastOrigin?.latitude ?? 0.0);
    double currentLng = deviceLatLng?.longitude ??
        (myResponder != null && myResponder.longitude != 0.0 ? myResponder.longitude : _lastOrigin?.longitude ?? 0.0);

    double distanceMeters = 9999.0;

    if (currentLat != 0.0 && currentLng != 0.0) {
      distanceMeters = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        emergency.latitude,
        emergency.longitude,
      );
    } else if (_currentDistanceMeters > 0) {
      distanceMeters = _currentDistanceMeters;
    }

    const double arrivalGeofenceThresholdMeters = 100.0;

    if (distanceMeters > arrivalGeofenceThresholdMeters) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
          backgroundColor: AppColors.surfacePureWhite,
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: AppColors.emergencyRed, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Not At Victim Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.deepNavy),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_outlined, color: AppColors.emergencyRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current Distance: ${_formatDistance(distanceMeters)} away',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emergencyRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To protect the victim and ensure safety, you must be within 100 meters of the victim\'s live location to confirm your arrival.',
                style: AppTypography.bodySecondary.copyWith(height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK, CONTINUE NAVIGATING'),
            ),
          ],
        ),
      );
      return;
    }

    // Within 100m geofence: Verified arrival
    HapticFeedback.heavyImpact();

    if (mounted) {
      AppSnackbar.showSuccess(
        context,
        'Arrival verified. Victim notified that you have reached.',
      );
    }

    _emergencyService.updateEmergencyStatus(
      widget.emergencyId,
      EmergencyStatus.ARRIVED,
      responderId: _currentUserId,
    );

    ImpactRewardService().recordArrivalVerified(
      userId: _currentUserId,
      emergencyId: widget.emergencyId,
      isPrimary: true,
      isOffline: widget.emergencyId.startsWith('JS-OFF-') || _mode == CommunicationMode.offline,
      emergencyType: _overriddenEmergencyType ?? emergency.type,
    );
  }

  void _showCancelConfirmationDialog() {
    AppDialogs.showCancelEmergencyDialog(
      context: context,
      onConfirmCancel: () async {
        await _emergencyService.cancelEmergency(widget.emergencyId);
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  void _openEmergencyTypeSheet(EmergencyModel emergency) {
    EmergencyTypeSheet.show(
      context,
      currentType: _overriddenEmergencyType ?? emergency.type,
      onSelected: (selected) {
        setState(() {
          _overriddenEmergencyType = selected;
        });
      },
    );
  }

  void _recenterMap(LatLng target) {
    try {
      _mapController.move(target, 16.0);
    } catch (_) {}
  }

  List<Marker> _buildResponderMarkers(EmergencyModel emergency, LatLng victimPos) {
    LatLng victimPoint = (emergency.isVictim(_currentUserId) && _currentDeviceLatLng != null)
        ? _currentDeviceLatLng!
        : victimPos;

    List<Marker> markers = [
      Marker(
        point: victimPoint,
        width: 80,
        height: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.emergencyRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.surfacePureWhite,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 4)],
              ),
              child: Text(
                emergency.isVictim(_currentUserId) ? 'YOU' : 'VICTIM',
                style: const TextStyle(
                  color: AppColors.emergencyRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    emergency.responders.forEach((userId, r) {
      Color markerColor = AppColors.brandBlue;
      String label = 'PRIMARY';
      IconData markerIcon = Icons.navigation_rounded;

      if (r.userRole == 'AMBULANCE_DRIVER') {
        markerIcon = Icons.local_hospital_rounded;
        markerColor = AppColors.emergencyRed;
        label = 'AMBULANCE';
      } else if (r.userRole == 'POLICE_PCR') {
        markerIcon = Icons.local_police_rounded;
        markerColor = AppColors.brandBlue;
        label = 'POLICE PCR';
      } else if (r.role == ResponderRole.PRIMARY) {
        if (r.status == ResponderStatus.AT_RISK) {
          markerColor = Colors.orange;
          label = 'AT-RISK';
        } else if (r.status == ResponderStatus.DELAYED) {
          markerColor = AppColors.warningAmber;
          label = 'DELAYED';
        } else {
          markerColor = AppColors.brandBlue;
          label = 'PRIMARY';
        }
      } else if (r.role == ResponderRole.STANDBY) {
        markerColor = AppColors.warningAmber;
        label = 'STANDBY';
      } else if (r.role == ResponderRole.SECONDARY) {
        markerColor = Colors.grey;
        label = 'SECONDARY';
      }

      LatLng responderPoint = (userId == _currentUserId && _currentDeviceLatLng != null)
          ? _currentDeviceLatLng!
          : LatLng(r.latitude, r.longitude);

      markers.add(
        Marker(
          point: responderPoint,
          width: 90,
          height: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Icon(markerIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 4)],
                ),
                child: Text(
                  label,
                  style: TextStyle(color: markerColor, fontWeight: FontWeight.bold, fontSize: 8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    });

    if (_isNavigatingToHospital && _selectedHospital != null) {
      markers.add(
        Marker(
          point: _selectedHospital!.location,
          width: 140,
          height: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _selectedHospital!.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.location_on_rounded, color: AppColors.emergencyRed, size: 28),
            ],
          ),
        ),
      );
    } else if (emergency.status == EmergencyStatus.ARRIVED && emergency.isPrimaryResponder(_currentUserId)) {
      for (final hosp in _nearbyHospitals.take(3)) {
        markers.add(
          Marker(
            point: hosp.location,
            width: 110,
            height: 48,
            child: GestureDetector(
              onTap: () => _selectHospitalForRouting(hosp, _currentDeviceLatLng ?? victimPos),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfacePureWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emergencyRed, width: 1.2),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                    ),
                    child: Text(
                      hosp.name,
                      style: const TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.bold, fontSize: 8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.local_hospital_rounded, color: AppColors.emergencyRed, size: 18),
                ],
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  Widget _buildSearchingPanel(EmergencyModel emergency, bool isOffline) {
    String effectiveType = _overriddenEmergencyType ?? emergency.type;
    String displayType = effectiveType.isNotEmpty
        ? '${effectiveType[0].toUpperCase()}${effectiveType.substring(1).toLowerCase()}'
        : 'Medical';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Semantic Status Badge
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const AppStatusBadge(
              status: AppStatusType.emergency,
              customLabel: 'SEARCHING FOR HELP',
            ),
            Text(
              'Your request is active.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalSm,

        // Primary Header
        Text(
          'Finding nearby help',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Looking for a responder near you…',
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.gapVerticalMd,

        // Emergency Type & Location Sharing Confirmation Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.emergencyRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 18, color: AppColors.emergencyRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$displayType Emergency',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        Text(
                          'Your location is being shared.',
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openEmergencyTypeSheet(emergency),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      'Change',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18, thickness: 0.8, color: AppColors.borderSubtle),
              Row(
                children: [
                  Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.check_circle_outline_rounded,
                    size: 15,
                    color: isOffline ? AppColors.warningAmber : AppColors.emeraldGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOffline
                          ? 'Offline rescue mode'
                          : 'Connected to live mutual-aid dispatch network',
                      style: AppTypography.caption.copyWith(
                        color: isOffline ? AppColors.deepNavy : AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: isOffline ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppSpacing.gapVerticalMd,

        // Status Timeline
        EmergencyTimelineWidget(status: emergency.status),
        AppSpacing.gapVerticalMd,

        // Fallback Emergency Contacts Card (Human Wording)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfacePureWhite,
            borderRadius: AppShapes.card,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded, color: AppColors.brandBlue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Having trouble finding help?',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Contact your trusted emergency contacts',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _smsFallbackTriggered
                    ? 'Trusted-contact SMS ready to send'
                    : 'Auto-SMS fallback in ${_secondsRemainingForFallback ~/ 60}m ${(_secondsRemainingForFallback % 60).toString().padLeft(2, '0')}s',
                style: AppTypography.caption.copyWith(
                  color: _smsFallbackTriggered ? AppColors.emeraldGreen : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.sms_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'SMS Contacts',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: () => _dispatchEmergencySMS(emergency, isAuto: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'WhatsApp',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: () => _handleWhatsAppDispatch(emergency),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppSpacing.gapVerticalMd,

        // Secondary Background Hospital Discovery Card (Phase A)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfacePureWhite,
            borderRadius: AppShapes.card,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_hospital_outlined, size: 16, color: AppColors.brandBlue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Nearby Hospitals (Standby)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_nearbyHospitals.length} Found',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Discovered in background for post-arrival transport. Primary goal is finding nearby responders.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
              ),
              if (_nearbyHospitals.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._nearbyHospitals.take(2).map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              h.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.deepNavy),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            h.formattedDistance,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandBlue),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        AppSpacing.gapVerticalMd,

        // Cancel Emergency Action (Intentional Confirmation)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.emergencyRed,
            side: const BorderSide(color: AppColors.emergencyRed, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 13),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.cancel_outlined, size: 20),
          label: const Text(
            'Cancel Emergency',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: _showCancelConfirmationDialog,
        ),
      ],
    );
  }

  Widget _buildAssignedPanel(EmergencyModel emergency, ResponderModel primary) {
    String headerSubtitle = 'A verified responder has accepted your request.';

    if (primary.userRole == 'AMBULANCE_DRIVER') {
      headerSubtitle = 'Ambulance #${primary.vehicleNumber ?? 'EMS'} responding';
    } else if (primary.userRole == 'POLICE_PCR') {
      headerSubtitle = 'PCR Unit #${primary.vehicleNumber ?? 'PCR-12'} approaching';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Semantic Status Badge & ETA
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            const AppStatusBadge(
              status: AppStatusType.warning,
              customLabel: 'HELP IS ON THE WAY',
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ESTIMATED TIME',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      _etaText,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ],
                ),
                if (_currentDistanceMeters > 0) ...[
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'DISTANCE',
                        style: AppTypography.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        _formatDistance(_currentDistanceMeters),
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
        AppSpacing.gapVerticalSm,

        // Primary Title
        Text(
          'Help is on the way',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          headerSubtitle,
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.gapVerticalMd,

        // Responder Profile Card
        ResponderProfileCard(responder: primary),
        AppSpacing.gapVerticalMd,

        // Status Timeline
        EmergencyTimelineWidget(status: emergency.status),
        // Secondary Hospital Information Card for Victim (Phase B)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfacePureWhite,
            borderRadius: AppShapes.card,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_hospital_outlined, size: 16, color: AppColors.brandBlue),
                  SizedBox(width: 8),
                  Text(
                    'Nearby Hospitals (Standby)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Available for medical handover if emergency transport is required.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
              ),
              if (_nearbyHospitals.isNotEmpty) ...[
                const SizedBox(height: 6),
                ..._nearbyHospitals.take(2).map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              h.name,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.deepNavy),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            h.formattedDistance,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandBlue),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        AppSpacing.gapVerticalMd,

        // Cancel Action
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.emergencyRed,
            side: const BorderSide(color: AppColors.emergencyRed, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 13),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.cancel_outlined, size: 20),
          label: const Text(
            'Cancel Emergency',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: _showCancelConfirmationDialog,
        ),
      ],
    );
  }

  Widget _buildArrivedPanel(EmergencyModel emergency, ResponderModel? primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const AppStatusBadge(
              status: AppStatusType.success,
              customLabel: 'RESPONDER ARRIVED',
            ),
            Text(
              'Help has arrived',
              style: AppTypography.caption.copyWith(
                color: AppColors.emeraldGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalSm,

        Text(
          'Help has arrived',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Your responder is nearby.',
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.gapVerticalMd,

        if (primary != null) ...[
          ResponderProfileCard(responder: primary),
          AppSpacing.gapVerticalMd,
        ],

        // Status Timeline
        const EmergencyTimelineWidget(status: EmergencyStatus.ARRIVED),
        AppSpacing.gapVerticalMd,

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.emeraldGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.emeraldGreen, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please stay in a safe, visible position. Your responder has reached your location.',
                  style: AppTypography.bodySecondary.copyWith(
                    fontSize: 12.5,
                    color: AppColors.deepNavy,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapVerticalMd,

        // Secondary Hospital Information Card for Victim
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfacePureWhite,
            borderRadius: AppShapes.card,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_hospital_outlined, size: 16, color: AppColors.brandBlue),
                  SizedBox(width: 8),
                  Text(
                    'Nearby Hospitals (For Transport)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Medical centers available for emergency handover if required.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
              ),
              if (_nearbyHospitals.isNotEmpty) ...[
                const SizedBox(height: 6),
                ..._nearbyHospitals.take(2).map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              h.name,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.deepNavy),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            h.formattedDistance,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandBlue),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedPanel(EmergencyModel emergency, ResponderModel? primary) {
    bool isVictim = emergency.isVictim(_currentUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AppStatusBadge(
              status: AppStatusType.completed,
              customLabel: isVictim ? 'EMERGENCY COMPLETED' : 'RESCUE COMPLETE',
            ),
          ],
        ),
        AppSpacing.gapVerticalSm,

        Text(
          isVictim ? 'Emergency completed' : 'Rescue complete',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isVictim
              ? 'Incident resolved and session closed.'
              : 'Thank you for responding to this emergency.',
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.gapVerticalMd,

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INCIDENT SUMMARY',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.emeraldGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency: ${emergency.type.toUpperCase()}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isVictim
                    ? (primary != null
                        ? 'Assisted by: ${primary.userName} (${primary.userRole})'
                        : 'Assistance successfully coordinated')
                    : 'Response: Assistance delivered successfully at scene',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapVerticalMd,

        if (isVictim && primary != null) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text(
              'Rate & Verify Assistance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () {
              VictimFeedbackDialog.show(
                context,
                emergencyId: emergency.id,
                helperId: primary.userId,
                helperName: primary.userName,
                helperRole: primary.userRole,
              );
            },
          ),
          const SizedBox(height: 10),
        ],

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            minimumSize: const Size(double.infinity, 48),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'CLOSE SUMMARY',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            AppStatusBadge(
              status: AppStatusType.normal,
              customLabel: 'EMERGENCY CANCELLED',
            ),
          ],
        ),
        AppSpacing.gapVerticalSm,

        Text(
          'Emergency Cancelled',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'This alert was cancelled. Responders have been notified.',
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.gapVerticalMd,

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            'No further action required. If you still need help, you can hold the SOS button on the Home screen anytime.',
            style: AppTypography.bodySecondary.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        AppSpacing.gapVerticalLg,

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            minimumSize: const Size(double.infinity, 48),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'CLOSE SUMMARY',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationHud(EmergencyModel emergency) {
    bool isArrived = emergency.status == EmergencyStatus.ARRIVED;

    String hudTitle;
    String hudSubtitle;
    IconData hudIcon;
    Color hudColor;

    if (_isNavigatingToHospital && _selectedHospital != null) {
      hudTitle = 'Route to selected hospital';
      hudSubtitle = '${_selectedHospital!.name} • Hospital Transfer';
      hudIcon = Icons.local_hospital_rounded;
      hudColor = AppColors.brandBlue;
    } else if (isArrived) {
      hudTitle = 'At emergency scene • Assist victim';
      hudSubtitle = '${emergency.type.toUpperCase()} • Victim Location';
      hudIcon = Icons.verified_rounded;
      hudColor = AppColors.emeraldGreen;
    } else {
      hudTitle = 'Proceed to emergency location';
      hudSubtitle = '${emergency.type.toUpperCase()} • Victim Location';
      hudIcon = Icons.navigation_rounded;
      hudColor = AppColors.brandBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfacePureWhite,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hudColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(hudIcon, color: hudColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hudTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hudSubtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_isNavigatingToHospital && _selectedHospital != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _hospitalEtaText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepNavy,
                  ),
                ),
                Text(
                  _formatDistance(_hospitalDistanceMeters),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ] else if (!isArrived) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _etaText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepNavy,
                  ),
                ),
                Text(
                  _formatDistance(_currentDistanceMeters),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ] else ...[
            const AppStatusBadge(
              status: AppStatusType.success,
              customLabel: 'AT SCENE',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCallVictim(EmergencyModel emergency) async {
    if (_isCallingVictim) return;
    _isCallingVictim = true;

    try {
      final victimId = emergency.victimId;
      if (victimId.trim().isEmpty) {
        if (mounted) {
          AppSnackbar.showWarning(context, 'Victim phone number is not available.');
        }
        return;
      }

      final profile = await AuthService().getUserProfile(victimId);
      final phone = profile?.phoneNumber;

      if (phone == null || phone.trim().isEmpty) {
        if (mounted) {
          AppSnackbar.showWarning(context, 'Victim phone number is not available.');
        }
        return;
      }

      final cleanNumber = EmergencyContactsService.normalizeDialerNumber(phone);
      if (cleanNumber.isEmpty) {
        if (mounted) {
          AppSnackbar.showWarning(context, 'Victim phone number is invalid.');
        }
        return;
      }

      final launched = await EmergencyContactsService.launchDialer(cleanNumber);
      if (!launched && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
            title: Row(
              children: [
                const Icon(Icons.phone_rounded, color: AppColors.brandBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile?.name.isNotEmpty == true ? profile!.name : 'Victim Contact',
                    style: AppTypography.subheading,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not open phone dialer automatically.', style: AppTypography.bodySecondary),
                const SizedBox(height: 12),
                const Text('Victim Phone Number:', style: AppTypography.caption),
                const SizedBox(height: 4),
                SelectableText(
                  phone,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('COPY NUMBER'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: phone));
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    if (mounted) {
                      AppSnackbar.showSuccess(context, 'Phone number copied to clipboard.');
                    }
                  }
                },
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
      }
    } finally {
      _isCallingVictim = false;
    }
  }

  Widget _buildPrimaryResponderControls(EmergencyModel emergency) {
    bool isArrived = emergency.status == EmergencyStatus.ARRIVED;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            AppStatusBadge(
              status: isArrived ? AppStatusType.success : AppStatusType.emergency,
              customLabel: isArrived ? "YOU'VE ARRIVED" : 'YOU ARE RESPONDING',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                'PRIMARY RESPONDER',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalSm,

        Text(
          isArrived ? 'At Emergency Scene' : 'Navigating to Victim',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isArrived
              ? 'You are within 100m of the victim. Provide immediate assistance.'
              : 'Keep app active for live routing and victim proximity updates.',
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        if (isArrived) ...[
          AppSpacing.gapVerticalSm,
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.emeraldGreen, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Victim Reached • Nearby hospitals ready for transfer',
                    style: TextStyle(
                      color: AppColors.deepNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapVerticalSm,

          // Hospital Navigation State (Phase C & D)
          if (_isNavigatingToHospital && _selectedHospital != null) ...[
            // Phase D: Selected Hospital Route Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfacePureWhite,
                borderRadius: AppShapes.card,
                border: Border.all(color: AppColors.brandBlue, width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_hospital_rounded, size: 18, color: AppColors.brandBlue),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Route to selected hospital',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _hospitalEtaText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedHospital!.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDistance(_hospitalDistanceMeters)} away • ${_selectedHospital!.address}',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                  if (_mode == CommunicationMode.offline || widget.emergencyId.startsWith('JS-OFF-')) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.warningAmber),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Emergency communication available offline • Hospital road routing requires internet',
                              style: TextStyle(fontSize: 10.5, color: AppColors.deepNavy, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandBlue,
                        side: const BorderSide(color: AppColors.brandBlue),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Change Hospital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _clearHospitalSelection,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Phase C: Choose Nearby Hospital Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfacePureWhite,
                borderRadius: AppShapes.card,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_hospital_outlined, size: 18, color: AppColors.emergencyRed),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Choose nearby hospital',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nearby Hospitals (${_nearbyHospitals.length})',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a hospital to route patient for emergency handover.',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                  if (_mode == CommunicationMode.offline || widget.emergencyId.startsWith('JS-OFF-')) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.warningAmber),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Emergency communication available offline • Hospital road routing requires internet',
                              style: TextStyle(fontSize: 10.5, color: AppColors.deepNavy, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_isLoadingHospitals)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_nearbyHospitals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No registered hospitals found within search radius.',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      ),
                    )
                  else
                    ..._nearbyHospitals.take(3).map((hosp) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.brandBlue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_hospital_rounded, size: 16, color: AppColors.brandBlue),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hosp.name,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.deepNavy,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${hosp.formattedDistance} • ${hosp.etaText}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: const Size(0, 34),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  LatLng currentPos = _currentDeviceLatLng ?? LatLng(emergency.latitude, emergency.longitude);
                                  _selectHospitalForRouting(hosp, currentPos);
                                },
                                child: const Text(
                                  'Route',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ] else ...[
          // Phase B: Standby Hospital Card (Secondary Info before arrival)
          AppSpacing.gapVerticalSm,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfacePureWhite,
              borderRadius: AppShapes.card,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 16, color: AppColors.brandBlue),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Nearby Hospitals (Standby)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_nearbyHospitals.length} Found',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hospital routing will become active after reaching victim.',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
                if (_nearbyHospitals.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ..._nearbyHospitals.take(2).map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                h.name,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.deepNavy),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              h.formattedDistance,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brandBlue),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
        AppSpacing.gapVerticalMd,

        // Essential Actions: [ Call ] & [ Report Problem ]
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepNavy,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.call_rounded, size: 18, color: AppColors.brandBlue),
                label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _handleCallVictim(emergency),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepNavy,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.report_problem_outlined, size: 18, color: AppColors.warningAmber),
                label: const Text('Report Problem', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _showReportProblemDialog,
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalMd,

        // Primary Action Button (min 48dp)
        if (!isArrived) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'I HAVE ARRIVED',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
            ),
            onPressed: () => _handleArrivedPressed(emergency),
          ),
        ] else ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.task_alt_rounded, size: 20),
            label: const Text(
              'COMPLETE RESCUE',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
            ),
            onPressed: () async {
              await _emergencyService.updateEmergencyStatus(
                widget.emergencyId,
                EmergencyStatus.COMPLETED,
                responderId: _currentUserId,
              );
              await ImpactRewardService().recordEmergencyCompleted(
                userId: _currentUserId,
                emergencyId: widget.emergencyId,
                isPrimary: emergency.isPrimaryResponder(_currentUserId),
                isOffline: widget.emergencyId.startsWith('JS-OFF-') || _mode == CommunicationMode.offline,
                emergencyType: _overriddenEmergencyType ?? emergency.type,
              );
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStandbyControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            AppStatusBadge(
              status: AppStatusType.normal,
              customLabel: 'ON STANDBY',
            ),
          ],
        ),
        AppSpacing.gapVerticalSm,

        Text(
          "You're on standby",
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Another responder is currently primary. You\'ll be notified if backup help is needed.',
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        AppSpacing.gapVerticalMd,

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.brandBlue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Standby responders automatically step up if the lead responder experiences delays.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapVerticalLg,

        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.deepNavy,
            side: const BorderSide(color: AppColors.borderSubtle),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('BACK TO DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMapContent(EmergencyModel emergency) {
    bool isOffline = widget.emergencyId.startsWith('JS-OFF-') || _mode == CommunicationMode.offline;
    bool isVictim = emergency.isVictim(_currentUserId);
    ResponderModel? primary = emergency.primaryResponder;
    bool isPrimary = emergency.isPrimaryResponder(_currentUserId);
    bool isStandby = emergency.isStandbyResponder(_currentUserId);
    bool isCancelled = emergency.status == EmergencyStatus.CANCELLED;
    bool isCompleted = emergency.status == EmergencyStatus.COMPLETED;

    if (!isCancelled && !isCompleted) {
      _initEmergencyLocationStream(isVictim);
      _checkAndStartFallbackTimer(emergency, isVictim);
      _discoverHospitalsIfNeeded(emergency);
      if (isVictim && primary != null) {
        EmergencySoundService.playVictimReceivedHelper(emergency.id, primary.userName);
      }
    } else {
      _fallbackSmsTimer?.cancel();
      _fallbackSmsTimer = null;
      EmergencySoundService.stopSound();
      _locationService.stopEmergencyLocationUpdates();

      // Clean up hospital routing state on completed or cancelled
      if (_isNavigatingToHospital || _selectedHospital != null) {
        _isNavigatingToHospital = false;
        _selectedHospital = null;
        _hospitalRoutePolyline = [];
        _hospitalDistanceMeters = 0.0;
        _hospitalEtaText = '-- min';
      }

      if (isVictim && isCompleted && primary != null && !_hasShownVictimFeedback) {
        _hasShownVictimFeedback = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            VictimFeedbackDialog.show(
              context,
              emergencyId: emergency.id,
              helperId: primary.userId,
              helperName: primary.userName,
              helperRole: primary.userRole,
            );
          }
        });
      }
    }

    LatLng victimPos = LatLng(emergency.latitude, emergency.longitude);
    LatLng? primaryPos = primary != null ? LatLng(primary.latitude, primary.longitude) : null;
    LatLng? originForRoute = isPrimary ? (_currentDeviceLatLng ?? primaryPos) : primaryPos;

    if (!isCancelled && !isCompleted) {
      if (isPrimary && _isNavigatingToHospital && _selectedHospital != null) {
        LatLng hospitalOrigin = _currentDeviceLatLng ?? victimPos;
        if (_shouldRecalculateHospitalRoute(hospitalOrigin, _selectedHospital!.location)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateHospitalRouteIfNeeded(hospitalOrigin, _selectedHospital!.location);
          });
        }
      } else if (!isOffline && originForRoute != null && emergency.status != EmergencyStatus.ARRIVED) {
        if (_shouldRecalculateRoute(originForRoute, victimPos)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateRouteIfNeeded(originForRoute, victimPos);
          });
        }
      }
    }

    List<Marker> markers = _buildResponderMarkers(emergency, victimPos);
    List<Polyline> polylines = [];
    if (!isCancelled && !isCompleted) {
      if (_isNavigatingToHospital && _hospitalRoutePolyline.isNotEmpty) {
        polylines = [
          Polyline(
            points: _hospitalRoutePolyline,
            strokeWidth: 5.0,
            color: AppColors.brandBlue,
            borderColor: const Color(0xFF1E40AF),
            borderStrokeWidth: 1.5,
          ),
        ];
      } else if (!isOffline && _mode == CommunicationMode.online && _routePolyline.isNotEmpty && emergency.status != EmergencyStatus.ARRIVED) {
        polylines = [
          Polyline(
            points: _routePolyline,
            strokeWidth: 5.0,
            color: AppColors.brandBlue,
            borderColor: const Color(0xFF1E40AF),
            borderStrokeWidth: 1.5,
          ),
        ];
      }
    }

    return PopScope<Object?>(
      canPop: !emergency.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSafeHomeNavigation(emergency);
      },
      child: Scaffold(
        backgroundColor: AppColors.warmOffWhite,
        appBar: AppBar(
          backgroundColor: AppColors.surfacePureWhite,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              emergency.isActive ? Icons.home_rounded : Icons.arrow_back_rounded,
              color: AppColors.deepNavy,
            ),
            tooltip: emergency.isActive ? 'Home' : 'Back',
            onPressed: () {
              if (emergency.isActive) {
                _handleSafeHomeNavigation(emergency);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        title: Text(
          isCancelled
              ? 'Emergency Cancelled'
              : isCompleted
                  ? 'Emergency Completed'
                  : isVictim
                      ? (isOffline ? 'Offline Emergency' : 'Live Assistance')
                      : isPrimary
                          ? (_isNavigatingToHospital ? 'Route to Hospital' : 'Navigating to Victim')
                          : isStandby
                              ? 'On Standby'
                              : 'Emergency Map',
          style: AppTypography.subheading.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderSubtle, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isPrimary && !isCancelled && !isCompleted)
              _buildNavigationHud(emergency),
            // Medium-Sized Readable Live Map
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  RealMapWidget(
                    centerLatLng: victimPos,
                    initialZoom: 16.0,
                    mapController: _mapController,
                    extraMarkers: markers,
                    polylines: polylines,
                  ),
                  // Subtle Recenter Control
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Material(
                      color: AppColors.surfacePureWhite,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _recenterMap(victimPos),
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.my_location_rounded,
                            color: AppColors.deepNavy,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Emergency State Details Panel (Immune to Overflows)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfacePureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Builder(
                    builder: (context) {
                      if (isCancelled) {
                        return _buildCancelledPanel();
                      } else if (isCompleted) {
                        return _buildCompletedPanel(emergency, primary);
                      } else if (isVictim) {
                        if (emergency.status == EmergencyStatus.ARRIVED) {
                          return _buildArrivedPanel(emergency, primary);
                        } else if (emergency.status == EmergencyStatus.ASSIGNED ||
                            emergency.status == EmergencyStatus.APPROACHING) {
                          return primary != null
                              ? _buildAssignedPanel(emergency, primary)
                              : _buildSearchingPanel(emergency, isOffline);
                        } else {
                          return _buildSearchingPanel(emergency, isOffline);
                        }
                      } else if (isPrimary) {
                        return _buildPrimaryResponderControls(emergency);
                      } else if (isStandby) {
                        return _buildStandbyControls();
                      } else {
                        return _buildSearchingPanel(emergency, isOffline);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    bool isOffline = widget.emergencyId.startsWith('JS-OFF-');

    if (isOffline) {
      return StreamBuilder<EmergencyModel?>(
        initialData: widget.initialEmergency,
        stream: _localDb.streamEmergency(widget.emergencyId),
        builder: (context, snapshot) {
          final emergency = snapshot.data ?? widget.initialEmergency;
          if (snapshot.connectionState == ConnectionState.waiting && emergency == null) {
            return const Scaffold(body: AppLoadingWidget());
          }
          if (emergency == null) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('Offline Emergency'),
              ),
              body: AppErrorWidget(
                title: 'Emergency Not Found',
                message: 'This emergency is no longer available offline.',
                icon: Icons.error_outline,
                iconColor: Colors.orange,
                onRetry: () => Navigator.of(context).pop(),
              ),
            );
          }
          return _buildMapContent(emergency);
        },
      );
    }

    Stream<EmergencyModel> emergencyStream;
    try {
      emergencyStream = _emergencyService.streamEmergency(widget.emergencyId);
    } catch (e) {
      emergencyStream = Stream.error(e);
    }

    return StreamBuilder<EmergencyModel>(
      initialData: widget.initialEmergency,
      stream: emergencyStream,
      builder: (context, snapshot) {
        final emergency = snapshot.data ?? widget.initialEmergency;
        if (snapshot.connectionState == ConnectionState.waiting && emergency == null) {
          return const Scaffold(body: AppLoadingWidget());
        }
        if (emergency == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Emergency Assistance'),
            ),
            body: AppErrorWidget(
              title: 'Emergency Map Unavailable',
              message: 'Unable to connect to this live emergency. It may have concluded or network signal was lost.',
              onRetry: () => Navigator.of(context).pop(),
            ),
          );
        }
        return _buildMapContent(emergency);
      },
    );
  }
}
