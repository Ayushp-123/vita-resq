import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_status.dart';

/// Reusable soft card container for Vita ResQ.
///
/// Features:
/// - Pure white surface with gentle 20dp corners
/// - Subtle 1.2dp border in Slate 200
/// - Diffuse, non-harsh shadow (avoids heavy floating elevation)
/// - Optional pressable feedback when [onTap] is provided
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final bool hasShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? AppShapes.card;
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfacePureWhite,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: borderColor ?? AppColors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: hasShadow
            ? const [
                BoxShadow(
                  color: AppColors.shadowCard,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return AppPressable(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// Open section primitive supporting flat, structured grouping
/// without forcing everything into a floating card.
class AppSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailingAction;
  final Widget child;
  final EdgeInsetsGeometry contentPadding;

  const AppSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailingAction,
    required this.child,
    this.contentPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTypography.sectionHeading),
                  if (subtitle != null) ...[
                    AppSpacing.gapVerticalXs,
                    Text(subtitle!, style: AppTypography.bodySecondary),
                  ],
                ],
              ),
            ),
            if (trailingAction != null) trailingAction!,
          ],
        ),
        AppSpacing.gapVerticalMd,
        Padding(
          padding: contentPadding,
          child: child,
        ),
      ],
    );
  }
}

/// Information container for tips, safety disclaimers, or key telemetry summaries.
class AppInfoContainer extends StatelessWidget {
  final String? title;
  final String message;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? borderColor;
  final Widget? trailing;

  const AppInfoContainer({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.backgroundColor,
    this.borderColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.subtleBlueGray;
    final effectiveBorder = borderColor ?? AppColors.borderSubtle;

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: AppShapes.medium,
        border: Border.all(color: effectiveBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: icon!,
            ),
            AppSpacing.gapHorizontalMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTypography.subheading.copyWith(fontSize: 14),
                  ),
                  AppSpacing.gapVerticalXs,
                ],
                Text(
                  message,
                  style: AppTypography.bodySecondary.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            AppSpacing.gapHorizontalSm,
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Tactical status container rendering dynamic alert/state banners
/// using centralized [AppStatusType] tokens.
class AppStatusContainer extends StatelessWidget {
  final AppStatusType status;
  final String? customTitle;
  final String? customSubtitle;
  final Widget? trailing;
  final Widget? child;

  const AppStatusContainer({
    super.key,
    required this.status,
    this.customTitle,
    this.customSubtitle,
    this.trailing,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final config = AppStatusConfig.resolve(status);
    final title = customTitle ?? config.label;

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: AppShapes.medium,
        border: Border.all(color: config.borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                config.icon,
                color: config.color,
                size: AppSpacing.iconMd,
              ),
              AppSpacing.gapHorizontalSm,
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.subheading.copyWith(
                    color: config.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (customSubtitle != null) ...[
            AppSpacing.gapVerticalXs,
            Text(
              customSubtitle!,
              style: AppTypography.bodySecondary.copyWith(
                fontSize: 13,
                color: config.color.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (child != null) ...[
            AppSpacing.gapVerticalSm,
            child!,
          ],
        ],
      ),
    );
  }
}

/// Clean, accessible list item row primitive.
class AppListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  const AppListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final rowContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                AppSpacing.gapHorizontalMd,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.bodySecondary.copyWith(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                AppSpacing.gapHorizontalSm,
                trailing!,
              ] else if (onTap != null) ...[
                AppSpacing.gapHorizontalSm,
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: AppSpacing.iconSm,
                ),
              ],
            ],
          ),
        ),
        if (showDivider) const AppDivider(),
      ],
    );

    if (onTap != null) {
      return AppPressable(
        onTap: onTap,
        child: rowContent,
      );
    }

    return rowContent;
  }
}

/// Subtle, standardized divider primitive for Vita ResQ.
class AppDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  final Color? color;
  final double thickness;

  const AppDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
    this.thickness = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      indent: indent,
      endIndent: endIndent,
      color: color ?? AppColors.borderSubtle,
      thickness: thickness,
      height: thickness,
    );
  }
}
