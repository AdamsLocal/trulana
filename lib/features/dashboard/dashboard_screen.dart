import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sovereign/core/theme/theme.dart';
import 'package:sovereign/core/ui/ui.dart';

import 'widgets/vault_status_card.dart';
import 'widgets/connections_section.dart';
import 'widgets/monetization_card.dart';

/// Root screen for the Sovereign command center.
///
/// Composes the vault heartbeat, active connections, and monetization
/// modules into a single scrollable column over the animated mesh
/// background. Each section is wrapped in [AnimatedListItem] so the
/// initial mount cascades with a staggered fade-up entrance,
/// reinforcing the "systems coming online" aesthetic.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SovereignColors.background,
      body: MeshGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 24),

                // — Header
                AnimatedListItem(
                  index: 0,
                  child: const Text(
                    'Welcome back.',
                    style: TextStyle(
                      fontSize: 14,
                      color: SovereignColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedListItem(
                  index: 1,
                  child: const Text(
                    'You are sovereign.',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: SovereignColors.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // — Vault heartbeat
                AnimatedListItem(
                  index: 2,
                  child: const VaultStatusCard(),
                ),

                const SizedBox(height: 28),

                // — Third-party agent connections
                AnimatedListItem(
                  index: 3,
                  child: const ConnectionsSection(),
                ),

                const SizedBox(height: 28),

                // — Earnings & pending lease requests
                AnimatedListItem(
                  index: 4,
                  child: const MonetizationCard(),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
