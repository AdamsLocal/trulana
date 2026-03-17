import 'package:flutter/material.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';

/// Step 3 — Lets the user choose which data streams Trulana manages.
///
/// These are mock toggles for MVP — actual data integrations are wired
/// in later phases. Pre-enabled defaults create a "just works" first
/// impression while letting privacy-conscious users opt out up front.
class DataStreamsStep extends StatefulWidget {
  const DataStreamsStep({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<DataStreamsStep> createState() => _DataStreamsStepState();
}

class _DataStreamsStepState extends State<DataStreamsStep> {
  /// All streams default to enabled so users feel immediate value.
  final List<bool> _toggles = List<bool>.filled(5, true);

  static const List<({IconData icon, String label})> _streams = [
    (icon: Icons.favorite, label: 'Apple Health'),
    (icon: Icons.calendar_today, label: 'Calendar'),
    (icon: Icons.email, label: 'Email'),
    (icon: Icons.account_balance, label: 'Banking'),
    (icon: Icons.home, label: 'Smart Home'),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          AnimatedListItem(
            index: 0,
            child: Text(
              'What should Trulana manage for you?',
              style: textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedListItem(
            index: 1,
            child: const Text(
              'You can change this anytime.',
              style: TextStyle(
                fontSize: 15,
                color: TrulanaColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int i = 0; i < _streams.length; i++) ...[
                    AnimatedListItem(
                      index: i + 2,
                      child: _StreamToggleCard(
                        icon: _streams[i].icon,
                        label: _streams[i].label,
                        value: _toggles[i],
                        onChanged: (bool value) {
                          setState(() => _toggles[i] = value);
                        },
                      ),
                    ),
                    if (i < _streams.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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

/// Individual data-stream toggle rendered as a glass card row.
class _StreamToggleCard extends StatelessWidget {
  const _StreamToggleCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: TrulanaColors.primaryCyan, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: TrulanaColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: TrulanaColors.primaryCyan,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
