import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sovereign/core/theme/sovereign_colors.dart';

/// Glass-styled action button with two interaction modes:
///
/// * **Tap** — standard press with haptic feedback and a spring-back
///   scale animation.
/// * **Hold-to-confirm** — the user must press and hold for 1.5 s;
///   a radial progress ring fills as visual confirmation. Designed
///   for irreversible actions like revoking agent access.
class SovereignButton extends StatefulWidget {
  const SovereignButton({
    required this.label,
    this.onPressed,
    this.color = SovereignColors.primaryCyan,
    this.holdToConfirm = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool holdToConfirm;
  final IconData? icon;

  @override
  State<SovereignButton> createState() => _SovereignButtonState();
}

class _SovereignButtonState extends State<SovereignButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _pressed = false;

  static const _holdDuration = Duration(milliseconds: 1500);
  static const _scaleDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdToConfirm ? _holdDuration : _scaleDuration,
    );

    if (widget.holdToConfirm) {
      _controller.addStatusListener(_onHoldComplete);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onHoldComplete);
    _controller.dispose();
    super.dispose();
  }

  void _onHoldComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      widget.onPressed?.call();
      _controller.reset();
      setState(() => _pressed = false);
    }
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _pressed = true);
    if (widget.holdToConfirm) {
      HapticFeedback.lightImpact();
      _controller.forward(from: 0);
    } else {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    if (widget.holdToConfirm) {
      _controller.reset();
    } else {
      HapticFeedback.lightImpact();
      _controller.reverse();
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    setState(() => _pressed = false);
    if (widget.holdToConfirm) {
      _controller.reset();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color color =
        enabled ? widget.color : widget.color.withValues(alpha: 0.3);

    return GestureDetector(
      onTapDown: enabled ? _handleTapDown : null,
      onTapUp: enabled ? _handleTapUp : null,
      onTapCancel: enabled ? _handleTapCancel : null,
      child: AnimatedScale(
        scale: _pressed && !widget.holdToConfirm ? 0.95 : 1.0,
        duration: _scaleDuration,
        curve: Curves.elasticOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.holdToConfirm) ...[
                _HoldProgressRing(
                  animation: _controller,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, color: color, size: 18),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular progress ring that visualises the hold-to-confirm countdown.
class _HoldProgressRing extends StatelessWidget {
  const _HoldProgressRing({
    required this.animation,
    required this.color,
    required this.size,
  });

  final Animation<double> animation;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        return SizedBox.square(
          dimension: size,
          child: CircularProgressIndicator(
            value: animation.value,
            strokeWidth: 2,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        );
      },
    );
  }
}
