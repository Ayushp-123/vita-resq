import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/responder_model.dart';
import '../core/theme/app_theme.dart';

class ResponderProfileCard extends StatelessWidget {
  final ResponderModel responder;
  final VoidCallback? onCallPressed;

  const ResponderProfileCard({
    super.key,
    required this.responder,
    this.onCallPressed,
  });

  void _handlePhoneCall(BuildContext context) {
    String? phone = responder.phoneNumber;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number not provided for ${responder.userName}.'),
          backgroundColor: AppTheme.tertiaryAmber,
        ),
      );
      return;
    }

    if (onCallPressed != null) {
      onCallPressed!();
      return;
    }

    String cleanNumber = phone.replaceAll(RegExp(r'[^\d+]'), '');
    const channel = MethodChannel('plugins.flutter.io/url_launcher');

    channel.invokeMethod('launch', {
      'url': 'tel:$cleanNumber',
      'useSafariVC': false,
      'useWebView': false,
      'enableJavaScript': false,
      'enableDomStorage': false,
      'universalLinksOnly': false,
      'headers': {},
    }).catchError((_) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.phone, color: AppTheme.secondaryBlue),
              const SizedBox(width: 8),
              Text(responder.userName),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Helper Contact Phone Number:'),
              const SizedBox(height: 8),
              SelectableText(
                phone,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryBlue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isPrimary = responder.role == ResponderRole.PRIMARY;
    bool isAmbulance = responder.userRole == 'AMBULANCE_DRIVER';
    bool isPolice = responder.userRole == 'POLICE_PCR';

    Color badgeColor = isAmbulance
        ? AppTheme.primaryRed
        : isPolice
            ? AppTheme.secondaryBlue
            : (isPrimary ? AppTheme.primaryRed : AppTheme.tertiaryAmber);

    String roleLabel = isAmbulance
        ? '🚑 108 AMBULANCE (${responder.vehicleNumber ?? '108'})'
        : isPolice
            ? '🚓 POLICE PCR (${responder.vehicleNumber ?? 'PCR-12'})'
            : (isPrimary ? 'PRIMARY HELPER' : 'STANDBY HELPER');

    IconData avatarIcon = isAmbulance
        ? Icons.local_hospital
        : isPolice
            ? Icons.local_police
            : Icons.person;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAmbulance || isPolice ? badgeColor.withValues(alpha: 0.5) : AppTheme.surfaceHighest),
      ),
      child: Row(
        children: [
          // Avatar with Status Badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAmbulance || isPolice ? badgeColor.withValues(alpha: 0.1) : AppTheme.surfaceContainer,
                  border: Border.all(color: badgeColor, width: 2),
                ),
                child: Icon(
                  avatarIcon,
                  size: 30,
                  color: badgeColor,
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: responder.status == ResponderStatus.ARRIVED
                      ? Colors.green
                      : isPrimary
                          ? AppTheme.primaryRed
                          : AppTheme.tertiaryAmber,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Helper Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        responder.userName.isNotEmpty ? responder.userName : 'Vita ResQ Responder',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (responder.bloodGroup != null && responder.bloodGroup!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Blood: ${responder.bloodGroup}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        responder.phoneNumber != null && responder.phoneNumber!.isNotEmpty
                            ? responder.phoneNumber!
                            : 'No phone listed',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Call Action Button
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.secondaryBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.phone, size: 20),
            onPressed: () => _handlePhoneCall(context),
          ),
        ],
      ),
    );
  }
}
