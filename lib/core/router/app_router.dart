import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sovereign/features/dashboard/dashboard_screen.dart';
import 'package:sovereign/features/onboarding/onboarding_screen.dart';
import 'package:sovereign/providers/user_config_provider.dart';

/// Central [GoRouter] instance wired to Riverpod so route guards
/// re-evaluate reactively whenever [userConfigProvider] changes.
final appRouterProvider = Provider<GoRouter>((Ref ref) {
  final userConfigAsync = ref.watch(userConfigProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RouterRefreshNotifier(ref, userConfigProvider),
    redirect: (BuildContext context, GoRouterState routerState) {
      final bool isLoading = userConfigAsync is AsyncLoading;
      if (isLoading) return null;

      final bool hasConfig = userConfigAsync.valueOrNull != null;
      final bool isOnboarding =
          routerState.matchedLocation.startsWith('/onboarding');

      if (!hasConfig && !isOnboarding) return '/onboarding';
      if (hasConfig && isOnboarding) return '/dashboard';

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (_, _) => '/dashboard',
      ),
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (BuildContext context, GoRouterState state) =>
            const DashboardScreen(),
      ),
      GoRoute(
        path: '/gatekeeper',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderScreen(title: 'Gatekeeper'),
      ),
      GoRoute(
        path: '/engine-settings',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderScreen(title: 'Engine Settings'),
      ),
    ],
  );
});

/// Bridges Riverpod's reactive system to GoRouter's [Listenable]-based
/// refresh mechanism so redirects fire whenever auth state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref, ProviderListenable<Object?> provider) {
    ref.listen<Object?>(provider, (_, _) => notifyListeners());
  }
}

/// Temporary stand-in for screens that will be built in later phases.
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
    );
  }
}
