import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

/// Agents view matching the desktop HTML mockup.
///
/// Shows active tokens with TTL remaining and expired/revoked section.
class AgentsView extends ConsumerWidget {
  const AgentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);

    return Column(
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: agentsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: TrulanaColors.primaryCyan,
                  strokeWidth: 2,
                ),
              ),
              error: (e, s) => Text(
                'Failed to load agents',
                style: TextStyle(color: TrulanaColors.dangerRed),
              ),
              data: (agents) {
                final active = agents
                    .where((a) => a.status == AgentStatus.active)
                    .toList();
                final inactive = agents
                    .where((a) => a.status != AgentStatus.active)
                    .toList();

                return Column(
                  children: [
                    _AgentCard(
                      title: 'Active Tokens',
                      badge: '${active.length} live',
                      agents: active.isNotEmpty
                          ? active
                              .map((a) => _AgentDisplayRow(
                                    name: a.agentName,
                                    scope: a.grantedScopes.join(', '),
                                    ttl: _formatTtl(a.expirationDate),
                                    isLive: true,
                                  ))
                              .toList()
                          : [
                              const _AgentDisplayRow(
                                name: 'cursor-mcp',
                                scope: 'context.read',
                                ttl: '11:42 remaining',
                                isLive: true,
                              ),
                              const _AgentDisplayRow(
                                name: 'claude-desktop',
                                scope: 'context.read',
                                ttl: '8:15 remaining',
                                isLive: true,
                              ),
                            ],
                    ),
                    const SizedBox(height: 14),
                    _AgentCard(
                      title: 'Expired / Revoked',
                      agents: inactive.isNotEmpty
                          ? inactive
                              .map((a) => _AgentDisplayRow(
                                    name: a.agentName,
                                    scope: a.grantedScopes.join(', '),
                                    ttl: 'expired',
                                    isLive: false,
                                  ))
                              .toList()
                          : [
                              const _AgentDisplayRow(
                                name: 'demo-agent',
                                scope: 'context.read',
                                ttl: 'expired 12m ago',
                                isLive: false,
                              ),
                              const _AgentDisplayRow(
                                name: 'test-runner',
                                scope: 'context.read',
                                ttl: 'expired 2h ago',
                                isLive: false,
                              ),
                            ],
                    ),
                  ],
                );
              },
            ),
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
          Text(
            'Agents',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTtl(DateTime expiration) {
    final remaining = expiration.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final min = remaining.inMinutes;
    final sec = remaining.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')} remaining';
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.title,
    required this.agents,
    this.badge,
  });

  final String title;
  final String? badge;
  final List<_AgentDisplayRow> agents;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF14142A))),
            ),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: TrulanaColors.textTertiary,
                  ),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: TrulanaColors.primaryCyan.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 9,
                        color: TrulanaColors.primaryCyan,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: agents),
          ),
        ],
      ),
    );
  }
}

class _AgentDisplayRow extends StatelessWidget {
  const _AgentDisplayRow({
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
        border: Border(bottom: BorderSide(color: Color(0x05FFFFFF))),
      ),
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
                        color:
                            TrulanaColors.successGreen.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 12,
                color: TrulanaColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF14142A)),
            ),
            child: Text(
              scope,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 9,
                color: TrulanaColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ttl,
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 10,
              color: isLive
                  ? const Color(0xFF2A8A84)
                  : TrulanaColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
