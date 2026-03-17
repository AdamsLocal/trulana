import 'dart:ui';

import 'package:flutter/material.dart';

/// Anamorphic glassmorphism card used as the primary surface element
/// throughout the Trulana UI. Blurs whatever sits behind it and
/// overlays a translucent white fill + border to create depth on
/// the dark mesh-gradient backgrounds.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.blur = 24,
    this.opacity = 0.06,
    this.borderOpacity = 0.12,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    super.key,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity),
                Colors.white.withValues(alpha: opacity * 0.4),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = _TapScaleWrapper(onTap: onTap!, child: card);
    }

    return card;
  }
}

/// Wraps a child in a scale-down animation on press to give tactile
/// feedback without relying on Material ink effects, which conflict
/// with the glass aesthetic.
class _TapScaleWrapper extends StatefulWidget {
  const _TapScaleWrapper({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<_TapScaleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
