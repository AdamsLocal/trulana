import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

/// Dashboard view matching the desktop HTML mockup.
///
/// Grid layout: vault stats, redaction bars, connected agents,
/// recent activity, and full audit trail.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(userConfigProvider);
    final agentsAsync = ref.watch(agentsProvider);

    return Column(
      children: [
        // — Header
        _ContentHeader(
          title: 'Dashboard',
          trailing: configAsync.whenOrNull(
            data: (config) => config != null
                ? PrivacyToggleWidget(
                    level: config.privacyLevel,
                    onChanged: (level) {
                      ref
                          .read(userConfigProvider.notifier)
                          .updatePrivacyLevel(level);
                    },
                  )
                : null,
          ),
        ),

        // — Scrollable grid content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Row 1: Vault status + Redaction stats
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(child: _VaultStatusCard()),
                    const SizedBox(width: 14),
                    const Expanded(child: _RedactionStatsCard()),
                  ],
                ),
                const SizedBox(height: 14),

                // Row 2: Connected agents + Recent activity
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ConnectedAgentsCard(agentsAsync: agentsAsync)),
                    const SizedBox(width: 14),
                    const Expanded(child: _RecentActivityCard()),
                  ],
                ),
                const SizedBox(height: 14),

                // Full-width audit trail
                const _AuditTrailCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable content header bar.
class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF14142A)),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Card wrapper matching the HTML mockup card style.
class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.title,
    required this.child,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final Widget child;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1A),
        border: Border.all(color: const Color(0xFF14142A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF14142A)),
              ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (badgeColor ?? TrulanaColors.primaryCyan)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 9,
                        color: badgeColor ?? TrulanaColors.primaryCyan,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Vault status card showing live entry, preference, and agent counts.
