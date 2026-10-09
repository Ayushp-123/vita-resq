import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/communication_mode.dart';
import '../../models/emergency_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/communication_manager.dart';
import '../../services/emergency_service.dart';
import '../../services/notification_service.dart';
import '../../services/accident_detection_service.dart';
import '../../services/accident_detection_evaluator.dart';
import '../../services/local_database_service.dart';
import '../../services/responder_mode_service.dart';
import '../../services/offline_communication_service.dart';
import '../../services/p2p_diagnostics.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/accident_detection_dialog.dart';
import '../../widgets/permission_request_dialog.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common/common.dart';
import '../../core/navigation/app_navigator.dart';
import '../profile/profile_screen.dart';
import '../history/emergency_history_screen.dart';

/// Vita ResQ Home Screen — Phase 2 UI Redesign.
///
/// Embodies the HUMAN + PROFESSIONAL design direction:
/// - Clean, calm, trustworthy aesthetic with zero decorative clutter.
/// - Locked order:
///   HEADER → STATUS / EXISTING CONTEXT → MEDIUM LIVE MAP → EMERGENCY HELP PROMPT → LARGE CIRCULAR SOS → "Hold for help" → BOTTOM NAVIGATION.
class HomeScreen extends StatefulWidget {
  final Position? initialPosition;
  final CommunicationMode? initialMode;
  final EmergencyModel? initialActiveEmergency;

