import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trulana/core/theme/trulana_colors.dart';

/// Full-screen animated mesh gradient that drifts slowly behind all
/// content. The organic movement prevents the dark background from
/// feeling static while keeping the CPU cost trivial (only 4 radial
/// gradient paints per frame via a single CustomPainter).
class MeshGradientBackground extends StatefulWidget {
  const MeshGradientBackground({
    required this.child,
    this.colors,
    super.key,
  });

  final Widget child;
  final List<Color>? colors;

  @override
  State<MeshGradientBackground> createState() =>
      _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _defaultColors = <Color>[
    TrulanaColors.background,
    Color(0xFF0D1B2A),
    Color(0xFF1B0A2E),
    TrulanaColors.background,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? _defaultColors;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            return CustomPaint(
              painter: _MeshPainter(
                progress: _controller.value,
                colors: colors,
              ),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

/// Draws four overlapping radial gradients whose centers orbit in
/// gentle ellipses. Each blob uses a different Lissajous phase so
/// the overall field looks organic rather than tiled.
class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.progress,
    required this.colors,
  });

  final double progress;
  final List<Color> colors;

  /// Pre-computed orbital parameters: [xFreq, yFreq, phase].
  static const _orbits = <List<double>>[
    [1.0, 1.3, 0.0],
    [1.4, 1.0, math.pi / 3],
    [0.8, 1.6, math.pi / 1.5],
    [1.2, 0.9, math.pi / 2],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    for (var i = 0; i < _orbits.length; i++) {
      final orbit = _orbits[i];
      final cx = size.width *
          (0.5 + 0.3 * math.sin(t * orbit[0] + orbit[2]));
      final cy = size.height *
          (0.5 + 0.3 * math.cos(t * orbit[1] + orbit[2]));

      final color = colors[i % colors.length];
      final radius = size.shortestSide * 0.6;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0.0)],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        );

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
