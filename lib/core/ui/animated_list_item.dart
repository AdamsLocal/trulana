import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Wraps a child in a staggered fade + upward-slide entrance that
/// fires automatically when the widget first mounts. Pass the item's
/// position via [index] to offset the delay so sequential list items
/// cascade in one after another.
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 80),
    this.duration = const Duration(milliseconds: 400),
    super.key,
  });

  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final stagger = delay * index;
    return child
        .animate()
        .fadeIn(duration: duration, delay: stagger)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: duration,
          delay: stagger,
          curve: Curves.easeOutCubic,
        );
  }
}
