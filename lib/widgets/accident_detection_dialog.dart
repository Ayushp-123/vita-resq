import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_typography.dart';
import '../services/accident_detection_service.dart';
import '../services/notification_service.dart';

/// Safety-critical crash confirmation bottom sheet (Phase 8 Redesign).
///
/// Follows strict human safety design principles:
/// - "POSSIBLE CRASH DETECTED"
/// - "Are you okay?"
/// - Highly visible countdown timer (15s auto-SOS trigger)
/// - Primary large touch target: [ I'M OKAY ] (>=54dp height)
/// - Secondary manual dispatch target: [ DISPATCH SOS NOW ] (>=48dp height)
/// - Zero generic dialog clutter; immediate comprehension under stress.
class AccidentDetectionDialog extends StatefulWidget {
  final String reasoning;
  final VoidCallback onConfirmAutoSOS;
  final VoidCallback onCancel;

  const AccidentDetectionDialog({
    super.key,
    required this.reasoning,
    required this.onConfirmAutoSOS,
    required this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required String reasoning,
    required VoidCallback onConfirmAutoSOS,
    VoidCallback? onCancel,
  }) async {
    AccidentDetectionService().setConfirmationActive(true);

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AccidentDetectionDialog(
          reasoning: reasoning,
          onConfirmAutoSOS: onConfirmAutoSOS,
          onCancel: () {
            Navigator.of(ctx).pop();
            if (onCancel != null) onCancel();
          },
        );
      },
    );

    AccidentDetectionService().setConfirmationActive(false);
  }

  @override
  State<AccidentDetectionDialog> createState() => _AccidentDetectionDialogState();
}

class _AccidentDetectionDialogState extends State<AccidentDetectionDialog>
    with SingleTickerProviderStateMixin {
  int _secondsRemaining = 15;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    EmergencySoundService.playAccidentWarning();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
          EmergencySoundService.playCountdownBeep(isFinal: _secondsRemaining <= 3);
        } else {
          _secondsRemaining = 0;
          timer.cancel();
          _triggerAutoSOS();
        }
      });
    });
  }

  void _triggerAutoSOS() {
    _countdownTimer?.cancel();
    EmergencySoundService.stopSound();
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    widget.onConfirmAutoSOS();
  }

  void _cancelDetection() {
    _countdownTimer?.cancel();
    EmergencySoundService.stopSound();
    widget.onCancel();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    EmergencySoundService.stopSound();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag / handle bar
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),

              // Pulsing Warning Beacon
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
                    Icons.car_crash_rounded,
                    size: 42,
                    color: AppColors.emergencyRed,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Warning Tag
              const Text(
                'POSSIBLE CRASH DETECTED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emergencyRed,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),

              // Direct Human Question
              Text(
                'Are you okay?',
                textAlign: TextAlign.center,
                style: AppTypography.pageHeading.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 8),

              // Clear Reassurance & Automatic Action Explanation
              Text(
                'Sensors detected a sudden hard impact. If you do not respond, Vita ResQ will automatically broadcast an emergency SOS.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // Circular Countdown Timer Display
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / 15.0,
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
                        'SECONDS',
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

              // Primary Action: [ I'M OKAY ]
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppShapes.medium,
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 24),
                label: const Text(
                  "I'M OKAY",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                onPressed: _cancelDetection,
              ),
              const SizedBox(height: 12),

              // Secondary Action: [ DISPATCH SOS NOW ]
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emergencyRed,
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppShapes.medium,
                  ),
                ),
                icon: const Icon(Icons.emergency_rounded, size: 20),
                label: const Text(
                  'DISPATCH SOS NOW',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                onPressed: _triggerAutoSOS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
