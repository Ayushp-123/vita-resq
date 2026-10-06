import 'package:flutter/material.dart';

/// Centralized motion and animation system for Vita ResQ.
///
/// Design direction: FAST + SMOOTH + SUBTLE
/// - 150-250ms transitions designed for immediate tactical responsiveness.
/// - Communicates state changes, user feedback, and hierarchy.
/// - Avoids distracting floating effects, excessive bounciness, and heavy parallax.
class AppMotion {
  AppMotion._();

  // -------------------------------------------------------------
  // DURATIONS (150 - 250ms)
  // -------------------------------------------------------------
  /// Fast duration (150ms) - Tap feedback, highlight changes, button presses
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal duration (200ms) - State toggles, accordion expansions, badge updates
  static const Duration normal = Duration(milliseconds: 200);

  /// Transition duration (250ms) - Modal reveals, tab changes, route transitions
  static const Duration transition = Duration(milliseconds: 250);

  /// Extended duration (350ms) - Complex layout morphs (used sparingly)
  static const Duration extended = Duration(milliseconds: 350);

  // -------------------------------------------------------------
  // CURVES
  // -------------------------------------------------------------
  /// Standard easing curve - smooth deceleration for natural UI entrance
  static const Curve easeOut = Curves.easeOutCubic;

  /// Emphasized easing curve - responsive acceleration & deceleration
  static const Curve easeInOut = Curves.easeInOutCubic;

  /// Quick feedback curve - immediate visual response to user touch
  static const Curve quick = Curves.easeOutQuad;
}

/// A subtle, accessible pressable wrapper providing tactile micro-feedback
/// (subtle 0.98 scale and slight opacity shift) without excessive bounce.
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.quick),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.quick),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// A subtle entrance transition (fade + gentle vertical offset) for cards & views
class AppFadeSlideTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final double offsetDistance;

  const AppFadeSlideTransition({
    super.key,
    required this.child,
    required this.animation,
    this.offsetDistance = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
        return Opacity(
          opacity: curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - curved.value) * offsetDistance),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
