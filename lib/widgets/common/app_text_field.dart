import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Clean, friendly, accessible text input field for Vita ResQ.
///
/// Features:
/// - Rounded 14dp border
/// - Consistent 52dp height baseline
/// - Built-in show/hide password toggle when [isPassword] is true
/// - Clear focus state with Soft Blue highlight
/// - Unambiguous error and validation states
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final bool enabled;
  final bool readOnly;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    Widget? effectiveSuffix = widget.suffixIcon;
    if (widget.isPassword) {
      effectiveSuffix = IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.textMuted,
          size: AppSpacing.iconSm,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
        splashRadius: 20,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.subheading.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          AppSpacing.gapVerticalXs,
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          style: AppTypography.body.copyWith(
            color: widget.enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: widget.prefixIcon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: AppSpacing.minTouchTarget,
            ),
            suffixIcon: effectiveSuffix,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: AppSpacing.minTouchTarget,
            ),
          ),
        ),
      ],
    );
  }
}

/// Clean dropdown selector adhering to the Vita ResQ input system tokens.
class AppDropdownField<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? prefixIcon;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  const AppDropdownField({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.subheading.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          AppSpacing.gapVerticalXs,
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
            size: AppSpacing.iconMd,
          ),
          dropdownColor: AppColors.surfacePureWhite,
          borderRadius: AppShapes.input,
          style: AppTypography.body.copyWith(
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: prefixIcon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: AppSpacing.minTouchTarget,
            ),
          ),
        ),
      ],
    );
  }
}
