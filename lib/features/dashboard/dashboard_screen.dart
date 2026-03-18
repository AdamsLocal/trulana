import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';

import 'widgets/vault_status_card.dart';
import 'widgets/connections_section.dart';
import 'widgets/monetization_card.dart';

/// Root screen for the Trulana command center.
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
      backgroundColor: TrulanaColors.background,
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
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/trulana-icon.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Trulana',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: TrulanaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedListItem(
                  index: 1,
                  child: const Text(
                    'Your local context server is running.',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: TrulanaColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedListItem(
                  index: 2,
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.terminal,
                          color: TrulanaColors.primaryCyan,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Connect with Claude or Cursor to start querying your vault. '
                            'REST on localhost:8432 · MCP via TRULANA_MCP=1',
                            style: TextStyle(
                              fontSize: 12,
                              color: TrulanaColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // — Vault heartbeat
                AnimatedListItem(
                  index: 3,
                  child: const VaultStatusCard(),
                ),

                const SizedBox(height: 28),

                // — Third-party agent connections
                AnimatedListItem(
                  index: 4,
                  child: const ConnectionsSection(),
                ),

                const SizedBox(height: 28),

                // — Earnings & pending lease requests
                AnimatedListItem(
                  index: 5,
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
