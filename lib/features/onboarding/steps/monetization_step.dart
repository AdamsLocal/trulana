import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:sovereign/core/theme/theme.dart';
import 'package:sovereign/core/ui/ui.dart';

/// Step 5 — Final step offering opt-in data monetization.
///
/// Positioned last deliberately: by now the user has experienced the
/// privacy-first posture (biometric lock, on-device engine, privacy
/// slider) and is more receptive to the value proposition that *they*
/// should capture the economic value of their own data.
class MonetizationStep extends StatefulWidget {
  const MonetizationStep({
    required this.onComplete,
    required this.onAutoMonetizeChanged,
    required this.onWalletChanged,
    super.key,
  });

  final VoidCallback onComplete;
  final ValueChanged<bool> onAutoMonetizeChanged;
  final ValueChanged<String?> onWalletChanged;

  @override
  State<MonetizationStep> createState() => _MonetizationStepState();
}

class _MonetizationStepState extends State<MonetizationStep> {
  bool _autoMonetize = false;
  final TextEditingController _walletController = TextEditingController();

  void _onAutoMonetizeChanged(bool value) {
    setState(() => _autoMonetize = value);
    widget.onAutoMonetizeChanged(value);
    if (!value) {
      _walletController.clear();
      widget.onWalletChanged(null);
    }
  }

  @override
  void dispose() {
    _walletController.dispose();
    super.dispose();
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
            'Brands pay billions for user data.',
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
          const SizedBox(height: 8),
          const Text(
            "It's time they paid you.",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SovereignColors.primaryCyan,
            ),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 500.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 40),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MonetizeToggle(
                    value: _autoMonetize,
                    onChanged: _onAutoMonetizeChanged,
                  ),
                  if (_autoMonetize) ...[
                    const SizedBox(height: 16),
                    _WalletInput(
                      controller: _walletController,
                      onChanged: (String value) {
                        widget.onWalletChanged(
                          value.isEmpty ? null : value,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SovereignButton(
              label: 'Enter Sovereign',
              icon: Icons.rocket_launch,
              onPressed: widget.onComplete,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Toggle card for the data-leasing opt-in.
class _MonetizeToggle extends StatelessWidget {
  const _MonetizeToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(
            Icons.monetization_on_outlined,
            color: SovereignColors.warningAmber,
            size: 24,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Enable data leasing',
              style: TextStyle(
                color: SovereignColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: SovereignColors.primaryCyan,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Wallet address input that reveals when data leasing is enabled.
/// Slides in with a fade for a premium feel.
class _WalletInput extends StatelessWidget {
  const _WalletInput({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payout Destination',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SovereignColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: SovereignTheme.monoStyle.copyWith(fontSize: 14),
            cursorColor: SovereignColors.primaryCyan,
            decoration: const InputDecoration(
              hintText: 'Enter wallet address or leave blank for fiat',
              hintStyle: TextStyle(
                color: SovereignColors.textTertiary,
                fontSize: 13,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
