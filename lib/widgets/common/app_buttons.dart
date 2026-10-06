import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_motion.dart';

/// Available visual variants for [AppButton].
enum AppButtonVariant {
  primary,
  secondary,
  outlined,
  destructive,
  success,
  text,
}

/// Generic, accessible button component for Vita ResQ.
///
/// Features:
/// - Consistent 52dp height (40dp compact)
/// - 16dp soft rounded corners
/// - Accessible 48dp minimum touch target
/// - Tactile micro-press feedback
/// - Clear loading, disabled, and pressed states
/// - Predictable typography and icon alignment
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;
  final bool isCompact;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isCompact = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isCompact = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isCompact = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isCompact = false,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isCompact = false,
  }) : variant = AppButtonVariant.destructive;

  const AppButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isCompact = false,
  }) : variant = AppButtonVariant.success;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isCompact = false,
  }) : variant = AppButtonVariant.text;

  bool get _isEnabled => onPressed != null && !isLoading;

  Color _resolveBackgroundColor() {
    if (!_isEnabled && variant != AppButtonVariant.text) {
      return AppColors.subtleBlueGray;
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.deepNavy;
      case AppButtonVariant.secondary:
        return AppColors.subtleBlueGray;
      case AppButtonVariant.outlined:
      case AppButtonVariant.text:
        return Colors.transparent;
      case AppButtonVariant.destructive:
        return AppColors.emergencyRed;
      case AppButtonVariant.success:
        return AppColors.emeraldGreen;
    }
  }

  Color _resolveForegroundColor() {
    if (!_isEnabled) {
      return AppColors.textMuted;
    }
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.destructive:
      case AppButtonVariant.success:
        return AppColors.textOnDark;
      case AppButtonVariant.secondary:
      case AppButtonVariant.outlined:
        return AppColors.deepNavy;
      case AppButtonVariant.text:
        return AppColors.softBlue;
    }
  }

  Border? _resolveBorder() {
    if (variant == AppButtonVariant.outlined) {
      return Border.all(
        color: _isEnabled ? AppColors.borderMedium : AppColors.borderSubtle,
        width: 1.5,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final height = isCompact ? AppSpacing.buttonHeightSm : AppSpacing.buttonHeight;
    final fgColor = _resolveForegroundColor();
    final bgColor = _resolveBackgroundColor();
    final border = _resolveBorder();
    final textStyle = (isCompact ? AppTypography.buttonTextSm : AppTypography.buttonText).copyWith(
      color: fgColor,
    );

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: isCompact ? 16 : 20,
            height: isCompact ? 16 : 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          AppSpacing.gapHorizontalSm,
        ] else if (icon != null) ...[
          IconTheme(
            data: IconThemeData(
              color: fgColor,
              size: isCompact ? AppSpacing.iconSm : AppSpacing.iconMd,
            ),
            child: icon!,
          ),
          AppSpacing.gapHorizontalSm,
        ],
        Text(label, style: textStyle),
      ],
    );

    return AppPressable(
      onTap: _isEnabled ? onPressed : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: height,
          minWidth: isFullWidth ? double.infinity : AppSpacing.minTouchTarget,
        ),
        child: Container(
          height: height,
          width: isFullWidth ? double.infinity : null,
          padding: isCompact ? AppSpacing.buttonPaddingSm : AppSpacing.buttonPadding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppShapes.button,
            border: border,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

/// Accessible icon button for Vita ResQ.
///
/// Features:
/// - 48x48dp minimum touch target
/// - Subtle soft surface or transparent styling
/// - Tooltip support
/// - Tactile micro-press feedback
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final Border? border;
  final double size;
  final double iconSize;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.border,
    this.size = AppSpacing.iconButtonSize,
    this.iconSize = AppSpacing.iconMd,
  });

  const AppIconButton.filled({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppColors.deepNavy,
    this.backgroundColor = AppColors.subtleBlueGray,
    this.border,
    this.size = AppSpacing.iconButtonSize,
    this.iconSize = AppSpacing.iconMd,
  });

  const AppIconButton.outlined({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppColors.deepNavy,
    this.backgroundColor = Colors.transparent,
    this.border = const Border.fromBorderSide(
      BorderSide(color: AppColors.borderSubtle, width: 1.2),
    ),
    this.size = AppSpacing.iconButtonSize,
    this.iconSize = AppSpacing.iconMd,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null
        ? AppColors.textMuted
        : (color ?? AppColors.deepNavy);

    Widget button = AppPressable(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: AppShapes.medium,
          border: border,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveColor,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