  const HomeScreen({
    super.key,
    this.initialPosition,
    this.initialMode,
    this.initialActiveEmergency,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final CommunicationManager _communicationManager = CommunicationManager();
  final EmergencyService _emergencyService = EmergencyService();
  final AccidentDetectionService _accidentDetectionService = AccidentDetectionService();
  final AuthService _authService = AuthService();
  final MapController _mapController = MapController();
  final LocalDatabaseService _localDb = LocalDatabaseService();

  NotificationService? _notificationServiceInstance;
  NotificationService? get _notificationService {
    try {
      return _notificationServiceInstance ??= NotificationService();
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? _authInstance;
  FirebaseAuth? get _auth {
    try {
      return _authInstance ??= FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Position? _currentPosition;
  UserModel? _userProfile;
  EmergencyModel? _activeEmergency;
  StreamSubscription<EmergencyModel?>? _activeEmergencySubscription;
  String? _subscribedEmergencyId;
  bool _isLoadingLocation = true;
  bool _isCreatingSOS = false;
  int _currentIndex = 0;
  CommunicationMode _currentMode = CommunicationMode.online;
  bool _isConnectivityExpanded = false;

  StreamSubscription<List<EmergencyModel>>? _nearbySubscription;
  StreamSubscription<CommunicationMode>? _modeSubscription;
  StreamSubscription<AccidentEvaluationResult>? _accidentSubscription;
  StreamSubscription<EmergencyModel>? _localEmergencyUpdateSub;
  StreamSubscription<Position>? _locationSubscription;
  final Set<String> _alertedEmergencyIds = {};

  @override
  void initState() {
    super.initState();
    _communicationManager.initialize();
    _currentMode = widget.initialMode ?? _communicationManager.activeMode;

    _modeSubscription = _communicationManager.modeStream.listen((mode) {
      if (widget.initialMode == null && mounted && _currentMode != mode) {
        setState(() => _currentMode = mode);
        if (_currentPosition != null) {
          _listenToAlerts(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _auth?.currentUser?.uid ?? 'offline_user',
          );
        }
      }
    });

    _localEmergencyUpdateSub = LocalDatabaseService.emergencyUpdatesStream.listen((emergency) async {
      if (emergency.status == EmergencyStatus.COMPLETED || emergency.status == EmergencyStatus.CANCELLED) {
        NotificationService.cancelEmergencyNotification(emergency.id);
      }
      final currentUid = _auth?.currentUser?.uid ?? 'offline_user';
      final myDeviceId = await LocalDatabaseService.getOrCreateLocalDeviceId();
      final isOwnDevice = emergency.originDeviceId != null && emergency.originDeviceId == myDeviceId;
      final isOwnAuthUser = currentUid != 'offline_user' && emergency.victimId == currentUid;
      final isVictim = isOwnDevice || isOwnAuthUser;
      final isResponder = emergency.isPrimaryResponder(currentUid) || emergency.isStandbyResponder(currentUid);

      if (isVictim || isResponder) {
        if (mounted) {
          setState(() {
            if (emergency.status == EmergencyStatus.COMPLETED || emergency.status == EmergencyStatus.CANCELLED) {
              if (_activeEmergency?.id == emergency.id) {
                _activeEmergency = null;
                _activeEmergencySubscription?.cancel();
                _activeEmergencySubscription = null;
                _subscribedEmergencyId = null;
              }
            } else {
              _activeEmergency = emergency;
              _subscribeToActiveEmergency(emergency.id, isOffline: emergency.isOffline);
            }
          });
        }
      }
    });

    if (widget.initialActiveEmergency != null) {
      _activeEmergency = widget.initialActiveEmergency;
      if (widget.initialActiveEmergency!.isActive) {
        _subscribeToActiveEmergency(
          widget.initialActiveEmergency!.id,
          isOffline: widget.initialActiveEmergency!.isOffline,
        );
      }
    }

    _checkExistingActiveEmergency();

    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
      _isLoadingLocation = false;
    }

    _notificationService?.init();
    ResponderModeService.instance.initialize();
    _initLocation();
    _initAccidentDetection();
    _loadUserProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PermissionRequestDialog.showIfNeeded(context);
        final pendingId = NotificationService.pendingEmergencyId;
        if (pendingId != null && pendingId.isNotEmpty) {
          NotificationService.pendingEmergencyId = null;
          AppNavigator.navigateToEmergencyDetails(context, pendingId);
        }
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final user = _auth?.currentUser;
    if (user != null) {
      UserModel? profile = await _authService.getUserProfile(user.uid);
      if (mounted) {
        setState(() => _userProfile = profile);
      }
    }
  }

  Future<void> _initAccidentDetection() async {
    await _accidentDetectionService.initialize();
    _accidentSubscription = _accidentDetectionService.possibleAccidentStream.listen((result) {
      if (mounted && !_isCreatingSOS) {
        AccidentDetectionDialog.show(
          context: context,
          reasoning: result.reasoning,
          onConfirmAutoSOS: _executeSOS,
          onCancel: () {
            if (mounted) {
              AppSnackbar.showSuccess(context, "Emergency cancelled — you're safe.");
            }
          },
        );
      }
    });
  }

  Future<void> _initLocation() async {
    Position? pos = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });
    }

    _locationSubscription?.cancel();
    _locationSubscription = _locationService.onPositionChanged.listen((updatedPos) {
      if (mounted) {
        final wasNull = _currentPosition == null;
        setState(() {
          _currentPosition = updatedPos;
          _isLoadingLocation = false;
        });
        if (wasNull) {
          _listenToAlerts(updatedPos.latitude, updatedPos.longitude, _auth?.currentUser?.uid ?? 'offline_user');
        }
      }
    });

    _locationService.startLocationUpdates();

    if (pos != null) {
      _listenToAlerts(pos.latitude, pos.longitude, _auth?.currentUser?.uid ?? 'offline_user');
    }
  }

  void _listenToAlerts(double lat, double lon, String uid) {
    _nearbySubscription?.cancel();
    _nearbySubscription = _communicationManager
        .listenForAlerts(userLat: lat, userLon: lon, currentUserId: uid)
        .listen((emergencies) async {
      if (emergencies.isNotEmpty && mounted) {
        final currentUid = _auth?.currentUser?.uid ?? uid;
        final myDeviceId = await LocalDatabaseService.getOrCreateLocalDeviceId();
        for (var alert in emergencies) {
          final isOwnDevice = alert.originDeviceId != null && alert.originDeviceId == myDeviceId;
          final isOwnAuthUser = currentUid != 'offline_user' && alert.victimId == currentUid;
          if (isOwnDevice || isOwnAuthUser) {
            continue;
          }

          if (alert.status == EmergencyStatus.SEARCHING &&
              !_alertedEmergencyIds.contains(alert.id) &&
              !_emergencyService.isEmergencyDeclined(alert.id)) {
            _alertedEmergencyIds.add(alert.id);
            // Allow 60 minutes for offline P2P to absorb device clock skew; 5 minutes for online
            if (alert.isOffline) {
              if (!OfflineCommunicationService.isOfflineAlertFresh(alert.createdAt)) {
                P2PDiagnostics.log(alert.id, 'ALERT_SKIPPED_CLOCK_SKEW', {
                  'skewMinutes': DateTime.now().difference(alert.createdAt).inMinutes.abs(),
                });
                continue;
              }
            } else {
              if (DateTime.now().difference(alert.createdAt).inMinutes.abs() > 5) {
                continue;
              }
            }
            if (_currentMode == CommunicationMode.online && currentUid != 'offline_user') {
              _emergencyService.markUserNotified(alert.id, currentUid);
            }

            double? distMeters;
            if (_currentPosition != null) {
              distMeters = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                alert.latitude,
                alert.longitude,
              );
            }
            NotificationService.showEmergencyAlertNotification(
              emergencyId: alert.id,
              type: alert.type,
              distanceMeters: distMeters,
              isOffline: alert.isOffline,
              status: alert.status,
            );

            _showNearbyEmergencyDialog(alert);
            break;
          }
        }
      }
    });
  }

  void _showNearbyEmergencyDialog(EmergencyModel emergency) {
    if (!mounted) return;
    AppDialogs.showNearbyEmergencyDialog(
      context: context,
      emergency: emergency,
      mode: _currentMode,
      userRole: _userProfile?.userRole ?? 'CITIZEN',
      vehicleNumber: _userProfile?.vehicleNumber,
      onViewEmergency: () {
        if (mounted) {
          AppNavigator.navigateToEmergencyDetails(context, emergency.id);
        }
      },
      onDecline: () {
        _emergencyService.markEmergencyDeclined(emergency.id);
      },
    );
  }

  void _executeSOS() async {
    if (_isCreatingSOS) return;

    if (mounted) setState(() => _isCreatingSOS = true);
    try {
      Position? pos = _currentPosition ?? await _locationService.getCurrentLocation();
      pos ??= Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      String emergencyId = await _communicationManager.broadcastSOS(
        position: pos,
        currentUserId: _auth?.currentUser?.uid ?? 'offline_user',
      );
      _alertedEmergencyIds.add(emergencyId);
      EmergencySoundService.playSOSSentSound();

      if (!mounted) return;

      AppNavigator.navigateToEmergencyMap(context, emergencyId);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        "Couldn't send SOS right now. Call official emergency services directly or try again.",
      );
    } finally {
      if (mounted) setState(() => _isCreatingSOS = false);
    }
  }

