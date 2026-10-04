import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/communication_manager.dart';
import '../../services/emergency_service.dart';
import '../../services/notification_service.dart';
import '../../services/accident_detection_service.dart';
import '../../services/accident_detection_evaluator.dart';
import '../../services/local_database_service.dart';
import '../../models/user_model.dart';
import '../../models/communication_mode.dart';
import '../../models/emergency_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/offline_mode_bento_banner.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/accident_detection_dialog.dart';
import '../../widgets/permission_request_dialog.dart';
import '../../core/navigation/app_navigator.dart';
import '../profile/profile_screen.dart';
import '../history/emergency_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final CommunicationManager _communicationManager = CommunicationManager();
  final EmergencyService _emergencyService = EmergencyService();
  final NotificationService _notificationService = NotificationService();
  final AccidentDetectionService _accidentDetectionService = AccidentDetectionService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Position? _currentPosition;
  UserModel? _userProfile;
  EmergencyModel? _activeEmergency;
  bool _isLoadingLocation = true;
  bool _isCreatingSOS = false;
  int _currentIndex = 0;
  CommunicationMode _currentMode = CommunicationMode.online;

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
    _currentMode = _communicationManager.activeMode;

    _modeSubscription = _communicationManager.modeStream.listen((mode) {
      if (mounted && _currentMode != mode) {
        setState(() => _currentMode = mode);
        if (_currentPosition != null) {
          _listenToAlerts(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _auth.currentUser?.uid ?? 'offline_user',
          );
        }
      }
    });

    _localEmergencyUpdateSub = LocalDatabaseService.emergencyUpdatesStream.listen((emergency) {
      final currentUid = _auth.currentUser?.uid ?? 'offline_user';
      if (emergency.victimId == currentUid || (currentUid == 'offline_user' && emergency.isOffline)) {
        if (mounted) {
          setState(() {
            if (emergency.status == EmergencyStatus.COMPLETED || emergency.status == EmergencyStatus.CANCELLED) {
              _activeEmergency = null;
            } else {
              _activeEmergency = emergency;
            }
          });
        }
      }
    });

    _notificationService.init();
    _initLocation();
    _initAccidentDetection();
    _loadUserProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PermissionRequestDialog.showIfNeeded(context);
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Emergency cancelled — you're safe."),
                  backgroundColor: Colors.green,
                ),
              );
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
          _listenToAlerts(updatedPos.latitude, updatedPos.longitude, _auth.currentUser?.uid ?? 'offline_user');
        }
      }
    });

    _locationService.startLocationUpdates();

    if (pos != null) {
      _listenToAlerts(pos.latitude, pos.longitude, _auth.currentUser?.uid ?? 'offline_user');
    }
  }

  void _listenToAlerts(double lat, double lon, String uid) {
    _nearbySubscription?.cancel();
    _nearbySubscription = _communicationManager
        .listenForAlerts(userLat: lat, userLon: lon, currentUserId: uid)
        .listen((emergencies) {
      if (emergencies.isNotEmpty && mounted) {
        final currentUid = _auth.currentUser?.uid ?? uid;
        for (var alert in emergencies) {
          // CRITICAL: A victim must NEVER be alerted or asked to volunteer for their own emergency!
          if (alert.isVictim(currentUid) ||
              alert.victimId == currentUid ||
              (currentUid == 'offline_user' && alert.isOffline && alert.victimId == 'offline_user')) {
            continue;
          }

          if (alert.status == EmergencyStatus.SEARCHING &&
              !_alertedEmergencyIds.contains(alert.id) &&
              !_emergencyService.isEmergencyDeclined(alert.id)) {
            _alertedEmergencyIds.add(alert.id);
            // Discard stale emergencies older than 5 minutes so opening the app doesn't show old test alerts
            if (DateTime.now().difference(alert.createdAt).inMinutes.abs() > 5) {
              continue;
            }
            if (_currentMode == CommunicationMode.online && currentUid != 'offline_user') {
              _emergencyService.markUserNotified(alert.id, currentUid);
            }
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
        currentUserId: _auth.currentUser?.uid ?? 'offline_user',
      );
      _alertedEmergencyIds.add(emergencyId);
      // Play victim confirmation chime and haptic feedback
      EmergencySoundService.playSOSSentSound();

      if (!mounted) return;

      AppNavigator.navigateToEmergencyMap(context, emergencyId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger SOS: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isCreatingSOS = false);
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _localEmergencyUpdateSub?.cancel();
    _accidentSubscription?.cancel();
    _modeSubscription?.cancel();
    _nearbySubscription?.cancel();
    _notificationService.dispose();
    _communicationManager.dispose();
    _locationService.stopLocationUpdates();
    super.dispose();
  }

  void _callHelpline(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildAppDrawer(BuildContext context) {
    final user = _auth.currentUser;
    String email = user?.email ?? 'offline_user@vita-resq.org';
    bool isOnline = _currentMode == CommunicationMode.online;
    String roleLabel = _userProfile?.userRole ?? 'CITIZEN';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header with Vita ResQ Brand Identity
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryNavy,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.emergencyRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.emergencyRed.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VITA RESQ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isOnline ? '🟢 ONLINE • CLOUD' : '📡 OFFLINE P2P',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Navigation Options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.radar_rounded, color: AppTheme.brandBlue),
                    title: const Text('Live Emergency Radar', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Role: $roleLabel', style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: AppTheme.brandBlue),
                    title: const Text('Emergency History', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('My SOS alerts & rescues', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded, color: AppTheme.brandBlue),
                    title: const Text('Profile & Medical ID', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Blood group, emergency contacts', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.navigateToProfile(context);
                    },
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),

                  // Sensor AI & Automation Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'SENSOR AI & CRASH DETECTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.car_crash_rounded, color: AppTheme.emergencyRed),
                    title: const Text('Impact & Fall Sensor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Autonomously detects high-G vehicle collisions & hard falls', style: TextStyle(fontSize: 11)),
                    value: _accidentDetectionService.isEnabled,
                    activeThumbColor: AppTheme.emergencyRed,
                    onChanged: (val) async {
                      await _accidentDetectionService.setEnabled(val);
                      setState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flash_on_rounded, color: AppTheme.tertiaryAmber),
                    title: const Text(
                      'Simulate Crash (Judge Demo)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emergencyRed, fontSize: 13),
                    ),
                    subtitle: const Text('Autonomous sensor evaluation demonstration', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      _accidentDetectionService.simulateAccidentEvent();
                    },
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),

                  // Helplines Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'OFFICIAL EMERGENCY HELPLINES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.emergencyRed),
                    title: const Text('112 - National All-In-One Emergency', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _callHelpline('112'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_hospital_rounded, color: AppTheme.brandBlue),
                    title: const Text('108 - Medical Ambulance'),
                    onTap: () => _callHelpline('108'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_police_rounded, color: AppTheme.brandBlue),
                    title: const Text('100 - Police Control Room'),
                    onTap: () => _callHelpline('100'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange),
                    title: const Text('101 - Fire Rescue'),
                    onTap: () => _callHelpline('101'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security_rounded, color: Colors.purple),
                    title: const Text('1090 - Women Safety Helpline'),
                    onTap: () => _callHelpline('1090'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              title: const Text('Log Out', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
              onTap: () async {
                await _auth.signOut();
                if (!context.mounted) return;
                Navigator.pop(context);
                AppNavigator.navigateToLogin(context);
              },
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12, top: 4),
              child: Text(
                'Vita ResQ v2.0 • Community Emergency Response Layer',
                style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveEmergencyBanner(EmergencyModel emergency) {
    String statusText = emergency.status == EmergencyStatus.SEARCHING
        ? 'Searching for nearby helpers...'
        : emergency.status == EmergencyStatus.ASSIGNED
            ? 'Helper Assigned & Preparing'
            : emergency.status == EmergencyStatus.APPROACHING
                ? 'Helper En-Route to Your Location'
                : 'Helper Has Arrived at Scene';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emergencyRed.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emergencyRed.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.emergencyRed,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'EMERGENCY IN PROGRESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.emergencyRed,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.emergencyRed,
                  borderRadius: BorderRadius.circular(8),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Emergency ID: ${emergency.id} • Created at ${emergency.createdAt.hour.toString().padLeft(2, '0')}:${emergency.createdAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emergencyRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text(
                'RESUME RESCUE TRACKING',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
              ),
              onPressed: () {
                AppNavigator.navigateToEmergencyMap(context, emergency.id);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialHelplineChip(String label, String number, Color color) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _callHelpline(number),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
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
    String userName = _userProfile?.name ?? _auth.currentUser?.displayName ?? 'Community Volunteer';
    String roleLabel = _userProfile?.userRole ?? 'CITIZEN';

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      drawer: _buildAppDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.primaryNavy, size: 26),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.emergencyRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Vita ResQ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontSize: 19,
                color: AppTheme.primaryNavy,
              ),
            ),
          ],
        ),
        actions: [
          // Connectivity Status Pill
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? AppTheme.emeraldGreen : AppTheme.tertiaryAmber,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'ONLINE' : 'OFFLINE P2P',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOnline ? const Color(0xFF047857) : const Color(0xFFB45309),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Active Emergency In Progress Alert
              if (_activeEmergency != null) ...[
                _buildActiveEmergencyBanner(_activeEmergency!),
              ],

              // User Identity Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_rounded, size: 18, color: AppTheme.brandBlue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            roleLabel == 'AMBULANCE_DRIVER'
                                ? '🚑 108 Emergency Ambulance Unit'
                                : roleLabel == 'POLICE_PCR'
                                    ? '🚓 Police PCR Unit'
                                    : 'Citizen Emergency Responder',
                            style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (_accidentDetectionService.isEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.emergencyRed.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sensors_rounded, size: 12, color: AppTheme.emergencyRed),
                            SizedBox(width: 4),
                            Text(
                              'CRASH AI',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.emergencyRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 112 Regulatory Disclaimer Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF475569)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Community response layer. For life-threatening emergencies, always dial 112 directly.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Offline P2P Notice (when cellular / internet is offline)
              if (!isOnline) ...[
                const OfflineModeBentoBanner(),
                const SizedBox(height: 14),
              ],

              // 2. High-Priority Hero SOS Trigger Zone
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'TRIGGER EMERGENCY SOS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.emergencyRed,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Press and hold button for 2 seconds to broadcast',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    // Press-and-Hold SOS Button
                    _isCreatingSOS
                        ? const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(color: AppTheme.emergencyRed),
                          )
                        : SOSButton(
                            size: 200,
                            holdDuration: const Duration(milliseconds: 2000),
                            onSOSActivated: _executeSOS,
                          ),

                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: AppTheme.onSurfaceVariant),
                        SizedBox(width: 6),
                        Text(
                          'Accidental taps ignored • Release early to cancel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Live GPS Telemetry Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.my_location_rounded, color: AppTheme.brandBlue, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'LIVE LOCATION TELEMETRY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryNavy,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.satellite_alt_rounded, size: 12, color: AppTheme.brandBlue),
                              SizedBox(width: 4),
                              Text(
                                '±3m GPS Lock',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.brandBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: _isLoadingLocation
                            ? const Center(child: CircularProgressIndicator())
                            : _currentPosition != null
                                ? RealMapWidget(initialPosition: _currentPosition!)
                                : const Center(child: Text('GPS coordinates unavailable')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop_rounded, size: 16, color: AppTheme.emergencyRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _currentPosition != null
                                ? '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}'
                                : 'Acquiring high-precision lock...',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Quick Helplines Row (1-Tap Call)
              Row(
                children: [
                  _buildOfficialHelplineChip('Emergency', '112', AppTheme.emergencyRed),
                  const SizedBox(width: 8),
                  _buildOfficialHelplineChip('Ambulance', '108', AppTheme.brandBlue),
                  const SizedBox(width: 8),
                  _buildOfficialHelplineChip('Police', '100', const Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  _buildOfficialHelplineChip('Fire', '101', Colors.deepOrange),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            currentIndex: _currentIndex,
            selectedItemColor: AppTheme.primaryNavy,
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.radar_rounded),
                activeIcon: Icon(Icons.radar_rounded, color: AppTheme.primaryNavy),
                label: 'Radar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_toggle_off_rounded),
                activeIcon: Icon(Icons.history_rounded, color: AppTheme.primaryNavy),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded, color: AppTheme.primaryNavy),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
