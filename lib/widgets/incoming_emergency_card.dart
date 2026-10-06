import 'package:flutter/material.dart';
import '../models/emergency_model.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';

/// Vita ResQ Incoming Emergency Card — Phase 7 Responder Experience.
///
/// Clean, high-contrast, action-oriented card for nearby emergencies.
/// Priority Hierarchy:
/// 1. Emergency Type & Status Badge
/// 2. Distance & Approximate Location
/// 3. Time since request & Broadcast Stage
/// 4. Primary Action: [ I CAN HELP ] (strongest touch target >= 48dp)
/// 5. Secondary Action: [ View Details ] (touch target >= 48dp)
class IncomingEmergencyCard extends StatelessWidget {
  final EmergencyModel emergency;
  final double? distanceMeters;
  final VoidCallback onCanHelp;
  final VoidCallback onViewDetails;
  final bool isClaiming;

  const IncomingEmergencyCard({
    super.key,
    required this.emergency,
    this.distanceMeters,
    required this.onCanHelp,
    required this.onViewDetails,
    this.isClaiming = false,
  });

  String _formatDistance(double? meters) {
    if (meters == null || meters <= 0) {
      if (emergency.currentRadiusMeters >= 1000) {
        return 'Within ${(emergency.currentRadiusMeters / 1000).toStringAsFixed(1)} km';
      }
      return 'Within ${emergency.currentRadiusMeters.round()} m';
    }
    if (meters < 1000) {
      return '${meters.round()} m away';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  String _formatTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'MEDICAL':
        return Icons.medical_services_outlined;
      case 'ACCIDENT':
        return Icons.car_crash_outlined;
      case 'POLICE':
        return Icons.local_police_outlined;
      default:
        return Icons.emergency_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'MEDICAL':
        return AppColors.emergencyRed;
      case 'ACCIDENT':
        return AppColors.warningAmber;
      case 'POLICE':
        return AppColors.brandBlue;
      default:
        return AppColors.emergencyRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(emergency.type);
    final typeIcon = _getTypeIcon(emergency.type);
    final distanceText = _formatDistance(distanceMeters);
    final timeAgoText = _formatTimeAgo(emergency.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: AppShapes.card,
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Emergency Type Badge & Time Ago
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${emergency.type.toUpperCase()} EMERGENCY',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeAgoText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalSm,

          // Distance & Approximate Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                distanceText,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Approx. victim location • ${emergency.isOffline ? "Direct Offline P2P" : "Live Network"}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalMd,

          // Actions: [ View Details ] & [ I CAN HELP ]
          if (isClaiming)
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.emergencyRed,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Joining rescue...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepNavy,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onViewDetails,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'View Details',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergencyRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.volunteer_activism, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'I CAN HELP',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    onPressed: onCanHelp,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
