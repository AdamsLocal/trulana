import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

/// Agents view — live from agentsProvider.
class AgentsView extends ConsumerWidget {
  const AgentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);

    return Column(
      children: [
        _header(),
        Expanded(
          child: agentsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: TrulanaColors.primaryCyan,
                strokeWidth: 2,
              ),
            ),
            error: (e, s) => Center(
              child: Text('Failed to load agents',
                  style: TextStyle(color: TrulanaColors.dangerRed)),
            ),
            data: (agents) {
              final active = agents
                  .where((a) => a.status == AgentStatus.active)
                  .toList();
              final inactive = agents
                  .where((a) => a.status != AgentStatus.active)
                  .toList();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _AgentCard(
                      title: 'Active Tokens',
                      badge: '${active.length} live',
                      agents: active,
                      isEmpty: active.isEmpty,
                    ),
                    const SizedBox(height: 14),
                    _AgentCard(
                      title: 'Expired / Revoked',
                      agents: inactive,
                      isEmpty: inactive.isEmpty,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF14142A))),
      ),
      child: const Row(
        children: [
          Text('Agents',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TrulanaColors.textPrimary)),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.title,
    required this.agents,
    this.badge,
    this.isEmpty = false,
  });

  final String title;
  final String? badge;
  final List<AuthorizedAgent> agents;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1A),
        border: Border.all(color: const Color(0xFF14142A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF14142A))),
            ),
            child: Row(
              children: [
                Text(title.toUpperCase(),
                    style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: TrulanaColors.textTertiary)),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: TrulanaColors.primaryCyan
                              .withValues(alpha: 0.25)),
                    ),
                    child: Text(badge!,
                        style: TrulanaTheme.monoStyle.copyWith(
                            fontSize: 9,
                            color: TrulanaColors.primaryCyan)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('None',
                        style: TextStyle(
                            fontSize: 12,
                            color: TrulanaColors.textTertiary)),
                  )
                : Column(
                    children: agents.map((agent) {
                      final isLive = agent.status == AgentStatus.active;
                      return _AgentRow(
                        name: agent.agentName,
                        scope: agent.grantedScopes.join(', '),
                        ttl: _formatTtl(agent),
                        isLive: isLive,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTtl(AuthorizedAgent agent) {
    if (agent.status != AgentStatus.active) {
      final ago = DateTime.now().difference(agent.expirationDate);
      if (ago.inHours > 0) return 'expired ${ago.inHours}h ago';
      return 'expired ${ago.inMinutes}m ago';
    }
    final remaining = agent.expirationDate.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final min = remaining.inMinutes;
    final sec = remaining.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')} remaining';
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.name,
    required this.scope,
    required this.ttl,
    required this.isLive,
  });

  final String name;
  final String scope;
  final String ttl;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x05FFFFFF)))),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive
                  ? TrulanaColors.successGreen
                  : TrulanaColors.textTertiary,
              boxShadow: isLive
                  ? [
                      BoxShadow(
                          color: TrulanaColors.successGreen
                              .withValues(alpha: 0.5),
                          blurRadius: 4)
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name,
                  style: TrulanaTheme.monoStyle.copyWith(
                      fontSize: 12, color: TrulanaColors.textSecondary))),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF14142A))),
            child: Text(scope,
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 9, color: TrulanaColors.textTertiary)),
          ),
          const SizedBox(width: 8),
          Text(ttl,
              style: TrulanaTheme.monoStyle.copyWith(
                  fontSize: 10,
                  color: isLive
                      ? const Color(0xFF2A8A84)
                      : TrulanaColors.textTertiary)),
        ],
      ),
    );
  }
}
