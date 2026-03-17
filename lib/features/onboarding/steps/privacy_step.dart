import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';
import 'package:trulana/models/models.dart';

/// Step 4 — Configures the Auto-Redact Engine's aggressiveness.
///
/// The animated example card gives users an intuitive feel for how each
/// tier transforms their real-world context before it reaches third
/// parties, so they can make an informed privacy choice rather than
/// guessing what "Strict" vs "Paranoid" actually means.
class PrivacyStep extends StatefulWidget {
  const PrivacyStep({
    required this.onComplete,
    required this.onPrivacyChanged,
    super.key,
  });

  final VoidCallback onComplete;
  final ValueChanged<PrivacyLevel> onPrivacyChanged;

  @override
  State<PrivacyStep> createState() => _PrivacyStepState();
}

class _PrivacyStepState extends State<PrivacyStep> {
  PrivacyLevel _level = PrivacyLevel.standard;

  static const Map<PrivacyLevel, String> _examples = {
    PrivacyLevel.standard:
        'User wakes up at 6:30 AM, goes to Equinox in San Francisco, '
            'and buys Philz Coffee.',
    PrivacyLevel.strict:
        'User wakes up early, visits a premium gym in an urban area, '
            'and buys coffee.',
    PrivacyLevel.paranoid:
        'User is active in the mornings and prefers caffeinated beverages.',
  };

  void _onLevelChanged(PrivacyLevel level) {
    setState(() => _level = level);
    widget.onPrivacyChanged(level);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'How much should be exposed to AI?',
            style: textTheme.headlineLarge,
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 40),
          PrivacySlider(
            value: _level,
            onChanged: _onLevelChanged,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _PrivacyExampleCard(
                key: ValueKey<PrivacyLevel>(_level),
                exampleText: _examples[_level]!,
              ),
            ),
          ),
          Center(
            child: TrulanaButton(
              label: 'Continue',
              onPressed: widget.onComplete,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Shows a concrete before/after example of how the selected privacy
/// level transforms a real-world data snippet. Wrapped in
/// [AnimatedSwitcher] by the parent so transitions cross-fade smoothly.
class _PrivacyExampleCard extends StatelessWidget {
  const _PrivacyExampleCard({
    required this.exampleText,
    super.key,
  });

  final String exampleText;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Example: What is the user\'s morning routine?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TrulanaColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              exampleText,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
