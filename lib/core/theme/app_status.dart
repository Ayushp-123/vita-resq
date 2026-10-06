import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Semantic status categories for Vita ResQ.
///
/// Centralized styling for tactical statuses across emergency screens,
/// maps, responder profiles, network state indicators, and history logs.
enum AppStatusType {
  normal,
  online,
  offline,
  warning,
  emergency,
  success,
  completed,
  error,
}

/// Metadata and styling configuration for an [AppStatusType].
class AppStatusConfig {
  final String label;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;

  const AppStatusConfig({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
  });

  /// Resolves the comprehensive styling configuration for any [AppStatusType].
  static AppStatusConfig resolve(AppStatusType type) {
    switch (type) {
      case AppStatusType.normal:
        return const AppStatusConfig(
          label: 'Normal',
          color: AppColors.navy700,
          backgroundColor: AppColors.subtleBlueGray,
          borderColor: AppColors.borderSubtle,
          icon: Icons.shield_outlined,
        );

      case AppStatusType.online:
        return const AppStatusConfig(
          label: 'Online',
          color: AppColors.emeraldGreen,
          backgroundColor: AppColors.emeraldLight,
          borderColor: AppColors.emeraldBorder,
          icon: Icons.cloud_done_outlined,
        );

      case AppStatusType.offline:
        return const AppStatusConfig(
          label: 'Offline (P2P)',
          color: AppColors.textSecondary,
          backgroundColor: AppColors.subtleBlueGray,
          borderColor: AppColors.borderMedium,
          icon: Icons.cloud_off_outlined,
        );

      case AppStatusType.warning:
        return const AppStatusConfig(
          label: 'Caution',
          color: AppColors.warningAmber,
          backgroundColor: AppColors.amberLight,
          borderColor: AppColors.amberBorder,
          icon: Icons.warning_amber_rounded,
        );

      case AppStatusType.emergency:
        return const AppStatusConfig(
          label: 'Emergency Active',
          color: AppColors.emergencyRed,
          backgroundColor: AppColors.emergencyLightRed,
          borderColor: AppColors.emergencyContainer,
          icon: Icons.emergency_outlined,
        );

      case AppStatusType.success:
        return const AppStatusConfig(
          label: 'Confirmed Safe',
          color: AppColors.emeraldGreen,
          backgroundColor: AppColors.emeraldLight,
          borderColor: AppColors.emeraldBorder,
          icon: Icons.check_circle_outline_rounded,
        );

      case AppStatusType.completed:
        return const AppStatusConfig(
          label: 'Completed',
          color: AppColors.softBlueDark,
          backgroundColor: AppColors.softBlueLight,
          borderColor: AppColors.softBlueBorder,
          icon: Icons.task_alt_rounded,
        );

      case AppStatusType.error:
        return const AppStatusConfig(
          label: 'Attention Needed',
          color: AppColors.emergencyRed,
          backgroundColor: AppColors.emergencyLightRed,
          borderColor: AppColors.emergencyContainer,
          icon: Icons.error_outline_rounded,
        );
    }
  }
}
