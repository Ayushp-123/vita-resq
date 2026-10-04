import 'package:flutter/material.dart';
import '../models/emergency_model.dart';
import '../core/theme/app_theme.dart';

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
    Color iconBgColor = isCompleted
        ? AppTheme.secondaryBlue
        : isActive
            ? AppTheme.surfaceLight
            : AppTheme.surfaceLow;

    Border? border = isActive
        ? Border.all(color: AppTheme.secondaryBlue, width: 2)
        : !isCompleted
            ? Border.all(color: AppTheme.surfaceHighest, width: 2)
            : null;

    Widget iconChild;
    if (isCompleted) {
      iconChild = const Icon(Icons.check, color: Colors.white, size: 14);
    } else if (isActive) {
      iconChild = Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppTheme.secondaryBlue,
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
          width: isActive ? 32 : 24,
          height: isActive ? 32 : 24,
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
            border: border,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.secondaryBlue.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(child: iconChild),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? AppTheme.secondaryBlue
                : isCompleted
                    ? AppTheme.onSurface
                    : AppTheme.outlineColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int activeIdx = _currentStepIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceHighest),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connecting Progress Bar
          Positioned(
            left: 24,
            right: 24,
            top: 14,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 2,
                    color: activeIdx >= 1 ? AppTheme.secondaryBlue : AppTheme.surfaceHighest,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 2,
                    color: activeIdx >= 2 ? AppTheme.secondaryBlue : AppTheme.surfaceHighest,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 2,
                    color: activeIdx >= 3 ? AppTheme.secondaryBlue : AppTheme.surfaceHighest,
                  ),
                ),
              ],
            ),
          ),
          // Step Nodes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepItem(
                stepIndex: 0,
                label: 'Search',
                isCompleted: activeIdx > 0,
                isActive: activeIdx == 0,
              ),
              _buildStepItem(
                stepIndex: 1,
                label: 'Assigned',
                isCompleted: activeIdx > 1,
                isActive: activeIdx == 1,
              ),
              _buildStepItem(
                stepIndex: 2,
                label: 'Approaching',
                isCompleted: activeIdx > 2,
                isActive: activeIdx == 2,
              ),
              _buildStepItem(
                stepIndex: 3,
                label: 'Arrived',
                isCompleted: activeIdx > 3,
                isActive: activeIdx == 3,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
