import 'package:flutter/material.dart';
import '../../services/accident_detection_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/accident_detection_dialog.dart';
import '../../widgets/common/app_feedback.dart';

/// Dedicated Demo & Evaluation Mode Screen (Phase 11 Information Architecture).
///
/// Designed exclusively for hackathon judges and technical evaluators to safely
/// test the synthetic vehicular impact pipeline, 15-second countdown alarm,
/// and automated SOS escalation without risk of accidental false dispatches.
class AccidentDetectionDemoScreen extends StatefulWidget {
  const AccidentDetectionDemoScreen({super.key});

  @override
  State<AccidentDetectionDemoScreen> createState() => _AccidentDetectionDemoScreenState();
}

class _AccidentDetectionDemoScreenState extends State<AccidentDetectionDemoScreen> {
  final AccidentDetectionService _accidentService = AccidentDetectionService();

  bool _isInjecting = false;

  void _triggerSimulatedCrash() async {
    if (_isInjecting) return;
    setState(() => _isInjecting = true);

    try {
      // 1. Injects high-confidence collision metrics into the evaluator
      _accidentService.simulateAccidentEvent();

      // 2. Display the safety-critical 15-second crash countdown sheet
      if (mounted) {
        AppSnackbar.showWarning(
          context,
          'Simulated crash event triggered (Score 90/100). Countdown active.',
        );

        await AccidentDetectionDialog.show(
          context: context,
          reasoning: 'High-G vehicular impact detected via accelerometer sensor telemetry (90/100 confidence score).',
          onConfirmAutoSOS: () {
            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                '[DEMO VERIFIED] Auto-SOS dispatch pipeline initiated successfully.',
              );
            }
          },
          onCancel: () {
            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                '[DEMO VERIFIED] False alarm cancelled safely by user tap.',
              );
            }
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isInjecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: AppColors.warmOffWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepNavy),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Accident Detection Demo',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Judge / Demo Mode Warning Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science_rounded, color: AppColors.warningAmber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DEMO / JUDGE MODE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepNavy,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This environment safely evaluates the collision detection evaluator, siren alerts, 15-second countdown timer, and automatic dispatch sequence without generating real emergency alarms.',
                            style: AppTypography.bodySecondary.copyWith(
                              fontSize: 12,
                              color: AppColors.deepNavy,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Synthetic Telemetry Metrics Card
              Text(
                'SYNTHETIC TELEMETRY PAYLOAD',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfacePureWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildMetricRow(
                      label: 'Impact G-Force (XYZ)',
                      value: '27.2 m/s² (+40)',
                      isHighlighted: true,
                    ),
                    const Divider(height: 16, color: AppColors.borderSubtle),
                    _buildMetricRow(
                      label: 'Speed Deceleration',
                      value: '-6.0 m/s (+25)',
                      isHighlighted: false,
                    ),
                    const Divider(height: 16, color: AppColors.borderSubtle),
                    _buildMetricRow(
                      label: 'Rotational Angular Rate',
                      value: '4.5 rad/s (+15)',
                      isHighlighted: false,
                    ),
                    const Divider(height: 16, color: AppColors.borderSubtle),
                    _buildMetricRow(
                      label: 'Calculated Confidence',
                      value: '90/100 (CRITICAL)',
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // What to expect during demonstration
              Text(
                'DEMO VERIFICATION CHECKLIST',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfacePureWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChecklistPoint('1. Tap the button below to inject the simulated collision.'),
                    const SizedBox(height: 10),
                    _buildChecklistPoint('2. Observe the 15-second pulsing siren modal and haptic vibrations.'),
                    const SizedBox(height: 10),
                    _buildChecklistPoint('3. Test [ I\'M OKAY ] to verify instant, safe cancellation.'),
                    const SizedBox(height: 10),
                    _buildChecklistPoint('4. Or test [ DISPATCH SOS NOW ] for immediate emergency dispatch.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Trigger Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  elevation: 2,
                ),
                onPressed: _isInjecting ? null : _triggerSimulatedCrash,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isInjecting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.warning_amber_rounded, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isInjecting ? 'Injecting Telemetry…' : 'SIMULATE VEHICULAR CRASH',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: Text(
                  'Isolated from live responder networks during evaluation mode.',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required bool isHighlighted,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.subheading.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.deepNavy,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isHighlighted ? AppColors.emergencyRed : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline_rounded, color: AppColors.emeraldGreen, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySecondary.copyWith(fontSize: 12.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}
