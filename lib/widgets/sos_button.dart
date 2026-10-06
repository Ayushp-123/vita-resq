import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback? onSOSActivated;
  final VoidCallback? onPressed;
  final Duration holdDuration;
  final double size;

  const SOSButton({
    super.key,
    this.onSOSActivated,
    this.onPressed,
    this.holdDuration = const Duration(milliseconds: 2000),
    this.size = 220,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _holdController;
  late Animation<double> _holdAnimation;

  bool _isHolding = false;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();

    // Gentle ambient radar ripple in idle state
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // Hold progress controller
    _holdController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _holdAnimation = CurvedAnimation(
      parent: _holdController,
      curve: Curves.linear,
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isActivated) {
        _isActivated = true;
        HapticFeedback.vibrate();
        final callback = widget.onSOSActivated ?? widget.onPressed;
        if (callback != null) {
          callback();
        }
      }
    });
  }

  void _onHoldStart() {
    if (_isActivated) return;
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.heavyImpact();
    _holdController.forward();
  }

  void _onHoldEnd([String reason = '']) {
    if (_isActivated) return;
    if (_holdController.value < 0.99) {
      // User released early: Cancel hold gesture safely
      _holdController.reset();
      setState(() {
        _isHolding = false;
      });
      HapticFeedback.selectionClick();
    } else {
      _isActivated = true;
      HapticFeedback.vibrate();
      final callback = widget.onSOSActivated ?? widget.onPressed;
      if (callback != null) {
        callback();
      }
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  Widget _buildAmbientRadarRing(double delay, double maxScale, double initialOpacity) {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        if (_isHolding) return const SizedBox.shrink();
        double progress = (_radarController.value + delay) % 1.0;
        double scale = 1.0 + (maxScale - 1.0) * progress;
        double opacity = (1.0 - progress) * initialOpacity;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size * 0.85,
            height: widget.size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.emergencyRed.withValues(alpha: opacity.clamp(0.0, 1.0)),
                width: 2.0,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency SOS Trigger. Press and hold for two seconds to activate emergency dispatch.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _onHoldStart(),
        onPointerUp: (_) => _onHoldEnd('UP'),
        onPointerCancel: (_) => _onHoldEnd('CANCEL'),
        child: SizedBox(
          width: widget.size + 60,
          height: widget.size + 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient Radar Rings (Idle Mode Only)
              _buildAmbientRadarRing(0.0, 1.5, 0.4),
              _buildAmbientRadarRing(0.5, 1.9, 0.25),

              // Dynamic Circular Progress Ring for Hold-to-Activate
              AnimatedBuilder(
                animation: _holdAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(widget.size + 36, widget.size + 36),
                    painter: _SOSHoldProgressPainter(
                      progress: _holdAnimation.value,
                      isHolding: _isHolding,
                    ),
                  );
                },
              ),

              // Main High-Visibility Emergency Button
              AnimatedBuilder(
                animation: _holdAnimation,
                builder: (context, child) {
                  double scale = _isHolding ? 0.95 + (_holdAnimation.value * 0.06) : 1.0;
                  double secondsLeft = (1.0 - _holdAnimation.value) * (widget.holdDuration.inMilliseconds / 1000);

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.emergencyRed,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emergencyRed.withValues(alpha: _isHolding ? 0.5 : 0.3),
                            blurRadius: _isHolding ? 32 : 20,
                            spreadRadius: _isHolding ? 4 : 1,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 4,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Inner Radial Glow
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.2, -0.3),
                                radius: 0.85,
                                colors: [
                                  Colors.white.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          // High-Contrast Emergency Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isHolding ? Icons.touch_app_rounded : Icons.shield_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isHolding
                                        ? (_holdAnimation.value >= 1.0 ? 'ACTIVATING!' : '${secondsLeft.toStringAsFixed(1)}s')
                                        : 'SOS',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black38,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _isHolding
                                          ? (_holdAnimation.value >= 1.0 ? 'RELEASED' : 'HOLD STEADY')
                                          : 'HOLD 2 SECONDS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white.withValues(alpha: 0.95),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering a thick, rounded progress track around the SOS button
class _SOSHoldProgressPainter extends CustomPainter {
  final double progress;
  final bool isHolding;

  _SOSHoldProgressPainter({
    required this.progress,
    required this.isHolding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Background track (subtle light track)
    final trackPaint = Paint()
      ..color = isHolding ? AppTheme.emergencyRed.withValues(alpha: 0.2) : Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.0) {
      // Dynamic Glowing Progress Arc
      final progressPaint = Paint()
        ..color = AppTheme.emergencyRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.0
        ..strokeCap = StrokeCap.round;

      // Start arc from the top (-pi/2)
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SOSHoldProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isHolding != isHolding;
  }
}
