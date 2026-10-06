import 'package:flutter/material.dart';
import '../services/impact_reward_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';
import 'common/app_feedback.dart';

/// Feedback dialog for victims to verify and rate helper assistance
class VictimFeedbackDialog extends StatelessWidget {
  final String emergencyId;
  final String helperId;
  final String helperName;
  final String helperRole;

  const VictimFeedbackDialog({
    super.key,
    required this.emergencyId,
    required this.helperId,
    required this.helperName,
    required this.helperRole,
  });

  static Future<void> show(
    BuildContext context, {
    required String emergencyId,
    required String helperId,
    required String helperName,
    required String helperRole,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VictimFeedbackDialog(
        emergencyId: emergencyId,
        helperId: helperId,
        helperName: helperName,
        helperRole: helperRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
      backgroundColor: AppColors.surfacePureWhite,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: AppColors.emeraldGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verify Assistance',
              style: AppTypography.sectionHeading.copyWith(
                fontSize: 18,
                color: AppColors.deepNavy,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Did this responder reach and assist you during this emergency?',
            style: AppTypography.bodySecondary.copyWith(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.gapVerticalMd,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.brandBlue,
                  radius: 20,
                  child: Text(
                    helperName.isNotEmpty ? helperName[0].toUpperCase() : 'H',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helperName,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        helperRole,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.brandBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('NO / SKIP'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 48),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.thumb_up_rounded, size: 18),
                label: const Text('YES, HELPED ME', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await ImpactRewardService().recordVictimFeedback(
                    helperId: helperId,
                    emergencyId: emergencyId,
                    wasHelpful: true,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    AppSnackbar.showSuccess(
                      context,
                      'Thank you! Recognition recorded for your responder.',
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