class _VaultStatusCard extends ConsumerWidget {
  const _VaultStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);
    final prefsAsync = ref.watch(preferencesProvider);

    final int? agentCount = agentsAsync.valueOrNull?.length;
    final int? prefCount = prefsAsync.valueOrNull?.length;
    final bool isLoading = agentsAsync.isLoading || prefsAsync.isLoading;

    if (isLoading) {
      return _DashCard(
        title: 'Vault Status',
        badge: 'encrypted',
        badgeColor: TrulanaColors.successGreen,
        child: const SizedBox(
          height: 48,
          child: Center(
            child: CircularProgressIndicator(
              color: TrulanaColors.primaryCyan,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return _DashCard(
      title: 'Vault Status',
      badge: 'encrypted',
      badgeColor: TrulanaColors.successGreen,
      child: Row(
        children: [
          // Vault entries are stored in the in-memory ContextVault (6 entries).
          const _StatColumn(value: '6', label: 'Entries'),
          _StatColumn(
            value: prefCount != null ? '$prefCount' : '—',
            label: 'Preferences',
          ),
          _StatColumn(
            value: agentCount != null ? '$agentCount' : '—',
            label: 'Agents',
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: TrulanaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: TrulanaColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Redaction statistics with colored bars.
class _RedactionStatsCard extends StatelessWidget {
  const _RedactionStatsCard();

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: 'Redactions Today',
      badge: '47 total',
      badgeColor: TrulanaColors.primaryCyan,
      child: Column(
        children: const [
          _RedactionBar(label: 'PII', percent: 0.72, count: '18', color: Color(0xFFF05858)),
          SizedBox(height: 10),
          _RedactionBar(label: 'Entity', percent: 0.56, count: '14', color: TrulanaColors.primaryCyan),
          SizedBox(height: 10),
          _RedactionBar(label: 'General', percent: 0.44, count: '11', color: Color(0xFFE0C85C)),
          SizedBox(height: 10),
          _RedactionBar(label: 'Blocked', percent: 0.16, count: '4', color: TrulanaColors.successGreen),
        ],
      ),
    );
  }
}

class _RedactionBar extends StatelessWidget {
  const _RedactionBar({
    required this.label,
    required this.percent,
    required this.count,
    required this.color,
  });

  final String label;
  final double percent;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 10,
              color: TrulanaColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: TrulanaColors.primaryCyan.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            count,
            textAlign: TextAlign.right,
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 10,
              color: TrulanaColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Connected agents card showing live agent data from [agentsProvider].
class _ConnectedAgentsCard extends StatelessWidget {
  const _ConnectedAgentsCard({required this.agentsAsync});

  final AsyncValue<List<AuthorizedAgent>> agentsAsync;

  /// Formats remaining TTL for display: "11:42" style or "expired".
  static String _formatTtl(AuthorizedAgent agent) {
    if (agent.status != AgentStatus.active) return 'expired';
    final Duration remaining =
        agent.expirationDate.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final int minutes = remaining.inMinutes;
    final int seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return agentsAsync.when(
      loading: () => const _DashCard(
        title: 'Connected Agents',
        child: SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(
              color: TrulanaColors.primaryCyan,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      error: (_, __) => const _DashCard(
        title: 'Connected Agents',
        child: Text(
          'Failed to load agents',
          style: TextStyle(color: TrulanaColors.dangerRed, fontSize: 12),
        ),
      ),
      data: (agents) {
        final List<AuthorizedAgent> active = agents
            .where((a) =>
                a.status == AgentStatus.active &&
                !a.expirationDate.isBefore(DateTime.now()))
            .toList();

        return _DashCard(
          title: 'Connected Agents',
          badge: '${active.length} active',
          badgeColor: TrulanaColors.primaryCyan,
          child: agents.isEmpty
              ? Text(
                  'No agents connected',
                  style: TextStyle(
                    fontSize: 12,
                    color: TrulanaColors.textTertiary,
                  ),
                )
              : Column(
                  children: agents.take(5).map((a) {
                    final bool isLive = a.status == AgentStatus.active &&
                        !a.expirationDate.isBefore(DateTime.now());
                    return _AgentRow(
                      name: a.agentName,
                      scope: a.grantedScopes.isNotEmpty
                          ? a.grantedScopes.first
                          : 'none',
                      ttl: _formatTtl(a),
                      isLive: isLive,
                    );
                  }).toList(),
                ),
        );
      },
    );
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
        border: Border(
          bottom: BorderSide(color: Color(0x05FFFFFF)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive ? TrulanaColors.successGreen : TrulanaColors.textTertiary,
              boxShadow: isLive
                  ? [BoxShadow(color: TrulanaColors.successGreen.withValues(alpha: 0.5), blurRadius: 4)]
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
              color: isLive ? const Color(0xFF2A8A84) : TrulanaColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent activity card with color-coded action tags.
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: 'Recent Activity',
      child: Column(
        children: const [
          _AuditEntry(time: '14:32:01', action: 'redact', detail: 'cursor-mcp · 7 redactions', isRedactHighlight: true),
          _AuditEntry(time: '14:31:58', action: 'query', detail: 'cursor-mcp · "work schedule"'),
          _AuditEntry(time: '14:28:44', action: 'auth', detail: 'claude-desktop · granted ttl=900s'),
          _AuditEntry(time: '14:22:10', action: 'deny', detail: 'unknown-app · no valid token'),
        ],
      ),
    );
  }
}

/// Full-width audit trail card.
class _AuditTrailCard extends StatelessWidget {
  const _AuditTrailCard();

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: 'Audit Trail',
      badge: 'encrypted · tamper-evident',
      badgeColor: TrulanaColors.successGreen,
      child: Column(
        children: const [
          _AuditEntry(
            time: '14:32:01',
            action: 'redact',
            detail: 'cursor-mcp queried "work schedule" → [PERSON] [EMAIL] [LOCATION] stripped',
            isRedactHighlight: true,
          ),
          _AuditEntry(
            time: '14:28:44',
            action: 'auth',
            detail: 'claude-desktop handshake · scopes: context.read · token issued · ttl=900s',
          ),
          _AuditEntry(
            time: '14:22:10',
            action: 'deny',
            detail: 'unknown-app attempted query without token · request rejected',
          ),
          _AuditEntry(
            time: '14:15:33',
            action: 'query',
            detail: 'cursor-mcp queried "morning routine" → matched 1 vault entry · 12 redactions',
          ),
        ],
      ),
    );
  }
}

/// Single audit log entry row used across dashboard cards.
class _AuditEntry extends StatelessWidget {
  const _AuditEntry({
    required this.time,
    required this.action,
    required this.detail,
    this.isRedactHighlight = false,
  });

  final String time;
  final String action;
  final String detail;
  final bool isRedactHighlight;

  Color get _actionColor => switch (action) {
        'auth' => TrulanaColors.primaryCyan,
        'query' => TrulanaColors.successGreen,
        'redact' => const Color(0xFFE0C85C),
        'deny' => const Color(0xFFF05858),
        _ => TrulanaColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x05FFFFFF))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 65,
            child: Text(
              time,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 11,
                color: TrulanaColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: _actionColor.withValues(alpha: 0.1),
            ),
            child: Text(
              action.toUpperCase(),
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 9,
                letterSpacing: 0.3,
                color: _actionColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 11,
                color: TrulanaColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
