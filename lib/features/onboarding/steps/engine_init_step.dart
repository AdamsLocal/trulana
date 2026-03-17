import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:sovereign/core/theme/theme.dart';
import 'package:sovereign/core/ui/ui.dart';

/// Step 2 — Simulates the local AI engine boot sequence.
///
/// The terminal-style reveal builds user confidence that everything
/// is happening on-device before the flow asks for personal preferences.
/// Lines are revealed every 800 ms over a 4-second progress bar; the
/// step auto-advances once the bar fills.
class EngineInitStep extends StatefulWidget {
  const EngineInitStep({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<EngineInitStep> createState() => _EngineInitStepState();
}

class _EngineInitStepState extends State<EngineInitStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Timer _lineTimer;

  /// Starts at 1 so the first line renders immediately on mount.
  int _visibleCount = 1;

  static const List<String> _lines = [
    '> Initializing local AI engine...',
    '> Loading quantized SLM to Neural Processing Unit...',
    '> Disconnecting from cloud services...',
    '> Establishing on-device encryption vault...',
    '> System ready. All operations are local.',
  ];

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    _progressController.addStatusListener(_onProgressComplete);

    _lineTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      _revealNextLine,
    );
  }

  void _revealNextLine(Timer timer) {
    if (_visibleCount < _lines.length) {
      setState(() => _visibleCount++);
    }
    if (_visibleCount >= _lines.length) {
      timer.cancel();
    }
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      /// Brief pause so the user can read the final "System ready" line
      /// before the screen transitions away.
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _lineTimer.cancel();
    _progressController.removeStatusListener(_onProgressComplete);
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _visibleCount; i++)
                _TerminalLine(
                  key: ValueKey<int>(i),
                  text: _lines[i],
                  isSuccess: i == _lines.length - 1,
                ),
              const SizedBox(height: 24),
              _ProgressBar(animation: _progressController),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single line of terminal output with a fade-in entrance animation.
/// Keyed by index so Flutter preserves already-visible lines across rebuilds.
class _TerminalLine extends StatelessWidget {
  const _TerminalLine({
    required this.text,
    required this.isSuccess,
    super.key,
  });

  final String text;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: SovereignTheme.monoStyle.copyWith(
          color: isSuccess
              ? SovereignColors.successGreen
              : SovereignColors.primaryCyan,
          fontSize: 13,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

/// Linear progress bar that fills in primaryCyan over the boot sequence.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: animation.value,
            backgroundColor:
                SovereignColors.primaryCyan.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(
              SovereignColors.primaryCyan,
            ),
            minHeight: 3,
          ),
        );
      },
    );
  }
}
