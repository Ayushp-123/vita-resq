import 'package:flutter/material.dart';
import 'common/app_feedback.dart';

export 'common/app_feedback.dart';

// Backward-compatible widget implementations mapped directly to Phase 8 components.

/// Legacy AppLoadingWidget forwarding to [AppLoadingState].
class LegacyAppLoadingWidget extends StatelessWidget {
  final String? message;
  const LegacyAppLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return AppLoadingState(message: message ?? 'Loading…');
  }
}

/// Legacy AppErrorWidget forwarding to [AppErrorState].
class LegacyAppErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? iconColor;

  const LegacyAppErrorWidget({
    super.key,
    this.title = 'An Error Occurred',
    required this.message,
    this.buttonText = 'GO BACK',
    this.onRetry,
    this.icon = Icons.error_outline,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: title,
      message: message,
      buttonText: buttonText,
      onRetry: onRetry,
      icon: icon,
      iconColor: iconColor,
    );
  }
}

/// Legacy AppEmptyWidget forwarding to [AppEmptyState].
class LegacyAppEmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String title;

  const LegacyAppEmptyWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.title = 'No items yet',
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: icon,
    );
  }
}
