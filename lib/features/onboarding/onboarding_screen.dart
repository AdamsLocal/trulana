import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

import 'steps/biometric_step.dart';
import 'steps/data_streams_step.dart';
import 'steps/engine_init_step.dart';
import 'steps/monetization_step.dart';
import 'steps/privacy_step.dart';

/// Orchestrates the 5-step onboarding flow that establishes the user's
/// local encryption vault, privacy preferences, and monetization settings.
///
/// Navigation is strictly linear — the [PageView] uses
/// [NeverScrollableScrollPhysics] so users can only advance forward
/// via each step's completion callback. This prevents skipping the
/// biometric gate or engine init sequence.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  /// Accumulated from step callbacks — assembled into [UserConfig] on completion.
  PrivacyLevel _privacyLevel = PrivacyLevel.standard;
  bool _autoMonetize = false;
  String? _walletAddress;

  static const int _totalSteps = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _advanceToNextStep() {
    if (_currentPage >= _totalSteps - 1) return;
    setState(() => _currentPage++);
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Persists the assembled [UserConfig] and hands off to the dashboard.
  ///
  /// The GoRouter redirect in [appRouterProvider] also watches
  /// [userConfigProvider], so navigation would happen reactively even
  /// without the explicit [context.go] — belt-and-suspenders.
  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    _isSaving = true;

    final UserConfig config = UserConfig(
      id: const Uuid().v4(),
      privacyLevel: _privacyLevel,
      autoMonetize: _autoMonetize,
      walletAddress: _walletAddress,
      vaultStatus: DateTime.now(),
    );

    await ref.read(userConfigProvider.notifier).saveConfig(config);

    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeshGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/trulana-icon.png',
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    BiometricStep(onComplete: _advanceToNextStep),
                    EngineInitStep(onComplete: _advanceToNextStep),
                    DataStreamsStep(onComplete: _advanceToNextStep),
                    PrivacyStep(
                      onComplete: _advanceToNextStep,
                      onPrivacyChanged: (PrivacyLevel level) {
                        _privacyLevel = level;
                      },
                    ),
                    MonetizationStep(
                      onComplete: _completeOnboarding,
                      onAutoMonetizeChanged: (bool value) {
                        _autoMonetize = value;
                      },
                      onWalletChanged: (String? address) {
                        _walletAddress = address;
                      },
                    ),
                  ],
                ),
              ),
              _DotIndicator(
                currentPage: _currentPage,
                totalSteps: _totalSteps,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped active indicator with round inactive dots.
/// The active dot stretches to a wider pill to visually anchor
/// the user's progress without dominating the screen.
class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.currentPage,
    required this.totalSteps,
  });

  final int currentPage;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (int index) {
        final bool isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? TrulanaColors.primaryCyan
                : TrulanaColors.textTertiary,
          ),
        );
      }),
    );
  }
}
