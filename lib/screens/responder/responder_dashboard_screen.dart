import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/emergency_model.dart';
import '../../models/user_model.dart';
import '../../services/emergency_service.dart';
import '../../services/emergency_claim_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/incoming_emergency_card.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_feedback.dart';
import '../../core/navigation/app_navigator.dart';
import '../history/emergency_history_screen.dart';
import '../profile/profile_screen.dart';

/// Vita ResQ Responder Dashboard & Radar Screen — Phase 7 UI Redesign.
///
/// Designed for glanceability, fast action, and calmness under pressure:
/// 1. Header with personalized greeting ("Good evening, [Name]")
/// 2. Clear RESPONDER STATUS: [ AVAILABLE ] / [ UNAVAILABLE ] (touch target >= 48dp)
/// 3. Nearby emergencies count badge
/// 4. Subtle, calming radar visualization (zero raw coordinates or debug data)
/// 5. NEAREST INCIDENT: prioritized [ I CAN HELP ] touch target
/// 6. OTHER NEARBY: concise incident rows
class ResponderDashboardScreen extends StatefulWidget {
  final List<EmergencyModel>? initialEmergencies;
  final UserModel? initialUserProfile;
  final bool? initialIsAvailable;
  final Position? initialPosition;
  final Function(String emergencyId)? onEmergencyClaimed;

  const ResponderDashboardScreen({
    super.key,
    this.initialEmergencies,
    this.initialUserProfile,
    this.initialIsAvailable,
    this.initialPosition,
    this.onEmergencyClaimed,
  });

  @override
  State<ResponderDashboardScreen> createState() => _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final EmergencyService _emergencyService = EmergencyService();
  final EmergencyClaimService _claimService = EmergencyClaimService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();

