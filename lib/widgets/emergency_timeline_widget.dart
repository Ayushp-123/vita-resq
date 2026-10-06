import 'package:flutter/material.dart';
import '../models/emergency_model.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_shapes.dart';

class EmergencyTimelineWidget extends StatelessWidget {
  final EmergencyStatus status;

  const EmergencyTimelineWidget({super.key, required this.status});

  int get _currentStepIndex {
    switch (status) {
      case EmergencyStatus.SEARCHING:
        return 0;
      case EmergencyStatus.ASSIGNED:
        return 1;
      case EmergencyStatus.APPROACHING:
        return 2;
      case EmergencyStatus.ARRIVED:
      case EmergencyStatus.COMPLETED:
        return 3;
      case EmergencyStatus.CANCELLED:
        return 0;
    }
  }

  Widget _buildStepItem({
    required int stepIndex,
    required String label,
    required bool isCompleted,
    required bool isActive,
  }) {
    Color nodeBgColor = isCompleted
        ? AppColors.emeraldGreen
        : isActive
            ? AppColors.surfacePureWhite
            : AppColors.surfaceLight;

    Border? border = isActive
        ? Border.all(color: AppColors.brandBlue, width: 2.5)
        : isCompleted
            ? null
            : Border.all(color: AppColors.borderSubtle, width: 1.5);

    Widget iconChild;
    if (isCompleted) {
      iconChild = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
    } else if (isActive) {
      iconChild = Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.brandBlue,
          shape: BoxShape.circle,
        ),
      );
    } else {
      iconChild = const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isActive ? 28 : 22,
          height: isActive ? 28 : 22,
          decoration: BoxDecoration(
            color: nodeBgColor,
            shape: BoxShape.circle,
            border: border,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(child: iconChild),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 10.5,
              fontWeight: isActive || isCompleted ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? AppColors.brandBlue
                  : isCompleted
                      ? AppColors.deepNavy
                      : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int activeIdx = _currentStepIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: AppShapes.card,
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connecting Progress Line
          Positioned(
            left: 24,
            right: 24,
            top: 12,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 2.5,
                    color: activeIdx >= 1 ? AppColors.brandBlue : AppColors.borderSubtle,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 2.5,
                    color: activeIdx >= 2 ? AppColors.brandBlue : AppColors.borderSubtle,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 2.5,
                    color: activeIdx >= 3 ? AppColors.brandBlue : AppColors.borderSubtle,
                  ),
                ),
              ],
            ),
          ),
          // Step Nodes
          Row(
            children: [
              Expanded(
                child: _buildStepItem(
                  stepIndex: 0,
                  label: 'Search',
                  isCompleted: activeIdx > 0,
                  isActive: activeIdx == 0,
                ),
              ),
              Expanded(
                child: _buildStepItem(
                  stepIndex: 1,
                  label: 'Assigned',
                  isCompleted: activeIdx > 1,
                  isActive: activeIdx == 1,
                ),
              ),
              Expanded(
                child: _buildStepItem(
                  stepIndex: 2,
                  label: 'Approaching',
                  isCompleted: activeIdx > 2,
                  isActive: activeIdx == 2,
                ),
              ),
              Expanded(
                child: _buildStepItem(
                  stepIndex: 3,
                  label: 'Arrived',
                  isCompleted: activeIdx > 3,
                  isActive: activeIdx == 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
