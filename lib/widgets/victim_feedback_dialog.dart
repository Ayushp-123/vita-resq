import 'package:flutter/material.dart';
import '../services/impact_reward_service.dart';
import '../core/theme/app_theme.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.volunteer_activism_rounded, color: AppTheme.primaryRed, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verify Assistance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Did this responder reach and assist you during this emergency?',
            style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.secondaryBlue,
                  radius: 20,
                  child: Text(
                    helperName.isNotEmpty ? helperName[0].toUpperCase() : 'H',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helperName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        helperRole,
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryBlue, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                  backgroundColor: const Color(0xFF10B981), // Emerald Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF10B981),
                        content: Text('Thank you! Community Impact Points awarded to responder.'),
                      ),
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