  late bool _isAvailable;
  UserModel? _userProfile;
  Position? _currentPosition;
  List<EmergencyModel> _emergencies = [];
  StreamSubscription<List<EmergencyModel>>? _emergenciesSubscription;
  StreamSubscription<Position>? _positionSubscription;
  String? _claimingEmergencyId;
  int _currentNavIndex = 0;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _isAvailable = widget.initialIsAvailable ?? true;
    _userProfile = widget.initialUserProfile;
    _currentPosition = widget.initialPosition;
    if (widget.initialEmergencies != null) {
      _emergencies = List.from(widget.initialEmergencies!);
    }

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _loadInitialData();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _emergenciesSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _loadInitialData() async {
    // Safely load profile if not passed
    if (_userProfile == null) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final profile = await _authService.getUserProfile(currentUser.uid);
          if (mounted && profile != null) {
            setState(() => _userProfile = profile);
          }
        }
      } catch (_) {}
    }

    // Safely acquire GPS location if not passed
    if (_currentPosition == null) {
      try {
        final pos = await _locationService.getCurrentLocation();
        if (mounted && pos != null) {
          setState(() => _currentPosition = pos);
        }
      } catch (_) {}
    }

    // Listen to device GPS updates
    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() => _currentPosition = pos);
        }
      });
    } catch (_) {}

    // Stream nearby searching emergencies if not pre-provided
    if (widget.initialEmergencies == null) {
      _subscribeToEmergencies();
    }
  }

  void _subscribeToEmergencies() {
    _emergenciesSubscription?.cancel();
    if (!_isAvailable) {
      setState(() => _emergencies = []);
      return;
    }

    final lat = _currentPosition?.latitude ?? 0.0;
    final lon = _currentPosition?.longitude ?? 0.0;

    try {
      _emergenciesSubscription = _emergencyService
          .streamNearbySearchingEmergencies(lat, lon)
          .listen((list) {
        if (mounted) {
          setState(() => _emergencies = list);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _toggleAvailability(bool value) {
    setState(() {
      _isAvailable = value;
      if (!_isAvailable) {
        _emergenciesSubscription?.cancel();
        _emergencies = [];
      } else {
        if (widget.initialEmergencies != null) {
          _emergencies = List.from(widget.initialEmergencies!);
        } else {
          _subscribeToEmergencies();
        }
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  double? _calculateDistance(EmergencyModel emergency) {
    if (_currentPosition == null) return null;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      emergency.latitude,
      emergency.longitude,
    );
  }

  void _handleClaimEmergency(EmergencyModel emergency) async {
    setState(() => _claimingEmergencyId = emergency.id);

    if (widget.onEmergencyClaimed != null) {
      widget.onEmergencyClaimed!(emergency.id);
      return;
    }

    try {
      final role = await _claimService.acceptAndRespond(emergency.id);
      if (!mounted) return;

      if (role != null) {
        AppSnackbar.showSuccess(
          context,
          'Accepted emergency as ${role.name}. You are responding!',
        );
        AppNavigator.navigateToEmergencyMap(context, emergency.id);
      } else {
        AppSnackbar.showWarning(
          context,
          'Emergency already handled or no longer active.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          "Couldn't claim emergency. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _claimingEmergencyId = null);
    }
  }

  Widget _buildRadarCircle() {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(64, 64),
          painter: _RadarPulsePainter(progress: _radarController.value),
        );
      },
    );
  }

  Widget _buildStatusSection() {
    final activeCount = _emergencies.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: AppShapes.card,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESPONDER STATUS',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isAvailable
                              ? AppColors.emeraldGreen
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _isAvailable
                              ? AppColors.deepNavy
                              : AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Accessible Switch with >= 48dp touch area
              Semantics(
                label: _isAvailable
                    ? 'Responder status: Available. Tap to set unavailable.'
                    : 'Responder status: Unavailable. Tap to set available.',
                child: SizedBox(
                  height: 48,
                  width: 60,
                  child: Center(
                    child: Switch.adaptive(
                      value: _isAvailable,
                      activeTrackColor: AppColors.emeraldGreen,
                      onChanged: _toggleAvailability,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      size: 16,
                      color: AppColors.brandBlue,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Nearby emergencies',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _isAvailable && activeCount > 0
                      ? AppColors.emergencyRed.withValues(alpha: 0.12)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAvailable && activeCount > 0
                        ? AppColors.emergencyRed.withValues(alpha: 0.3)
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Text(
                  _isAvailable
                      ? (activeCount > 0 ? '$activeCount active' : '0 nearby')
                      : 'Paused',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _isAvailable && activeCount > 0
                        ? AppColors.emergencyRed
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: AppShapes.card,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isAvailable
              ? _buildRadarCircle()
              : const Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
          const SizedBox(height: 16),
          Text(
            _isAvailable ? 'Scanning for nearby incidents' : 'Responder Status Paused',
            style: AppTypography.subheading.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _isAvailable
                ? 'Your status is active. We\'ll alert you immediately if someone needs help nearby.'
                : 'Toggle your status to Available when you are ready to receive emergency dispatches.',
            style: AppTypography.bodySecondary.copyWith(
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOtherNearbyRow(EmergencyModel item) {
    final distance = _calculateDistance(item);
    String distStr = distance != null
        ? (distance < 1000 ? '${distance.round()}m' : '${(distance / 1000).toStringAsFixed(1)}km')
        : '${(item.currentRadiusMeters / 1000).toStringAsFixed(1)}km';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.type.toUpperCase() == 'MEDICAL'
                  ? Icons.medical_services_outlined
                  : Icons.emergency_outlined,
              size: 18,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.type.toUpperCase()} ALERT',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$distStr away • ${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: const BorderSide(color: AppColors.borderSubtle),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => AppNavigator.navigateToEmergencyDetails(context, item.id),
            child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNavIndex == 1) {
      return EmergencyHistoryScreen(
        onBackPressed: () => setState(() => _currentNavIndex = 0),
      );
    }
    if (_currentNavIndex == 2) {
      return ProfileScreen(
        onBackPressed: () => setState(() => _currentNavIndex = 0),
      );
    }

    final userName = _userProfile?.name ?? 'Volunteer';
    final nearest = _emergencies.isNotEmpty ? _emergencies.first : null;
    final otherList = _emergencies.length > 1 ? _emergencies.sublist(1) : <EmergencyModel>[];

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: AppColors.surfacePureWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepNavy),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderSubtle, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                '${_getGreeting()}, $userName',
                style: AppTypography.sectionHeading.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mutual-aid emergency response network',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              AppSpacing.gapVerticalLg,

              // RESPONDER STATUS CARD
              _buildStatusSection(),
              AppSpacing.gapVerticalLg,

              // INCIDENTS SECTION
              if (!_isAvailable || _emergencies.isEmpty)
                _buildEmptyState()
              else ...[
                // NEAREST INCIDENT
                Text(
                  'NEAREST INCIDENT',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                if (nearest != null)
                  IncomingEmergencyCard(
                    emergency: nearest,
                    distanceMeters: _calculateDistance(nearest),
                    isClaiming: _claimingEmergencyId == nearest.id,
                    onCanHelp: () => _handleClaimEmergency(nearest),
                    onViewDetails: () => AppNavigator.navigateToEmergencyDetails(context, nearest.id),
                  ),

                // OTHER NEARBY INCIDENTS
                if (otherList.isNotEmpty) ...[
                  AppSpacing.gapVerticalLg,
                  Text(
                    'OTHER NEARBY',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...otherList.map(_buildOtherNearbyRow),
                ],
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
        },
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  final double progress;

  _RadarPulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Outer ripple 1
    final p1 = (progress) % 1.0;
    final r1 = maxRadius * p1;
    final paint1 = Paint()
      ..color = AppColors.brandBlue.withValues(alpha: (1.0 - p1) * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, r1, paint1);

    // Outer ripple 2
    final p2 = (progress + 0.5) % 1.0;
    final r2 = maxRadius * p2;
    final paint2 = Paint()
      ..color = AppColors.brandBlue.withValues(alpha: (1.0 - p2) * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, r2, paint2);

    // Center solid dot
    final centerPaint = Paint()
      ..color = AppColors.brandBlue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5.0, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
