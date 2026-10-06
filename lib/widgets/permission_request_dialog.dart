import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_typography.dart';
import '../services/app_permissions_service.dart';

/// Essential permissions request sheet (Phase 8 Redesign).
///
/// Follows concise, human feedback principles:
/// - Replaces technical Android/OS jargon with plain reasons why access is needed.
/// - Minimum 48dp touch targets.
/// - Responsive and scrollable on compact devices.
class PermissionRequestDialog extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionRequestDialog({
    super.key,
    required this.onPermissionsGranted,
  });

  static Future<void> showIfNeeded(BuildContext context) async {
    bool hasPermissions = await AppPermissionsService().hasAllCriticalPermissions();
    if (!hasPermissions && context.mounted) {
      await showModalBottomSheet(
        context: context,
        isDismissible: true,
        enableDrag: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PermissionRequestDialog(
          onPermissionsGranted: () {
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        ),
      );
    }
  }

  @override
  State<PermissionRequestDialog> createState() => _PermissionRequestDialogState();
}

class _PermissionRequestDialogState extends State<PermissionRequestDialog> {
  final AppPermissionsService _permService = AppPermissionsService();
  bool _isRequesting = false;

  void _handleGrantPermissions() async {
    setState(() => _isRequesting = true);
    try {
      await _permService.requestAllPermissions();
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
        widget.onPermissionsGranted();
      }
    }
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
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag handle & close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderMedium,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => widget.onPermissionsGranted(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Header Badge
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.emergencyLightRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.emergencyRed.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 34,
                    color: AppColors.emergencyRed,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Emergency Permissions Required',
                textAlign: TextAlign.center,
                style: AppTypography.pageHeading.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'Vita ResQ is a mutual-aid emergency network. These permissions enable volunteers and services to reach you when you need help:',
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              // Permission 1: GPS Location
              _buildPermissionItem(
                icon: Icons.location_on_rounded,
                iconColor: AppColors.emergencyRed,
                title: 'Location Access',
                description: 'Location is needed to share your emergency position with nearby responders.',
              ),
              const SizedBox(height: 10),

              // Permission 2: Notifications
              _buildPermissionItem(
                icon: Icons.notifications_active_rounded,
                iconColor: AppColors.brandBlue,
                title: 'Emergency Alerts',
                description: 'Alerts are needed to sound emergency warnings and dispatch updates.',
              ),
              const SizedBox(height: 10),

              // Permission 3: Bluetooth & Nearby
              _buildPermissionItem(
                icon: Icons.wifi_tethering_rounded,
                iconColor: AppColors.emeraldGreen,
                title: 'Nearby Connectivity',
                description: 'Needed for offline mutual-aid when mobile networks are unavailable.',
              ),
              const SizedBox(height: 22),

              // Action Buttons
              _isRequesting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.brandBlue),
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emergencyRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppShapes.medium,
                        ),
                      ),
                      icon: const Icon(Icons.verified_user_rounded, size: 20),
                      label: const Text(
                        'GRANT ALL PERMISSIONS',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                      onPressed: _handleGrantPermissions,
                    ),
              const SizedBox(height: 8),

              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open App Settings Manually', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: () => _permService.openSettings(),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () => widget.onPermissionsGranted(),
                child: const Text(
                  'Continue to App',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.brandBlue, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.subtleBlueGray,
        borderRadius: AppShapes.medium,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySecondary.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
