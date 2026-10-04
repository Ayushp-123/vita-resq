import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/accident_detection_service.dart';
import '../services/notification_service.dart';

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
    if (mounted) {
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
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHighest,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          // Pulsing Warning Beacon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorRed.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.car_crash_outlined,
                size: 46,
                color: AppTheme.errorRed,
              ),
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'CRASH / IMPACT DETECTED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.errorRed,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'High-G impact detected by sensor AI.\nBroadcasting emergency SOS if unresponsive.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          if (widget.reasoning.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.surfaceHighest),
              ),
              child: Text(
                'Telemetry: ${widget.reasoning}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 24),

          // Circular Countdown Timer Display
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _secondsRemaining / 15.0,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.surfaceHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.errorRed),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_secondsRemaining',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorRed,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'SECONDS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Action Buttons
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 24),
            label: const Text(
              "I AM SAFE (CANCEL SOS)",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            onPressed: _cancelDetection,
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.emergency_outlined, size: 20),
            label: const Text(
              'DISPATCH SOS IMMEDIATELY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _triggerAutoSOS,
          ),
        ],
      ),
    );
  }
}
