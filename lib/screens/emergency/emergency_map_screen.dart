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
import '../../core/theme/app_theme.dart';
import '../../services/emergency_service.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/responder_reliability_monitor.dart';
import '../../services/local_database_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/app_state_widgets.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/emergency_timeline_widget.dart';
import '../../widgets/responder_profile_card.dart';
import '../../widgets/victim_feedback_dialog.dart';
import '../../services/impact_reward_service.dart';

class EmergencyMapScreen extends StatefulWidget {
  final String emergencyId;
  const EmergencyMapScreen({super.key, required this.emergencyId});

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
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'offline_user';

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

  // Route calculation cache
  LatLng? _lastOrigin;
  LatLng? _lastDestination;
  DateTime? _lastRouteFetchTime;
  bool _isFetchingRoute = false;
  bool _hasShownVictimFeedback = false;

  @override
  void initState() {
    super.initState();
    _connectivityService.initialize();
    _mode = _connectivityService.currentMode;
    _connectivityService.modeStream.listen((m) {
      if (mounted) setState(() => _mode = m);
    });

    // Stream live device GPS hardware updates with 1-meter precision
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

    if (!widget.emergencyId.startsWith('JS-OFF-')) {
      _reliabilityMonitor.startMonitoring(widget.emergencyId);
    } else {
      // Listen to reactive local updates for offline emergency state sync
      _offlineUpdateSubscription = LocalDatabaseService.emergencyUpdatesStream.listen((updatedEmergency) {
        if (updatedEmergency.id == widget.emergencyId && mounted) {
          setState(() {});
        }
      });
    }
  }

