import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sovereign/core/theme/theme.dart';
import 'package:sovereign/core/ui/ui.dart';
import 'package:sovereign/models/models.dart';
import 'package:sovereign/providers/providers.dart';

/// Displays the local vault's heartbeat — a sonar pulse paired with
/// the last-sync timestamp. Lives in its own widget so the
/// `userConfigProvider` rebuild boundary stays tight and the pulse
/// animation never causes the entire dashboard to repaint.
class VaultStatusCard extends ConsumerWidget {
  const VaultStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserConfig?> configAsync =
        ref.watch(userConfigProvider);

    return configAsync.when(
      loading: () => const GlassCard(
        child: SizedBox(
          height: 60,
          child: Center(
            child: CircularProgressIndicator(
              color: SovereignColors.primaryCyan,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      error: (Object error, StackTrace stack) => const GlassCard(
        child: Text(
          'Unable to read vault status',
          style: TextStyle(color: SovereignColors.dangerRed),
        ),
      ),
      data: (UserConfig? config) {
        if (config == null) {
          return const GlassCard(
            child: Text(
              'Vault not configured',
              style: TextStyle(color: SovereignColors.textTertiary),
            ),
          );
        }

        final Duration elapsed =
            DateTime.now().difference(config.vaultStatus);
        final String agoLabel = _formatDuration(elapsed);

        return GlassCard(
          child: Row(
            children: <Widget>[
              const PulseIndicator(
                size: 60,
                color: SovereignColors.primaryCyan,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Local Vault',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: SovereignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last synchronized: $agoLabel ago',
                      style: SovereignTheme.monoStyle.copyWith(
                        fontSize: 12,
                        color: SovereignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Converts a [Duration] into a human-friendly relative string
  /// without exposing exact timestamps (privacy-conscious UX).
  static String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return 'just now';
  }
}
