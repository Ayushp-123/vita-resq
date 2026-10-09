import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/emergency_model.dart';
import '../models/communication_mode.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_typography.dart';
import '../services/notification_service.dart';

/// Centralized Dialog & Bottom Sheet Service for Vita ResQ (Phase 8 Redesign).
///
/// Follows strict feedback principles:
/// - Warm white surfaces (`AppColors.surfacePureWhite`)
/// - Rounded corners (`AppShapes.dialog`, 20dp+)
/// - Clear title, concise human explanation
/// - Safe action visually favored over destructive actions
/// - All touch targets >= 48dp
/// - Responsive across 360x640 and 390x844 without overflows
class AppDialogs {
  /// Standardized Destructive Action Confirmation Dialog.
  ///
  /// Places the SAFE action as the prominent primary button (blue/filled)
  /// and the DESTRUCTIVE action as the secondary outline button.
  static Future<bool?> showDestructiveConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    VoidCallback? onConfirm,
    bool isDangerous = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePureWhite,
        shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDangerous ? AppColors.emergencyRed : AppColors.brandBlue)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDangerous ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                color: isDangerous ? AppColors.emergencyRed : AppColors.brandBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTypography.bodySecondary.copyWith(
            fontSize: 13.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    cancelLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDangerous ? AppColors.emergencyRed : AppColors.deepNavy,
                    side: BorderSide(
                      color: isDangerous ? AppColors.emergencyRed : AppColors.borderMedium,
                      width: 1.2,
                    ),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop(true);
                    if (onConfirm != null) onConfirm();
                  },
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show Intentional Confirmation Dialog for Cancelling Emergency
  static Future<bool?> showCancelEmergencyDialog({
    required BuildContext context,
    required VoidCallback onConfirmCancel,
  }) {
    return showDestructiveConfirmDialog(
      context: context,
      title: 'Cancel emergency?',
      message: 'Are you sure you no longer need help? Responders will be notified.',
      cancelLabel: 'Keep Emergency Active',
      confirmLabel: 'Cancel Emergency',
      isDangerous: true,
      onConfirm: onConfirmCancel,
    );
  }

  /// Show 5-Second SOS Countdown Bottom Sheet with Audio Alert & Cancel Option
  static Future<bool?> showSOSConfirmationBottomSheet({
    required BuildContext context,
    required String currentAddress,
    required bool isOnline,
    required VoidCallback onConfirmSOS,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SOSCountdownSheet(
          currentAddress: currentAddress,
          isOnline: isOnline,
          onConfirmSOS: onConfirmSOS,
        );
      },
    );
  }

  /// Show Incoming Nearby Emergency Alert Modal (Standardized Phase 8 Presentation)
  static void showNearbyEmergencyDialog({
    required BuildContext context,
    required EmergencyModel emergency,
    required CommunicationMode mode,
    String userRole = 'CITIZEN',
    String? vehicleNumber,
    required VoidCallback onViewEmergency,
    VoidCallback? onDecline,
  }) {
    // Play role-specific siren and alert tone immediately with deduplication
    EmergencySoundService.playEmergencyAlert(userRole: userRole, emergencyId: emergency.id);

    final bool isAmbulance = userRole == 'AMBULANCE_DRIVER';
    final bool isPolice = userRole == 'POLICE_PCR';

    final Color headerColor = isAmbulance
        ? AppColors.emergencyRed
        : isPolice
            ? AppColors.brandBlue
            : AppColors.emergencyRed;

    final String titleText = isAmbulance
        ? 'URGENT DISPATCH: MEDICAL SOS'
        : isPolice
            ? 'URGENT DISPATCH: POLICE ALERT'
            : 'NEARBY EMERGENCY ALERT';

    final String subtitleText = isAmbulance
        ? 'Priority dispatch to Ambulance${vehicleNumber != null && vehicleNumber.isNotEmpty ? ' #$vehicleNumber' : ' Unit'}'
        : isPolice
            ? 'Priority dispatch to Patrol Unit #${vehicleNumber ?? 'PCR-12'}'
            : 'Someone nearby needs urgent assistance.';

    final String actionLabel = isAmbulance
        ? 'ACCEPT & START ROUTING'
        : isPolice
            ? 'ACCEPT & START PATROL ROUTING'
            : 'VIEW EMERGENCY';

    final IconData actionIcon = isAmbulance
        ? Icons.local_hospital_rounded
        : isPolice
            ? Icons.local_police_rounded
            : Icons.directions_run_rounded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfacePureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Accent Line
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: headerColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: headerColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAmbulance
                                    ? Icons.emergency_rounded
                                    : isPolice
                                        ? Icons.local_police_rounded
                                        : Icons.warning_amber_rounded,
                                color: headerColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: headerColor,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleText,
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Details Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.subtleBlueGray,
                            borderRadius: AppShapes.medium,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppColors.brandBlue, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Incident Radius: ${(emergency.currentRadiusMeters / 1000).toStringAsFixed(1)} km',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isAmbulance || isPolice
                                          ? AppColors.emergencyLightRed
                                          : AppColors.emeraldLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAmbulance
                                          ? 'AMBULANCE PRIORITY'
                                          : isPolice
                                              ? 'POLICE PATROL'
                                              : 'CITIZEN VOLUNTEER',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isAmbulance || isPolice
                                            ? AppColors.emergencyRed
                                            : AppColors.emeraldGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons (Both >= 48dp touch targets)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: headerColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            elevation: 0,
                            shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
                          ),
                          icon: Icon(actionIcon, size: 20),
                          label: Text(
                            actionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                          onPressed: () {
                            EmergencySoundService.stopSound();
                            Navigator.of(context).pop();
                            onViewEmergency();
                          },
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.borderMedium),
                            minimumSize: const Size(double.infinity, 48),
                            shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
                          ),
                          onPressed: () {
                            EmergencySoundService.stopSound();
                            Navigator.of(context).pop();
                            if (onDecline != null) onDecline();
                          },
                          child: const Text(
                            'DECLINE / DISMISS',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      EmergencySoundService.stopSound();
    });
  }

  /// Show Confirm Response Dialog
  static void showConfirmResponseDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfacePureWhite,
          shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
          title: const Row(
            children: [
              Icon(Icons.volunteer_activism_rounded, color: AppColors.emergencyRed),
              SizedBox(width: 10),
              Text(
                'Confirm Response',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepNavy),
              ),
            ],
          ),
          content: Text(
            'Are you sure you can help? Accepting will stream your live location to the victim and dispatch network.',
            style: AppTypography.bodySecondary.copyWith(color: AppColors.textPrimary, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Show Report Problem Dialog
  static void showReportProblemDialog({
    required BuildContext context,
    required Function(String reason, bool isFatal) onReport,
  }) {
    String selectedReason = 'Traffic Delay';
    bool isFatal = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surfacePureWhite,
              shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
              title: const Row(
                children: [
                  Icon(Icons.report_problem_rounded, color: AppColors.warningAmber),
                  SizedBox(width: 10),
                  Text(
                    'Report a Problem',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      labelText: 'Problem Reason',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.brandBlue, width: 2),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Traffic Delay', child: Text('Traffic Delay')),
                      DropdownMenuItem(value: 'Vehicle Problem', child: Text('Vehicle Breakdown')),
                      DropdownMenuItem(value: 'Medical Issue', child: Text('Personal Emergency')),
                      DropdownMenuItem(value: 'Blocked Road', child: Text('Blocked Road')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.warningAmber,
                    title: const Text(
                      'Cannot continue (Hand over to Standby pool)',
                      style: TextStyle(fontSize: 13, color: AppColors.deepNavy, fontWeight: FontWeight.w600),
                    ),
                    value: isFatal,
                    onChanged: (val) {
                      setState(() => isFatal = val ?? false);
                    },
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: AppColors.borderSubtle),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warningAmber,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onReport(selectedReason, isFatal);
                        },
                        child: const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SOSCountdownSheet extends StatefulWidget {
  final String currentAddress;
  final bool isOnline;
  final VoidCallback onConfirmSOS;

  const _SOSCountdownSheet({
    required this.currentAddress,
    required this.isOnline,
    required this.onConfirmSOS,
  });

  @override
  State<_SOSCountdownSheet> createState() => _SOSCountdownSheetState();
}

class _SOSCountdownSheetState extends State<_SOSCountdownSheet> with SingleTickerProviderStateMixin {
  int _secondsRemaining = 5;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    EmergencySoundService.playAccidentWarning();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
          EmergencySoundService.playCountdownBeep(isFinal: _secondsRemaining <= 2);
        } else {
          _secondsRemaining = 0;
          timer.cancel();
          _dispatchSOS();
        }
      });
    });
  }

  void _dispatchSOS() {
    _timer?.cancel();
    EmergencySoundService.stopSound();
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop(true);
    }
    widget.onConfirmSOS();
  }

  void _cancelSOS() {
    _timer?.cancel();
    EmergencySoundService.stopSound();
    HapticFeedback.mediumImpact();
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),

              // Pulsing Warning Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.emergencyLightRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.emergencyRed.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    size: 42,
                    color: AppColors.emergencyRed,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'DISPATCHING EMERGENCY SOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emergencyRed,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'Alerting nearby responders and emergency services in...',
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Circular 5-Second Countdown Indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / 5.0,
                      strokeWidth: 7,
                      backgroundColor: AppColors.subtleBlueGray,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emergencyRed),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emergencyRed,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'SEC',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Large Cancel Button (False Alarm Guard) >= 54dp
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppShapes.medium,
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 22),
                label: const Text(
                  'CANCEL SOS (FALSE ALARM)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                ),
                onPressed: _cancelSOS,
              ),
              const SizedBox(height: 10),

              // Instant Send Bypass Button >= 48dp
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emergencyRed,
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppShapes.medium,
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'SEND IMMEDIATELY',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: _dispatchSOS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
