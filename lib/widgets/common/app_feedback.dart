import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_status.dart';

/// Centralized UI feedback components for Vita ResQ (Phase 8).
///
/// Follows the Core Feedback Principle:
/// - WHAT HAPPENED?
/// - WHAT DOES IT MEAN?
/// - WHAT SHOULD I DO NEXT?
///
/// Guarantees calm, human, actionable messages without technical terminology,
/// stack traces, or developer IDs.

/// Standardized floating snackbar for temporary feedback.
class AppSnackbar {
  /// Show a standardized floating snackbar with deduplication (hides existing first).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AppStatusType type = AppStatusType.normal,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    Color backgroundColor;
    Color textColor = Colors.white;
    IconData icon;

    switch (type) {
      case AppStatusType.success:
        backgroundColor = const Color(0xFF047857); // Deep emerald
        icon = Icons.check_circle_rounded;
        break;
      case AppStatusType.warning:
        backgroundColor = const Color(0xFFB45309); // Deep amber
        icon = Icons.warning_amber_rounded;
        break;
      case AppStatusType.emergency:
      case AppStatusType.error:
        backgroundColor = AppColors.emergencyRed;
        icon = Icons.error_outline_rounded;
        break;
      case AppStatusType.online:
        backgroundColor = const Color(0xFF047857);
        icon = Icons.cloud_done_rounded;
        break;
      case AppStatusType.offline:
        backgroundColor = const Color(0xFF334155);
        icon = Icons.cloud_off_rounded;
        break;
      case AppStatusType.completed:
        backgroundColor = AppColors.brandBlue;
        icon = Icons.task_alt_rounded;
        break;
      case AppStatusType.normal:
        backgroundColor = AppColors.deepNavy;
        icon = Icons.info_outline_rounded;
        break;
    }

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: backgroundColor,
      duration: duration,
      shape: const RoundedRectangleBorder(
        borderRadius: AppShapes.medium,
      ),
      content: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onAction();
              },
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return messenger.showSnackBar(snackBar);
  }

  /// Convenience helper for positive confirmations.
  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience helper for errors.
  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience helper for warnings.
  static void showWarning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience helper for informational updates.
  static void showInfo(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.normal,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// In-line contextual feedback banner matching the Phase 1 AppStatus language.
class AppFeedbackBanner extends StatelessWidget {
  final AppStatusType status;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool isCompact;

  const AppFeedbackBanner({
    super.key,
    required this.status,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = AppStatusConfig.resolve(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: AppShapes.medium,
        border: Border.all(color: config.borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(config.icon, color: config.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.subheading.copyWith(
                        color: config.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: AppTypography.bodySecondary.copyWith(
                        fontSize: 12.5,
                        color: AppColors.deepNavy.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, size: 16, color: config.color),
                  ),
                ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(borderRadius: AppShapes.small),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standardized loading state with human-friendly contextual message.
class AppLoadingState extends StatelessWidget {
  final String message;
  final bool isOverlay;

  const AppLoadingState({
    super.key,
    this.message = 'Loading…',
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandBlue),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.deepNavy,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );

    if (isOverlay) {
      return Container(
        color: AppColors.deepNavy.withValues(alpha: 0.35),
        child: content,
      );
    }

    return content;
  }
}

/// Backward-compatible alias for existing imports.
typedef AppLoadingWidget = AppLoadingState;

/// Standardized error state explaining what happened, whether it is recoverable,
/// and clear next steps without exposing technical details or stack traces.
class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? iconColor;

  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.buttonText = 'Try Again',
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? AppColors.emergencyRed;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: effectiveColor, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.subheading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary.copyWith(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(140, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
                ),
                onPressed: onRetry,
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Backward-compatible alias for existing imports.
typedef AppErrorWidget = AppErrorState;

/// Standardized calm empty state for logs, incidents, contacts, and lists.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.subtleBlueGray,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: Icon(icon, size: 30, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.subheading.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTypography.bodySecondary.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandBlue,
                  side: const BorderSide(color: AppColors.borderMedium),
                  minimumSize: const Size(120, 48),
                  shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Backward-compatible alias for existing imports.
typedef AppEmptyWidget = AppEmptyState;