  void _recenterMap() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
    }
  }

  void _checkExistingActiveEmergency() async {
    try {
      final currentUid = _auth?.currentUser?.uid ?? 'offline_user';
      final active = await _localDb.getActiveEmergency(userId: currentUid);
      if (active != null && active.isActive && mounted) {
        setState(() {
          _activeEmergency = active;
        });
        _subscribeToActiveEmergency(active.id, isOffline: active.isOffline);
      }
    } catch (_) {}
  }

  void _subscribeToActiveEmergency(String emergencyId, {bool isOffline = false}) {
    if (_subscribedEmergencyId == emergencyId && _activeEmergencySubscription != null) {
      return;
    }
    _activeEmergencySubscription?.cancel();
    _subscribedEmergencyId = emergencyId;

    if (isOffline || emergencyId.startsWith('JS-OFF-')) {
      _activeEmergencySubscription = _localDb.streamEmergency(emergencyId).listen((em) {
        if (!mounted) return;
        setState(() {
          if (em == null || em.isTerminal) {
            _activeEmergency = null;
            _activeEmergencySubscription?.cancel();
            _activeEmergencySubscription = null;
            _subscribedEmergencyId = null;
          } else {
            _activeEmergency = em;
          }
        });
      });
    } else {
      _activeEmergencySubscription = _emergencyService.streamEmergency(emergencyId).listen((em) {
        if (!mounted) return;
        setState(() {
          if (em.isTerminal) {
            _activeEmergency = null;
            _activeEmergencySubscription?.cancel();
            _activeEmergencySubscription = null;
            _subscribedEmergencyId = null;
          } else {
            _activeEmergency = em;
          }
        });
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _activeEmergencySubscription?.cancel();
    _locationSubscription?.cancel();
    _localEmergencyUpdateSub?.cancel();
    _accidentSubscription?.cancel();
    _modeSubscription?.cancel();
    _nearbySubscription?.cancel();
    _notificationService?.dispose();
    _communicationManager.dispose();
    _locationService.stopLocationUpdates();
    super.dispose();
  }

  Widget _buildAppDrawer(BuildContext context) {
    return AppDrawer(
      currentIndex: _currentIndex,
      onIndexChanged: (index) {
        setState(() => _currentIndex = index);
      },
      userProfile: _userProfile,
    );
  }

  Widget _buildActiveEmergencyBanner(EmergencyModel emergency) {
    final currentUid = _auth?.currentUser?.uid ?? 'offline_user';
    final isVictim = emergency.victimId == currentUid || (currentUid == 'offline_user' && emergency.isOffline);
    final isPrimary = emergency.isPrimaryResponder(currentUid);

    String statusText;
    if (isVictim) {
      statusText = emergency.status == EmergencyStatus.SEARCHING
          ? 'Searching for nearby helpers...'
          : emergency.status == EmergencyStatus.ASSIGNED
              ? 'Helper Assigned & Preparing'
              : emergency.status == EmergencyStatus.APPROACHING
                  ? 'Helper En-Route to Your Location'
                  : 'Helper Has Arrived at Scene';
    } else {
      statusText = emergency.status == EmergencyStatus.ASSIGNED
          ? (isPrimary ? 'Assigned as Primary Responder' : 'On Standby for Rescue')
          : emergency.status == EmergencyStatus.APPROACHING
              ? 'En-Route to Victim Location'
              : emergency.status == EmergencyStatus.ARRIVED
                  ? 'Arrived at Emergency Scene'
                  : 'Active Emergency';
    }

    String title = isVictim ? 'EMERGENCY IN PROGRESS' : 'ACTIVE RESCUE ASSIGNMENT';
    String actionLabel = isVictim ? 'RESUME LIVE ASSISTANCE' : 'RESUME NAVIGATION';

    return AppStatusContainer(
      status: AppStatusType.emergency,
      customTitle: title,
      customSubtitle: '$statusText • Created at ${emergency.createdAt.hour.toString().padLeft(2, '0')}:${emergency.createdAt.minute.toString().padLeft(2, '0')}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: const BoxDecoration(
          color: AppColors.emergencyRed,
          borderRadius: AppShapes.small,
        ),
        child: Text(
          emergency.status.name,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: AppButton.destructive(
          label: actionLabel,
          icon: const Icon(Icons.navigation_rounded, size: 18),
          isCompact: true,
          onPressed: () {
            AppNavigator.navigateToEmergencyMap(context, emergency.id);
          },
        ),
      ),
    );
  }

  void _showTelemetryDetails(BuildContext context) {
    if (_currentPosition == null) return;
    final pos = _currentPosition!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surfacePureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.satellite_alt_rounded, size: 18, color: AppColors.softBlue),
                      const SizedBox(width: 8),
                      Text(
                        'GPS & Location Details',
                        style: AppTypography.subheading.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const AppDivider(),
              const SizedBox(height: 8),
              _buildTelemetryRow('Latitude', '${pos.latitude.toStringAsFixed(6)}°'),
              _buildTelemetryRow('Longitude', '${pos.longitude.toStringAsFixed(6)}°'),
              _buildTelemetryRow('GPS Accuracy', '±${pos.accuracy.toStringAsFixed(1)} m'),
              _buildTelemetryRow('Movement Speed', '${(pos.speed * 3.6).toStringAsFixed(1)} km/h'),
              _buildTelemetryRow('Elevation', '${pos.altitude.toStringAsFixed(1)} m'),
              _buildTelemetryRow('Last Updated', '${pos.timestamp.hour.toString().padLeft(2, '0')}:${pos.timestamp.minute.toString().padLeft(2, '0')}:${pos.timestamp.second.toString().padLeft(2, '0')}'),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySecondary.copyWith(fontSize: 13)),
          Text(
            value,
            style: AppTypography.numericCompact.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.deepNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightContextArea(bool isOnline, String userName, String roleLabel) {
    String roleDisplay = roleLabel == 'AMBULANCE_DRIVER'
        ? '🚑 Ambulance Unit'
        : roleLabel == 'POLICE_PCR'
            ? '🚓 Police PCR Unit'
            : 'Citizen Responder';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.subtleBlueGray.withValues(alpha: 0.6),
        borderRadius: AppShapes.medium,
        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.7), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: InkWell(
                  onTap: () => AppNavigator.navigateToResponderDashboard(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? AppColors.emeraldGreen : AppColors.warningAmber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            roleDisplay,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepNavy,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_accidentDetectionService.isEnabled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyLightRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors_rounded, size: 9, color: AppColors.emergencyRed),
                          SizedBox(width: 2),
                          Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emergencyRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: () {
                      setState(() => _isConnectivityExpanded = !_isConnectivityExpanded);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isOnline ? 'Online' : 'Offline P2P',
                            style: AppTypography.caption.copyWith(
                              color: isOnline ? AppColors.emeraldGreen : AppColors.warningAmber,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _isConnectivityExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.chevron_right_rounded,
                            size: 13,
                            color: isOnline ? AppColors.emeraldGreen : AppColors.warningAmber,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Community mutual-aid active',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    'Official primary',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            child: _isConnectivityExpanded
                ? (isOnline ? _buildOnlineExpandedDetails() : _buildOfflineExpandedDetails())
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineExpandedDetails() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.warningAmber),
              SizedBox(width: 6),
              Text(
                'Offline P2P',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Nearby emergency communication is available without internet.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: AppDivider(),
          ),
          _buildReadinessRow('Bluetooth', true),
          const SizedBox(height: 4),
          _buildReadinessRow('Nearby P2P', true),
          const SizedBox(height: 4),
          _buildReadinessRow('Local cache', true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.subtleBlueGray,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textMuted),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Online map tiles and road routing require internet.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.subtleBlueGray,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 12, color: AppColors.textMuted),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Vita ResQ is a community emergency-response platform and does not replace official emergency services.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessRow(String label, bool isReady) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.deepNavy,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isReady ? AppColors.emeraldGreen : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isReady ? 'Ready' : 'Unavailable',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isReady ? AppColors.emeraldGreen : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlineExpandedDetails() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.emeraldGreen),
              SizedBox(width: 6),
              Text(
                'Online Network',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Emergency network connected.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: AppDivider(),
          ),
          _buildOnlineStatusItem('Nearby responder discovery available.'),
          const SizedBox(height: 4),
          _buildOnlineStatusItem('Push notifications connected.'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.subtleBlueGray,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 12, color: AppColors.textMuted),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Vita ResQ is a community emergency-response platform and does not replace official emergency services.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStatusItem(String text) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emeraldGreen,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediumLiveMap() {
    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppShapes.card,
      child: ClipRRect(
        borderRadius: AppShapes.card,
        child: SizedBox(
          height: 190,
          width: double.infinity,
          child: Stack(
            children: [
              _isLoadingLocation
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.softBlue),
                    )
                  : _currentPosition != null
                      ? RealMapWidget(
                          initialPosition: _currentPosition!,
                          mapController: _mapController,
                          initialZoom: 16.0,
                        )
                      : const Center(
                          child: Text(
                            'GPS coordinates unavailable',
                            style: AppTypography.bodySecondary,
                          ),
                        ),
              // Top Overlay Controls
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite.withValues(alpha: 0.92),
                        borderRadius: AppShapes.small,
                        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPosition != null ? AppColors.softBlue : AppColors.warningAmber,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _currentPosition != null ? 'GPS Active' : 'Acquiring GPS...',
                            style: AppTypography.metadata.copyWith(
                              color: AppColors.deepNavy,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppIconButton.filled(
                      icon: Icons.near_me_rounded,
                      tooltip: 'Recenter Map',
                      size: 36,
                      iconSize: 18,
                      backgroundColor: AppColors.surfacePureWhite.withValues(alpha: 0.95),
                      color: AppColors.softBlue,
                      onPressed: _currentPosition != null ? _recenterMap : null,
                    ),
                  ],
                ),
              ),
              // Unobtrusive Telemetry Micro-Pill (Secondary, non-competing)
              if (_currentPosition != null)
                Positioned(
                  bottom: 8,
                  left: 10,
                  child: InkWell(
                    onTap: () => _showTelemetryDetails(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.7)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 10, color: AppColors.brandBlue),
                          const SizedBox(width: 4),
                          Text(
                            'GPS Active',
                            style: AppTypography.metadata.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
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

  Widget _buildResponderAvailabilityCard() {
    final service = ResponderModeService.instance;
    return StreamBuilder<bool>(
      stream: service.availabilityStream,
      initialData: service.isAvailable,
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? false;

        return AppCard(
          padding: const EdgeInsets.all(14),
          borderRadius: AppShapes.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppColors.emeraldGreen.withValues(alpha: 0.12)
                          : AppColors.softBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAvailable ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                      size: 18,
                      color: isAvailable ? AppColors.emeraldGreen : AppColors.softBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAvailable ? 'Responder mode active' : 'Responder Available',
                      style: AppTypography.subheading.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppColors.emeraldGreen.withValues(alpha: 0.12)
                          : AppColors.subtleBlueGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAvailable ? AppColors.emeraldGreen : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAvailable ? 'Active' : 'Standby',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isAvailable ? AppColors.emeraldGreen : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Responder Mode keeps Vita ResQ active in the background while the service remains running and permitted by Android. Device/OEM restrictions may terminate it.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.battery_charging_full_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Uses foreground service • Android 15 limits background dataSync to 6h per 24h',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: isAvailable
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.stop_circle_outlined, size: 16),
                        label: const Text('Stop responding'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emergencyRed,
                          side: const BorderSide(color: AppColors.emergencyRed, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await service.stopResponderMode();
                          if (mounted) setState(() {});
                        },
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.radar_rounded, size: 16),
                        label: const Text('Go Available'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.softBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final uid = _auth?.currentUser?.uid ?? 'offline_user';
                          final lat = _currentPosition?.latitude;
                          final lon = _currentPosition?.longitude;
                          await service.startResponderMode(
                            latitude: lat,
                            longitude: lon,
                            userId: uid,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex == 1) {
      return EmergencyHistoryScreen(
        onBackPressed: () => setState(() => _currentIndex = 0),
      );
    }
    if (_currentIndex == 2) {
      return ProfileScreen(
        onBackPressed: () => setState(() => _currentIndex = 0),
      );
    }

    bool isOnline = _currentMode == CommunicationMode.online;
    String userName = _userProfile?.name ?? _auth?.currentUser?.displayName ?? 'Community Volunteer';
    String roleLabel = _userProfile?.userRole ?? 'CITIZEN';

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      drawer: _buildAppDrawer(context),
      appBar: AppBar(
        backgroundColor: AppColors.warmOffWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.deepNavy,
              size: AppSpacing.iconLg,
            ),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. STATUS / LIGHT CONTEXTUAL INFORMATION
              if (_activeEmergency != null && _activeEmergency!.isActive) ...[
                _buildActiveEmergencyBanner(_activeEmergency!),
                AppSpacing.gapVerticalMd,
              ],
              _buildLightContextArea(isOnline, userName, roleLabel),
              AppSpacing.gapVerticalMd,

              // 2. MEDIUM LIVE MAP
              _buildMediumLiveMap(),
              AppSpacing.gapVerticalLg,

              // 3. EMERGENCY HELP PROMPT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  children: [
                    Text(
                      'Need emergency help?',
                      style: AppTypography.sectionHeading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepNavy,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapVerticalXs,
                    Text(
                      'Hold the button below to dispatch an SOS to verified responders and emergency contacts.',
                      style: AppTypography.bodySecondary.copyWith(
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapVerticalLg,

              // 4. LARGE CIRCULAR SOS
              _isCreatingSOS
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              color: AppColors.emergencyRed,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Activating Emergency...',
                            style: AppTypography.subheading.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emergencyRed,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Broadcasting to nearby verified responders',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SOSButton(
                      size: 200,
                      holdDuration: const Duration(milliseconds: 2000),
                      onSOSActivated: _executeSOS,
                    ),
              AppSpacing.gapVerticalMd,

              // 5. "Hold for help" & Accidental Tap Notice
              Text(
                'Hold for help',
                style: AppTypography.subheading.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              AppSpacing.gapVerticalXs,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Press and hold for 2 seconds • Accidental taps ignored',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVerticalLg,

              // 6. RESPONDER AVAILABILITY (BACKGROUND MODE)
              _buildResponderAvailabilityCard(),
              AppSpacing.gapVerticalXxl,
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
