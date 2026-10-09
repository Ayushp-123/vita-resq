import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/responder_model.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_shapes.dart';
import 'common/app_feedback.dart';
import '../services/auth_service.dart';
import '../services/emergency_service.dart';

class ResponderProfileCard extends StatelessWidget {
  final ResponderModel responder;
  final VoidCallback? onCallPressed;

  const ResponderProfileCard({
    super.key,
    required this.responder,
    this.onCallPressed,
  });

  static bool _isCalling = false;

  void _handlePhoneCall(BuildContext context) async {
    if (_isCalling) return;
    _isCalling = true;

    try {
      if (onCallPressed != null) {
        onCallPressed!();
        return;
      }

      String? phone = responder.phoneNumber;
      if (phone == null || phone.trim().isEmpty) {
        final profile = await AuthService().getUserProfile(responder.userId);
        phone = profile?.phoneNumber;
      }

      if (phone == null || phone.trim().isEmpty) {
        if (context.mounted) {
          AppSnackbar.showWarning(
            context,
            'Phone number not available for this responder.',
          );
        }
        return;
      }

      final cleanNumber = EmergencyContactsService.normalizeDialerNumber(phone);
      if (cleanNumber.isEmpty) {
        if (context.mounted) {
          AppSnackbar.showWarning(
            context,
            'Responder phone number is invalid.',
          );
        }
        return;
      }

      final launched = await EmergencyContactsService.launchDialer(cleanNumber);
      if (!launched && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: AppShapes.dialog),
            title: Row(
              children: [
                const Icon(Icons.phone_rounded, color: AppColors.brandBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    responder.userName.isNotEmpty ? responder.userName : 'Responder Contact',
                    style: AppTypography.subheading,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not open phone dialer automatically.', style: AppTypography.bodySecondary),
                const SizedBox(height: 12),
                const Text('Responder Phone Number:', style: AppTypography.caption),
                const SizedBox(height: 4),
                SelectableText(
                  phone!,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('COPY NUMBER'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: phone!));
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    AppSnackbar.showSuccess(context, 'Phone number copied to clipboard.');
                  }
                },
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
      }
    } finally {
      _isCalling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPrimary = responder.role == ResponderRole.PRIMARY;
    bool isAmbulance = responder.userRole == 'AMBULANCE_DRIVER';
    bool isPolice = responder.userRole == 'POLICE_PCR';

    Color roleColor = isAmbulance
        ? AppColors.emergencyRed
        : isPolice
            ? AppColors.brandBlue
            : (isPrimary ? AppColors.emeraldGreen : AppColors.warningAmber);

    String roleLabel = isAmbulance
        ? (responder.vehicleNumber != null && responder.vehicleNumber!.isNotEmpty
            ? 'Ambulance #${responder.vehicleNumber}'
            : 'Ambulance Unit')
        : isPolice
            ? 'Police Unit #${responder.vehicleNumber ?? 'PCR'}'
            : (isPrimary ? 'Primary Responder' : 'Standby Responder');

    IconData avatarIcon = isAmbulance
        ? Icons.local_hospital_rounded
        : isPolice
            ? Icons.local_police_rounded
            : Icons.person_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: AppShapes.card,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with Status Indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: roleColor.withValues(alpha: 0.12),
                  border: Border.all(color: roleColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(
                  avatarIcon,
                  size: 26,
                  color: roleColor,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: responder.status == ResponderStatus.ARRIVED
                        ? AppColors.emeraldGreen
                        : AppColors.brandBlue,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Responder Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  responder.userName.isNotEmpty ? responder.userName : 'Vita ResQ Responder',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.deepNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                    if (responder.bloodGroup != null && responder.bloodGroup!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle, width: 0.8),
                        ),
                        child: Text(
                          responder.bloodGroup!,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emergencyRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Call Action Button (>= 48dp touch target)
          Material(
            color: AppColors.brandBlue,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => _handlePhoneCall(context),
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.phone_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
