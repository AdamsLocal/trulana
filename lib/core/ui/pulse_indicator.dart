import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sovereign/core/theme/sovereign_colors.dart';

/// Sonar-ping concentric-ring animation used on the vault status
/// screen to convey that the local context engine is alive and
/// listening. Three rings expand outward in a staggered loop,
/// fading as they grow — reminiscent of a radar sweep.
class PulseIndicator extends StatefulWidget {
  const PulseIndicator({
    this.size = 120,
    this.color = SovereignColors.primaryCyan,
    this.child,
    super.key,
  });

  final double size;
  final Color color;
  final Widget? child;

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _PulseRingPainter(
              progress: _controller.value,
              color: widget.color,
            ),
            child: child,
          );
        },
        child: widget.child != null
            ? Center(child: widget.child)
            : null,
      ),
    );
  }
}

/// Draws 3 concentric circles staggered by 1/3 of the animation
/// cycle. Each ring expands from 20% to 100% of the available
/// radius while its opacity falls linearly to zero.
class _PulseRingPainter extends CustomPainter {
  _PulseRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  static const _ringCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2;

    for (var i = 0; i < _ringCount; i++) {
      final stagger = i / _ringCount;
      final t = (progress + stagger) % 1.0;

      final radius = maxRadius * (0.2 + 0.8 * t);
      final opacity = (1.0 - t).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
