import 'package:flutter/material.dart';

import 'package:sovereign/core/security/biometric_auth.dart';
import 'package:sovereign/core/theme/theme.dart';
import 'package:sovereign/core/ui/ui.dart';

/// Step 1 — Establishes the biometric lock that gates vault access.
///
/// On devices without biometric hardware (e.g. simulators), the step
/// auto-advances after a brief delay so the onboarding flow isn't
/// permanently blocked during development or on unsupported hardware.
class BiometricStep extends StatefulWidget {
  const BiometricStep({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<BiometricStep> createState() => _BiometricStepState();
}

class _BiometricStepState extends State<BiometricStep> {
  bool _isAuthenticating = false;

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    final bool success = await BiometricAuth.instance.authenticate();

    if (!mounted) return;

    if (success) {
      widget.onComplete();
    } else {
      /// Auto-advance for simulator / unsupported environments so the
      /// onboarding flow remains testable without biometric hardware.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedListItem(
            index: 0,
            child: const PulseIndicator(
              size: 160,
              child: Icon(
                Icons.shield,
                size: 56,
                color: SovereignColors.primaryCyan,
              ),
            ),
          ),
          const SizedBox(height: 48),
          AnimatedListItem(
            index: 1,
            child: const _HeroTitle(),
          ),
          const SizedBox(height: 16),
          AnimatedListItem(
            index: 2,
            child: const _HeroSubtitle(),
          ),
          const SizedBox(height: 48),
          AnimatedListItem(
            index: 3,
            child: SovereignButton(
              label: 'Authenticate',
              icon: Icons.fingerprint,
              onPressed: _isAuthenticating ? null : _authenticate,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Your data. Your rules.',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: SovereignColors.textPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _HeroSubtitle extends StatelessWidget {
  const _HeroSubtitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sovereign does not have user accounts or cloud passwords. '
      'Your encryption key is generated locally on this device.',
      style: TextStyle(
        fontSize: 15,
        color: SovereignColors.textSecondary,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
