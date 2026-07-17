import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';
import 'package:trulana/providers/agents_provider.dart';

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
              final pending = agents
                  .where((a) => a.status == AgentStatus.pending)
                  .toList();
              final active = agents
                  .where((a) => a.status == AgentStatus.active)
                  .toList();
              final inactive = agents
                  .where((a) =>
                      a.status != AgentStatus.active &&
                      a.status != AgentStatus.pending)
                  .toList();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (pending.isNotEmpty) ...[
                      _PendingCard(agents: pending),
                      const SizedBox(height: 14),
                    ],
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

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.agents});

  final List<AuthorizedAgent> agents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1A),
        border: Border.all(color: TrulanaColors.warningAmber.withValues(alpha: 0.4)),
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
                Text('PENDING REQUESTS',
                    style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: TrulanaColors.warningAmber)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: TrulanaColors.warningAmber
                            .withValues(alpha: 0.4)),
                  ),
                  child: Text('${agents.length} awaiting',
                      style: TrulanaTheme.monoStyle.copyWith(
                          fontSize: 9,
                          color: TrulanaColors.warningAmber)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: agents
                  .map((agent) => _PendingRow(
                        agent: agent,
                        onTap: () => _openSheet(context, ref, agent),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSheet(
      BuildContext context, WidgetRef ref, AuthorizedAgent agent) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E0E1A),
      isScrollControlled: true,
      builder: (BuildContext ctx) => _ApprovalSheet(agent: agent),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.agent, required this.onTap});

  final AuthorizedAgent agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? fingerprint = agent.mcpPublicKeyFingerprint;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                color: TrulanaColors.warningAmber,
                boxShadow: [
                  BoxShadow(
                      color: TrulanaColors.warningAmber
                          .withValues(alpha: 0.5),
                      blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent.agentName,
                      style: TrulanaTheme.monoStyle.copyWith(
                          fontSize: 12,
                          color: TrulanaColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text('requests: ${agent.grantedScopes.join(', ')}',
                      style: TrulanaTheme.monoStyle.copyWith(
                          fontSize: 10,
                          color: TrulanaColors.textTertiary)),
                  if (fingerprint != null) ...[
                    const SizedBox(height: 2),
                    Text('Ed25519: $fingerprint',
                        overflow: TextOverflow.ellipsis,
                        style: TrulanaTheme.monoStyle.copyWith(
                            fontSize: 9,
                            color: TrulanaColors.textTertiary)),
                  ],
                ],
              ),
            ),
            Text('Review',
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 10,
                    color: TrulanaColors.primaryCyan)),
          ],
        ),
      ),
    );
  }
}

/// Modal sheet for reviewing a pending agent. The caller narrows scopes
/// by unchecking entries; at least one must remain checked to approve.
class _ApprovalSheet extends ConsumerStatefulWidget {
  const _ApprovalSheet({required this.agent});

  final AuthorizedAgent agent;

  @override
  ConsumerState<_ApprovalSheet> createState() => _ApprovalSheetState();
}

class _ApprovalSheetState extends ConsumerState<_ApprovalSheet> {
  late final Set<String> _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.agent.grantedScopes.toSet();
  }

  Future<void> _approve() async {
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(agentsProvider.notifier)
        .approveAgent(widget.agent.agentId,
            approvedScopes: _selected.toList());
    if (!mounted) return;
    setState(() => _busy = false);
    _closeWithFeedback(result, 'Approved');
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result =
        await ref.read(agentsProvider.notifier).rejectAgent(widget.agent.agentId);
    if (!mounted) return;
    setState(() => _busy = false);
    _closeWithFeedback(result, 'Rejected');
  }

  void _closeWithFeedback(AgentMutationResult r, String successVerb) {
    final String msg;
    switch (r) {
      case AgentMutationResult.success:
        msg = '$successVerb ${widget.agent.agentName}';
      case AgentMutationResult.notFound:
        msg = 'Agent no longer exists';
      case AgentMutationResult.notPending:
        msg = 'Agent is no longer pending';
      case AgentMutationResult.invalidScopes:
        msg = 'At least one scope must remain selected';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final requested = widget.agent.grantedScopes;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.agent.agentName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: TrulanaColors.textPrimary)),
            const SizedBox(height: 4),
            Text('agent_id: ${widget.agent.agentId}',
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 10, color: TrulanaColors.textTertiary)),
            if (widget.agent.mcpPublicKeyFingerprint != null) ...[
              const SizedBox(height: 8),
              Text('APPROVED MCP KEY',
                  style: TrulanaTheme.monoStyle.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: TrulanaColors.warningAmber)),
              const SizedBox(height: 3),
              SelectableText(widget.agent.mcpPublicKeyFingerprint!,
                  style: TrulanaTheme.monoStyle.copyWith(
                      fontSize: 9, color: TrulanaColors.textSecondary)),
            ],
            const SizedBox(height: 18),
            Text('REQUESTED SCOPES',
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: TrulanaColors.textTertiary)),
            const SizedBox(height: 8),
            ...requested.map(
              (scope) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: TrulanaColors.primaryCyan,
                title: Text(scope,
                    style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 12,
                        color: TrulanaColors.textSecondary)),
                value: _selected.contains(scope),
                onChanged: (bool? v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(scope);
                    } else {
                      _selected.remove(scope);
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: TrulanaColors.dangerRed
                              .withValues(alpha: 0.6)),
                      foregroundColor: TrulanaColors.dangerRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (_busy || _selected.isEmpty) ? null : _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TrulanaColors.primaryCyan,
                      foregroundColor: const Color(0xFF000814),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? 'Select a scope'
                          : 'Approve (${_selected.length})',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
