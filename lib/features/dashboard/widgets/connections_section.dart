import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sovereign/core/theme/theme.dart';
import 'package:sovereign/core/ui/ui.dart';
import 'package:sovereign/models/models.dart';
import 'package:sovereign/providers/providers.dart';

/// Horizontal scrolling roster of active third-party agents.
///
/// Separated from the dashboard so the `agentsProvider` rebuild
/// boundary is scoped to this subtree alone — the rest of the
/// dashboard won't repaint when agents change.
class ConnectionsSection extends ConsumerWidget {
  const ConnectionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AuthorizedAgent>> agentsAsync =
        ref.watch(agentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Active Connections',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: SovereignColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        agentsAsync.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(
              child: CircularProgressIndicator(
                color: SovereignColors.primaryCyan,
                strokeWidth: 2,
              ),
            ),
          ),
          error: (Object error, StackTrace stack) => const SizedBox(
            height: 140,
            child: Center(
              child: Text(
                'Failed to load connections',
                style: TextStyle(color: SovereignColors.dangerRed),
              ),
            ),
          ),
          data: (List<AuthorizedAgent> agents) {
            final List<AuthorizedAgent> active = agents
                .where(
                  (AuthorizedAgent a) => a.status == AgentStatus.active,
                )
                .toList();

            if (active.isEmpty) {
              return const SizedBox(
                height: 140,
                child: Center(
                  child: Text(
                    'No active connections',
                    style: TextStyle(
                      color: SovereignColors.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: active.length,
                itemBuilder: (BuildContext context, int index) {
                  return _AgentTile(agent: active[index]);
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: SovereignButton(
            label: 'Revoke All Access',
            holdToConfirm: true,
            color: SovereignColors.dangerRed,
            onPressed: () {
              ref.read(agentsProvider.notifier).revokeAll();
            },
          ),
        ),
      ],
    );
  }
}

/// Individual agent card rendered inside the horizontal list.
///
/// Kept private to this file because it has no standalone value —
/// it only makes sense within the [ConnectionsSection] context.
class _AgentTile extends ConsumerWidget {
  const _AgentTile({required this.agent});

  final AuthorizedAgent agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    agent.agentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SovereignColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _RevokeIconButton(agentId: agent.agentId),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: agent.grantedScopes
                    .map(
                      (String scope) => StatusBadge(
                        label: scope,
                        color: SovereignColors.primaryCyan,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny icon button to revoke a single agent's access.
///
/// Extracted so its `InkWell` hit area is self-contained and doesn't
/// interfere with the parent card's tap handler.
class _RevokeIconButton extends ConsumerWidget {
  const _RevokeIconButton({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(agentsProvider.notifier).revokeAgent(agentId);
      },
      child: const Icon(
        Icons.close,
        size: 18,
        color: SovereignColors.dangerRed,
      ),
    );
  }
}
