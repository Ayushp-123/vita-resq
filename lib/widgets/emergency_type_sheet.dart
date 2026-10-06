import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_shapes.dart';
import '../core/theme/app_spacing.dart';

class EmergencyTypeOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;

  const EmergencyTypeOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

class EmergencyTypeSheet extends StatelessWidget {
  final String currentType;
  final ValueChanged<String> onTypeSelected;

  static const List<EmergencyTypeOption> options = [
    EmergencyTypeOption(
      id: 'MEDICAL',
      label: 'Medical',
      description: 'Paramedic, cardiac, injury or medical aid',
      icon: Icons.medical_services_outlined,
      accentColor: AppColors.emergencyRed,
    ),
    EmergencyTypeOption(
      id: 'ACCIDENT',
      label: 'Accident',
      description: 'Vehicle crash, collision or road emergency',
      icon: Icons.car_crash_outlined,
      accentColor: AppColors.warningAmber,
    ),
    EmergencyTypeOption(
      id: 'POLICE',
      label: 'Police',
      description: 'Personal safety, threat or police patrol',
      icon: Icons.local_police_outlined,
      accentColor: AppColors.brandBlue,
    ),
    EmergencyTypeOption(
      id: 'OTHER',
      label: 'Other',
      description: 'General mutual-aid assistance',
      icon: Icons.shield_outlined,
      accentColor: AppColors.deepNavy,
    ),
  ];

  const EmergencyTypeSheet({
    super.key,
    required this.currentType,
    required this.onTypeSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required String currentType,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EmergencyTypeSheet(
        currentType: currentType,
        onTypeSelected: (selected) {
          onSelected(selected);
          Navigator.of(ctx).pop(selected);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.radiusLg)),
        boxShadow: [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.gapVerticalMd,

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Emergency Type',
                  style: AppTypography.sectionHeading.copyWith(
                    color: AppColors.deepNavy,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Help responders prepare appropriate medical and rescue equipment.',
              style: AppTypography.bodySecondary.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.gapVerticalMd,

            // Emergency options
            ...options.map((option) {
              final isSelected = option.id.toUpperCase() == currentType.toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Material(
                  color: isSelected
                      ? option.accentColor.withValues(alpha: 0.08)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => onTypeSelected(option.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? option.accentColor : AppColors.borderSubtle,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? option.accentColor
                                  : option.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              option.icon,
                              color: isSelected ? Colors.white : option.accentColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option.description,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: option.accentColor,
                              size: 22,
                            )
                          else
                            const Icon(
                              Icons.circle_outlined,
                              color: AppColors.borderMedium,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
