import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/app_permissions_service.dart';

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row with Drag handle and Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.onSurfaceVariant, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => widget.onPermissionsGranted(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Header Badge
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(
                Icons.security_outlined,
                size: 40,
                color: AppTheme.primaryRed,
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Emergency Permissions Required',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),

          const Text(
            'Vita ResQ is a community emergency response network. To find victims and dispatch nearby responders, please enable these essential permissions:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Permission Item 1: GPS Location
          _buildPermissionItem(
            icon: Icons.location_on_outlined,
            iconColor: AppTheme.primaryRed,
            title: 'Precise GPS Location',
            description: 'Streams your real-time satellite coordinates to nearby 108 ambulances, PCR units, and volunteers during an SOS.',
          ),
          const SizedBox(height: 12),

          // Permission Item 2: Notifications
          _buildPermissionItem(
            icon: Icons.notifications_active_outlined,
            iconColor: AppTheme.secondaryBlue,
            title: 'Critical Emergency Notifications',
            description: 'Triggers loud sirens, vibration alerts, and live dispatch updates even when your screen is locked.',
          ),
          const SizedBox(height: 12),

          // Permission Item 3: Bluetooth & Nearby Devices
          _buildPermissionItem(
            icon: Icons.wifi_tethering_rounded,
            iconColor: Colors.teal,
            title: 'Nearby Devices & Bluetooth',
            description: 'Enables offline nearby-device P2P communication when mobile data or towers are down during natural disasters.',
          ),
          const SizedBox(height: 24),

          // Action Buttons
          _isRequesting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    minimumSize: const Size(double.infinity, 54),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.verified_user_outlined, size: 22),
                  label: const Text(
                    'GRANT ALL PERMISSIONS',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  onPressed: _handleGrantPermissions,
                ),
          const SizedBox(height: 10),

          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open App Settings Manually', style: TextStyle(fontSize: 13)),
            onPressed: () => _permService.openSettings(),
          ),
          TextButton(
            onPressed: () => widget.onPermissionsGranted(),
            child: const Text('Continue to App', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryBlue)),
          ),
        ],
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
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceHighest),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
