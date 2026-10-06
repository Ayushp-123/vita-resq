import 'package:flutter/material.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_status.dart';

/// Semantic pill badge for Vita ResQ.
///
/// Communicates state (NORMAL, ONLINE, OFFLINE, WARNING, EMERGENCY, SUCCESS, COMPLETED, ERROR)
/// using subtle tinted backgrounds, high-contrast text, and consistent outline icons.
class AppStatusBadge extends StatelessWidget {
  final AppStatusType status;
  final String? customLabel;
  final bool isCompact;
  final bool showIcon;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  });

  const AppStatusBadge.online({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.online;

  const AppStatusBadge.offline({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.offline;

  const AppStatusBadge.emergency({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.emergency;

  const AppStatusBadge.warning({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.warning;

  const AppStatusBadge.success({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.success;

  const AppStatusBadge.completed({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.completed;

  const AppStatusBadge.error({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.error;

  const AppStatusBadge.normal({
    super.key,
    this.customLabel,
    this.isCompact = false,
    this.showIcon = true,
  }) : status = AppStatusType.normal;

  @override
  Widget build(BuildContext context) {
    final config = AppStatusConfig.resolve(status);
    final text = customLabel ?? config.label;

    return Container(
      padding: isCompact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : AppSpacing.statusBadgePadding,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: AppShapes.pill,
        border: Border.all(color: config.borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(
              config.icon,
              size: isCompact ? AppSpacing.iconXs : AppSpacing.iconSm,
              color: config.color,
            ),
            SizedBox(width: isCompact ? 4 : 6),
          ],
          Text(
            text,
            style: (isCompact ? AppTypography.metadata : AppTypography.caption).copyWith(
              color: config.color,
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 10.5 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
