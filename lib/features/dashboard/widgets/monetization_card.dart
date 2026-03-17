import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sovereign/core/theme/theme.dart';
import 'package:sovereign/core/ui/ui.dart';
import 'package:sovereign/models/models.dart';
import 'package:sovereign/providers/providers.dart';

/// The Data Monetization Hub card — shows aggregate earnings and
/// pending lease requests.
///
/// Scoped to its own ConsumerWidget so that `totalEarningsProvider`
/// and `ledgerProvider` rebuilds don't propagate to sibling sections.
class MonetizationCard extends ConsumerWidget {
  const MonetizationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<double> earningsAsync =
        ref.watch(totalEarningsProvider);
    final AsyncValue<List<LedgerEntry>> ledgerAsync =
        ref.watch(ledgerProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _EarningsDisplay(earningsAsync: earningsAsync),
          const Divider(
            color: SovereignColors.glassBorder,
            height: 32,
          ),
          _PendingRequests(ledgerAsync: ledgerAsync),
        ],
      ),
    );
  }
}

/// Top portion: "Earnings This Month" with a glowing balance figure.
class _EarningsDisplay extends StatelessWidget {
  const _EarningsDisplay({required this.earningsAsync});

  final AsyncValue<double> earningsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Earnings This Month',
          style: TextStyle(
            fontSize: 14,
            color: SovereignColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        earningsAsync.when(
          loading: () => const CircularProgressIndicator(
            color: SovereignColors.primaryCyan,
            strokeWidth: 2,
          ),
          error: (Object error, StackTrace stack) => const Text(
            '—',
            style: TextStyle(
              fontSize: 28,
              color: SovereignColors.dangerRed,
            ),
          ),
          data: (double earnings) => Text(
            '\$${earnings.toStringAsFixed(2)} USD',
            style: SovereignTheme.monoStyle.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: SovereignColors.successGreen,
              shadows: <Shadow>[
                Shadow(
                  color: SovereignColors.successGreen.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom portion: list of pending ledger entries with Approve/Deny.
class _PendingRequests extends StatelessWidget {
  const _PendingRequests({required this.ledgerAsync});

  final AsyncValue<List<LedgerEntry>> ledgerAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Pending Requests',
          style: TextStyle(
            fontSize: 14,
            color: SovereignColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ledgerAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: SovereignColors.primaryCyan,
              strokeWidth: 2,
            ),
          ),
          error: (Object error, StackTrace stack) => const Text(
            'Failed to load requests',
            style: TextStyle(color: SovereignColors.dangerRed),
          ),
          data: (List<LedgerEntry> entries) {
            if (entries.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No pending lease requests',
                    style: TextStyle(
                      fontSize: 14,
                      color: SovereignColors.textTertiary,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: entries
                  .map((LedgerEntry entry) => _LeaseRequestRow(entry: entry))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

/// A single pending lease request with buyer info and action buttons.
class _LeaseRequestRow extends StatelessWidget {
  const _LeaseRequestRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.buyerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SovereignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.dataLeased,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SovereignColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${entry.amountUsd.toStringAsFixed(2)}',
            style: SovereignTheme.monoStyle.copyWith(
              fontSize: 14,
              color: SovereignColors.successGreen,
            ),
          ),
          const SizedBox(width: 12),
          SovereignButton(
            label: 'Approve',
            color: SovereignColors.successGreen,
            onPressed: () {
              // TODO: Wire to lease approval flow once backend is ready.
            },
          ),
          const SizedBox(width: 6),
          SovereignButton(
            label: 'Deny',
            color: SovereignColors.dangerRed,
            onPressed: () {
              // TODO: Wire to lease denial flow once backend is ready.
            },
          ),
        ],
      ),
    );
  }
}