  void _checkAndStartFallbackTimer(EmergencyModel emergency, bool isVictim) {
    if (!isVictim || _smsFallbackTriggered) return;

    if (emergency.status == EmergencyStatus.SEARCHING) {
      _fallbackSmsTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_secondsRemainingForFallback > 0) {
          setState(() => _secondsRemainingForFallback--);
        } else {
          timer.cancel();
          _dispatchEmergencySMS(emergency, isAuto: true);
        }
      });
    } else {
      _fallbackSmsTimer?.cancel();
      _fallbackSmsTimer = null;
    }
  }

  void _dispatchEmergencySMS(EmergencyModel emergency, {bool isAuto = false}) async {
    _fallbackSmsTimer?.cancel();
    if (mounted) setState(() => _smsFallbackTriggered = true);

    bool sent = await _contactsService.sendEmergencySMS(
      latitude: emergency.latitude,
      longitude: emergency.longitude,
      type: emergency.type,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: isAuto ? AppTheme.primaryRed : AppTheme.secondaryBlue,
          content: Row(
            children: [
              const Icon(Icons.sms, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sent
                    ? (isAuto
                        ? '3-Min Timeout: Emergency SMS with victim details & live Google Maps location dispatched to your contacts!'
                        : 'Emergency SMS with victim details & live Google Maps link dispatched!')
                    : 'No emergency contacts found. Add contacts in Profile to enable Auto-SMS fallback.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _handleWhatsAppDispatch(EmergencyModel emergency) async {
    List<EmergencyContact> contacts = await _contactsService.getContacts();
    if (!mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No emergency contacts found. Add contacts in Profile to enable WhatsApp dispatch.'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    if (contacts.length == 1) {
      bool sent = await _contactsService.sendEmergencyWhatsApp(
        latitude: emergency.latitude,
        longitude: emergency.longitude,
        type: emergency.type,
        specificPhoneNumber: contacts.first.phoneNumber,
      );
      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp dispatch failed. Ensure WhatsApp is installed.')),
        );
      }
      return;
    }

    // If multiple contacts exist, show quick 1-tap contact chooser
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 24),
                SizedBox(width: 10),
                Text(
                  'Send WhatsApp Alert To:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...contacts.map((c) => ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${c.relationship} • +${EmergencyContactsService.normalizePhoneNumber(c.phoneNumber)}'),
              trailing: const Icon(Icons.send_rounded, color: Color(0xFF25D366)),
              onTap: () async {
                Navigator.pop(ctx);
                await _contactsService.sendEmergencyWhatsApp(
                  latitude: emergency.latitude,
                  longitude: emergency.longitude,
                  type: emergency.type,
                  specificPhoneNumber: c.phoneNumber,
                );
              },
            )),
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

    // If either point moved 8 meters or more, recalculation is needed
    if (originDelta >= 8.0 || destDelta >= 8.0) return true;

    // If we have no polyline points yet, and at least 15 seconds have passed since last attempt
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

    // 1. Calculate high-precision direct geodesic distance
    double directDist = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    // If within 30m, victim is directly reachable
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFD97706), // Amber
                  content: Text(
                    'Handover complete: Promoted ${result.newPrimaryName} to Primary. You are now on Standby.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFFEA580C), // Orange
                  content: Text(
                    'Handover complete: No standby helper was available. Emergency reset to searching. You are now on Standby.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0284C7), // Sky blue
                content: Text('Delay reported ($reason). Victim and dispatch network notified.'),
              ),
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
    // 1. Instant 0-latency arrival check from live 1-meter GPS stream
    LatLng? deviceLatLng = _currentDeviceLatLng;
    ResponderModel? myResponder = emergency.responders[_currentUserId];

    double currentLat = deviceLatLng?.latitude ??
        (myResponder != null && myResponder.latitude != 0.0 ? myResponder.latitude : _lastOrigin?.latitude ?? 0.0);
    double currentLng = deviceLatLng?.longitude ??
        (myResponder != null && myResponder.longitude != 0.0 ? myResponder.longitude : _lastOrigin?.longitude ?? 0.0);

    double distanceMeters = 9999.0;

    if (currentLat != 0.0 && currentLng != 0.0) {
      // High-precision WGS-84 ellipsoidal distance calculation
      distanceMeters = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        emergency.latitude,
        emergency.longitude,
      );
    } else if (_currentDistanceMeters > 0) {
      distanceMeters = _currentDistanceMeters;
    }

    // Geofence Arrival Threshold: 100 meters
    const double arrivalGeofenceThresholdMeters = 100.0;

    if (distanceMeters > arrivalGeofenceThresholdMeters) {
      // Reject premature arrival
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: AppTheme.errorRed, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Not At Victim Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_outlined, color: AppTheme.errorRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current Distance: ${_formatDistance(distanceMeters)} away',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To protect the victim and ensure accurate reporting, you must be within 100 meters of the victim\'s live location to confirm your arrival.',
                style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryBlue,
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

    // Within 100m geofence: Instant Optimistic Haptics & Notification
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          content: Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Arrival verified! Victim notified that you have reached.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Update Firestore / Local storage immediately in parallel
    _emergencyService.updateEmergencyStatus(
      widget.emergencyId,
      EmergencyStatus.ARRIVED,
      responderId: _currentUserId,
    );

    // Record verified arrival impact points (+15 to +25 points) & unlock rapid responder badge
    ImpactRewardService().recordArrivalVerified(
      userId: _currentUserId,
      emergencyId: widget.emergencyId,
      isPrimary: true,
      isOffline: widget.emergencyId.startsWith('JS-OFF-') || _mode == CommunicationMode.offline,
      emergencyType: emergency.type,
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.primaryRed),
            SizedBox(width: 8),
            Text('Cancel Emergency?'),
          ],
        ),
        content: const Text('Are you sure you want to cancel this SOS alert? Responders will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('NO, KEEP SOS'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _emergencyService.cancelEmergency(widget.emergencyId);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('YES, CANCEL SOS'),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildResponderMarkers(EmergencyModel emergency, LatLng victimPos) {
    LatLng victimPoint = (emergency.isVictim(_currentUserId) && _currentDeviceLatLng != null)
        ? _currentDeviceLatLng!
        : victimPos;

    List<Marker> markers = [
      Marker(
        point: victimPoint,
        width: 60,
        height: 60,
        child: const Column(
          children: [
            Icon(Icons.location_on, color: AppTheme.primaryRed, size: 36),
            Text('VICTIM 🔴', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
      ),
    ];

    emergency.responders.forEach((userId, r) {
      Color markerColor = AppTheme.secondaryBlue;
      String label = 'PRIMARY 🟢';
      IconData markerIcon = Icons.navigation;

      if (r.userRole == 'AMBULANCE_DRIVER') {
        markerIcon = Icons.local_hospital;
        markerColor = AppTheme.primaryRed;
        label = 'AMBULANCE 🚑 (${r.vehicleNumber ?? '108'})';
      } else if (r.userRole == 'POLICE_PCR') {
        markerIcon = Icons.local_police;
        markerColor = AppTheme.secondaryBlue;
        label = 'PCR PATROL 🚓 (${r.vehicleNumber ?? 'PCR-12'})';
      } else if (r.role == ResponderRole.PRIMARY) {
        if (r.status == ResponderStatus.AT_RISK) {
          markerColor = Colors.orange;
          label = 'AT-RISK 🟠';
        } else if (r.status == ResponderStatus.DELAYED) {
          markerColor = AppTheme.tertiaryAmber;
          label = 'DELAYED 🟡';
        } else {
          markerColor = AppTheme.secondaryBlue;
          label = 'PRIMARY 🟢';
        }
      } else if (r.role == ResponderRole.STANDBY) {
        markerColor = AppTheme.tertiaryAmber;
        label = 'STANDBY 🟡';
      } else if (r.role == ResponderRole.SECONDARY) {
        markerColor = Colors.grey;
        label = 'SECONDARY ⚪';
      }

      LatLng responderPoint = (userId == _currentUserId && _currentDeviceLatLng != null)
          ? _currentDeviceLatLng!
          : LatLng(r.latitude, r.longitude);

      markers.add(
        Marker(
          point: responderPoint,
          width: 80,
          height: 65,
          child: Column(
            children: [
              Icon(markerIcon, color: markerColor, size: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
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

    return markers;
  }

  Widget _buildTopFloatingHUD(bool isVictim, bool isPrimary, bool isStandby, ResponderModel? primary, EmergencyStatus status) {
    if (isVictim) {
      String statusText = 'SOS ACTIVE';
      Color hudColor = AppTheme.primaryRed;

      if (status == EmergencyStatus.ARRIVED) {
        statusText = 'HELPER HAS ARRIVED';
        hudColor = Colors.green;
      } else if (status == EmergencyStatus.COMPLETED) {
        statusText = 'EMERGENCY COMPLETED';
        hudColor = AppTheme.secondaryBlue;
      } else if (status == EmergencyStatus.CANCELLED) {
        statusText = 'EMERGENCY CANCELLED';
        hudColor = Colors.grey;
      }

      return Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: hudColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: hudColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == EmergencyStatus.ARRIVED
                      ? Icons.check_circle_outline
                      : status == EmergencyStatus.COMPLETED
                          ? Icons.task_alt
                          : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isPrimary) {
      return Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'YOU ARE THE PRIMARY HELPER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PRIMARY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _currentDistanceMeters > 0
                        ? '${_formatDistance(_currentDistanceMeters)} • $_etaText'
                        : 'Approaching Victim',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isStandby) {
      return Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.tertiaryContainerAmber,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.pause_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Primary responder is responding. You are on Standby.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBottomControls(EmergencyModel emergency, bool isOffline, bool isVictim, bool isPrimary, ResponderModel? primary) {
    String headerTitle = 'Help is on the way';
    String headerSubtitle = 'Responder assigned and approaching';

    if (primary != null) {
      if (primary.userRole == 'AMBULANCE_DRIVER') {
        headerTitle = 'Ambulance is En-Route!';
        headerSubtitle = '108 Ambulance #${primary.vehicleNumber ?? '108'} responding with siren';
      } else if (primary.userRole == 'POLICE_PCR') {
        headerTitle = 'Police Patrol Dispatched!';
        headerSubtitle = 'PCR Unit #${primary.vehicleNumber ?? 'PCR-12'} approaching';
      }
    }

    if (emergency.status == EmergencyStatus.SEARCHING) {
      headerTitle = 'Searching for nearby helpers...';
      headerSubtitle = 'Alert broadcasted to safety network & dispatchers';
    } else if (emergency.status == EmergencyStatus.ARRIVED) {
      headerTitle = primary?.userRole == 'AMBULANCE_DRIVER'
          ? 'Ambulance Has Arrived!'
          : primary?.userRole == 'POLICE_PCR'
              ? 'Police Patrol Has Arrived!'
              : 'Helper Has Arrived!';
      headerSubtitle = 'Your responder is at your location';
    } else if (emergency.status == EmergencyStatus.COMPLETED) {
      headerTitle = 'Emergency Completed';
      headerSubtitle = 'Incident resolved and session ended';
    } else if (emergency.status == EmergencyStatus.CANCELLED) {
      headerTitle = 'Emergency Cancelled';
      headerSubtitle = 'SOS alert was cancelled';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHighest,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Victim Bottom Content
          if (isVictim) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headerTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(headerSubtitle, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (emergency.status == EmergencyStatus.ASSIGNED || emergency.status == EmergencyStatus.APPROACHING) ...[
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('ETA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                          Text(_etaText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                        ],
                      ),
                      if (_currentDistanceMeters > 0) ...[
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('DIST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                            Text(_formatDistance(_currentDistanceMeters), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            EmergencyTimelineWidget(status: emergency.status),
            const SizedBox(height: 14),
            if (primary != null && emergency.status != EmergencyStatus.COMPLETED && emergency.status != EmergencyStatus.CANCELLED) ...[
              ResponderProfileCard(responder: primary),
              const SizedBox(height: 14),
            ],

            // 60-Second Auto-SMS Fallback Banner
            if (emergency.status == EmergencyStatus.SEARCHING) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.tertiaryAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppTheme.tertiaryAmber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _smsFallbackTriggered
                                ? 'Auto-SMS Fallback Dispatched'
                                : 'Auto-SMS Fallback: ${_secondsRemainingForFallback ~/ 60}m ${(_secondsRemainingForFallback % 60).toString().padLeft(2, '0')}s',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _smsFallbackTriggered
                                ? 'Emergency details & Google Maps link sent to your 3 contacts'
                                : 'If no responder connects in 3 mins, victim details & map link will be SMSed to family',
                            style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.sms, size: 18),
                      label: const Text('SEND SMS NOW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _dispatchEmergencySMS(emergency, isAuto: false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WhatsApp Brand Green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('WHATSAPP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleWhatsAppDispatch(emergency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            if (emergency.status == EmergencyStatus.SEARCHING ||
                emergency.status == EmergencyStatus.ASSIGNED ||
                emergency.status == EmergencyStatus.APPROACHING)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('CANCEL SOS'),
                onPressed: _showCancelConfirmationDialog,
              ),
            if (emergency.status == EmergencyStatus.COMPLETED || emergency.status == EmergencyStatus.CANCELLED)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryBlue),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CLOSE SUMMARY'),
              ),
          ],

          // Primary Responder Controls
          if (isPrimary && emergency.status != EmergencyStatus.COMPLETED && emergency.status != EmergencyStatus.CANCELLED) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tertiaryAmber),
                    icon: const Icon(Icons.report_problem, size: 20),
                    label: const Text('PROBLEM'),
                    onPressed: _showReportProblemDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: emergency.status == EmergencyStatus.ARRIVED ? const Color(0xFF059669) : Colors.green,
                      elevation: emergency.status == EmergencyStatus.ARRIVED ? 0 : 2,
                    ),
                    icon: Icon(
                      emergency.status == EmergencyStatus.ARRIVED ? Icons.verified_outlined : Icons.check_circle,
                      size: 20,
                    ),
                    label: Text(emergency.status == EmergencyStatus.ARRIVED ? 'AT SCENE' : 'ARRIVED'),
                    onPressed: emergency.status == EmergencyStatus.ARRIVED ? null : () => _handleArrivedPressed(emergency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryBlue),
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
                  emergencyType: emergency.type,
                );
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('END EMERGENCY'),
            ),
          ],
        ],
      ),
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
      if (isVictim && primary != null) {
        EmergencySoundService.playVictimReceivedHelper(emergency.id, primary.userName);
      }
    } else {
      _fallbackSmsTimer?.cancel();
      _fallbackSmsTimer = null;
      EmergencySoundService.stopSound();
      _locationService.stopEmergencyLocationUpdates();

      // Show victim feedback dialog once when emergency concludes
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

    if (!isOffline && originForRoute != null && !isCancelled && !isCompleted) {
      if (_shouldRecalculateRoute(originForRoute, victimPos)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateRouteIfNeeded(originForRoute, victimPos);
        });
      }
    }

    List<Marker> markers = _buildResponderMarkers(emergency, victimPos);
    List<Polyline> polylines = (!isOffline && _mode == CommunicationMode.online && _routePolyline.isNotEmpty && !isCancelled && !isCompleted)
        ? [
            Polyline(
              points: _routePolyline,
              strokeWidth: 5.5,
              color: const Color(0xFF2563EB),
              borderColor: const Color(0xFF1E40AF),
              borderStrokeWidth: 1.5,
            ),
          ]
        : [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isCancelled
              ? 'Emergency Cancelled'
              : isCompleted
                  ? 'Emergency Completed'
                  : isVictim
                      ? (isOffline ? 'Offline SOS Active' : 'Emergency Assistance')
                      : isPrimary
                          ? 'Navigating to Victim'
                          : isStandby
                              ? 'On Standby'
                              : 'Emergency Map',
        ),
      ),
      body: Stack(
        children: [
          RealMapWidget(
            centerLatLng: victimPos,
            initialZoom: 16.0,
            mapController: _mapController,
            extraMarkers: markers,
            polylines: polylines,
          ),
          _buildTopFloatingHUD(isVictim, isPrimary, isStandby, primary, emergency.status),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomControls(emergency, isOffline, isVictim, isPrimary, primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isOffline = widget.emergencyId.startsWith('JS-OFF-');

    if (isOffline) {
      return FutureBuilder<EmergencyModel?>(
        future: _localDb.getEmergencyById(widget.emergencyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: AppLoadingWidget());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('📡 OFFLINE EMERGENCY'),
              ),
              body: AppErrorWidget(
                title: 'Offline Record Not Found',
                message: 'Offline emergency record not found in local storage.',
                icon: Icons.error_outline,
                iconColor: Colors.orange,
                onRetry: () => Navigator.of(context).pop(),
              ),
            );
          }
          return _buildMapContent(snapshot.data!);
        },
      );
    }

    return StreamBuilder<EmergencyModel>(
      stream: _emergencyService.streamEmergency(widget.emergencyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: AppLoadingWidget());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('🚨 EMERGENCY MAP'),
            ),
            body: AppErrorWidget(
              title: 'Emergency Map Unavailable',
              message: 'Emergency session unavailable: ${snapshot.error ?? 'Not Found'}',
              onRetry: () => Navigator.of(context).pop(),
            ),
          );
        }
        return _buildMapContent(snapshot.data!);
      },
    );
  }
}
