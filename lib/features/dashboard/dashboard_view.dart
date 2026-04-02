import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/services/preferences_service.dart';
import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/features/engine/context_vault.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

// ---------------------------------------------------------------------------
// Computed providers for dashboard stats
// ---------------------------------------------------------------------------

/// Live preference count from the database.
final _prefCountProvider = FutureProvider<int>((ref) async {
  final prefs = await PreferencesService.instance.getAllPreferences();
  return prefs.length;
});

/// Counts redaction events by type from audit log entries.
/// Parses the requestIntent text to extract redaction counts.
final _redactionStatsProvider =
    FutureProvider<_RedactionStats>((ref) async {
  final entries = await DatabaseHelper.instance.getAuditEntries(limit: 100);
  int pii = 0;
  int entity = 0;
  int general = 0;
  int blocked = 0;

  for (final entry in entries) {
    if (entry.actionTaken == AuditAction.blocked) {
      blocked++;
      continue;
    }
    if (entry.actionTaken == AuditAction.redacted) {
      final match = RegExp(r'(\d+) redaction').firstMatch(entry.requestIntent);
      if (match != null) {
        final count = int.tryParse(match.group(1)!) ?? 0;
        // Distribute across categories based on tag presence
        final text = entry.requestIntent;
        if (text.contains('[SSN]') ||
            text.contains('[CARD]') ||
            text.contains('[EMAIL]') ||
            text.contains('[PHONE]') ||
            text.contains('[IP]')) {
          pii += (count * 0.4).ceil();
        }
        if (text.contains('[PERSON]') ||
            text.contains('[ORG]') ||
            text.contains('[LOCATION]')) {
          entity += (count * 0.35).ceil();
        }
        general += (count * 0.25).ceil();
      }
    }
  }

  return _RedactionStats(
    pii: pii,
    entity: entity,
    general: general,
    blocked: blocked,
  );
});

class _RedactionStats {
  final int pii;
  final int entity;
  final int general;
  final int blocked;

  const _RedactionStats({
    required this.pii,
    required this.entity,
    required this.general,
    required this.blocked,
  });

  int get total => pii + entity + general + blocked;
}

// ---------------------------------------------------------------------------
// Dashboard view
// ---------------------------------------------------------------------------

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(userConfigProvider);
    final agentsAsync = ref.watch(agentsProvider);
    final auditAsync = ref.watch(auditProvider);
    final prefCountAsync = ref.watch(_prefCountProvider);
    final redactionAsync = ref.watch(_redactionStatsProvider);

    return Column(
      children: [
        _ContentHeader(
          title: 'Dashboard',
          trailing: configAsync.whenOrNull(
            data: (config) => config != null
                ? _PrivacyToggle(
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
                    Expanded(
                      child: _VaultStatusCard(
                        agentsAsync: agentsAsync,
                        prefCountAsync: prefCountAsync,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RedactionStatsCard(
                        statsAsync: redactionAsync,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Row 2: Connected agents + Recent activity
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ConnectedAgentsCard(agentsAsync: agentsAsync),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RecentActivityCard(auditAsync: auditAsync),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Full-width audit trail
                _AuditTrailCard(auditAsync: auditAsync),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF14142A))),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TrulanaColors.textPrimary)),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.level, required this.onChanged});

  final PrivacyLevel level;
  final ValueChanged<PrivacyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: PrivacyLevel.values.map((pl) {
          final isActive = pl == level;
          return GestureDetector(
            onTap: () => onChanged(pl),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? TrulanaColors.primaryCyan.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Text(
                pl.name[0].toUpperCase() + pl.name.substring(1),
                style: TrulanaTheme.monoStyle.copyWith(
                  fontSize: 9,
                  color: isActive
                      ? TrulanaColors.primaryCyan
                      : TrulanaColors.textTertiary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

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
                          color: (badgeColor ?? TrulanaColors.primaryCyan)
                              .withValues(alpha: 0.25)),
                    ),
                    child: Text(badge!,
                        style: TrulanaTheme.monoStyle.copyWith(
                            fontSize: 9,
                            color:
                                badgeColor ?? TrulanaColors.primaryCyan)),
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vault Status — live counts from providers
// ---------------------------------------------------------------------------

class _VaultStatusCard extends StatelessWidget {
  const _VaultStatusCard({
    required this.agentsAsync,
    required this.prefCountAsync,
  });

  final AsyncValue<List<AuthorizedAgent>> agentsAsync;
  final AsyncValue<int> prefCountAsync;

  @override
  Widget build(BuildContext context) {
    final vaultEntries = ContextVault.instance.entryCount;
    final prefCount =
        prefCountAsync.whenOrNull(data: (c) => c) ?? 0;
    final activeAgents = agentsAsync.whenOrNull(
            data: (list) =>
                list.where((a) => a.status == AgentStatus.active).length) ??
        0;

    return _DashCard(
      title: 'Vault Status',
      badge: 'encrypted',
      badgeColor: TrulanaColors.successGreen,
      child: Row(
        children: [
          _StatColumn(value: '$vaultEntries', label: 'Entries'),
          _StatColumn(value: '$prefCount', label: 'Preferences'),
          _StatColumn(value: '$activeAgents', label: 'Agents'),
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
          Text(value,
              style: TrulanaTheme.monoStyle.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: TrulanaColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: TrulanaColors.textTertiary)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Redaction Stats — computed from audit log
// ---------------------------------------------------------------------------

class _RedactionStatsCard extends StatelessWidget {
  const _RedactionStatsCard({required this.statsAsync});

  final AsyncValue<_RedactionStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.whenOrNull(data: (s) => s) ??
        const _RedactionStats(pii: 0, entity: 0, general: 0, blocked: 0);
    final total = stats.total;
    final maxVal = [stats.pii, stats.entity, stats.general, stats.blocked]
        .reduce(max);
    final denom = maxVal > 0 ? maxVal.toDouble() : 1.0;

    return _DashCard(
      title: 'Redactions Today',
      badge: '$total total',
      badgeColor: TrulanaColors.primaryCyan,
      child: Column(
        children: [
          _RedactionBar(
              label: 'PII',
              percent: stats.pii / denom,
              count: '${stats.pii}',
              color: const Color(0xFFF05858)),
          const SizedBox(height: 10),
          _RedactionBar(
              label: 'Entity',
              percent: stats.entity / denom,
              count: '${stats.entity}',
              color: TrulanaColors.primaryCyan),
          const SizedBox(height: 10),
          _RedactionBar(
              label: 'General',
              percent: stats.general / denom,
              count: '${stats.general}',
              color: const Color(0xFFE0C85C)),
          const SizedBox(height: 10),
          _RedactionBar(
              label: 'Blocked',
              percent: stats.blocked / denom,
              count: '${stats.blocked}',
              color: TrulanaColors.successGreen),
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
            child: Text(label,
                style: TrulanaTheme.monoStyle
                    .copyWith(fontSize: 10, color: TrulanaColors.textTertiary))),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
                color: TrulanaColors.primaryCyan.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 30,
            child: Text(count,
                textAlign: TextAlign.right,
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 10, color: TrulanaColors.textSecondary))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Connected Agents — live from agentsProvider
// ---------------------------------------------------------------------------

class _ConnectedAgentsCard extends StatelessWidget {
  const _ConnectedAgentsCard({required this.agentsAsync});

  final AsyncValue<List<AuthorizedAgent>> agentsAsync;

  @override
  Widget build(BuildContext context) {
    final agents = agentsAsync.valueOrNull ?? [];
    final activeCount =
        agents.where((a) => a.status == AgentStatus.active).length;

    return _DashCard(
      title: 'Connected Agents',
      badge: '$activeCount active',
      badgeColor: TrulanaColors.primaryCyan,
      child: agents.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No agents registered',
                  style: TextStyle(
                      fontSize: 12, color: TrulanaColors.textTertiary)),
            )
          : Column(
              children: agents.map((agent) {
                final isLive = agent.status == AgentStatus.active;
                final ttl = _formatTtl(agent);
                return _AgentRow(
                  name: agent.agentName,
                  scope: agent.grantedScopes.join(', '),
                  ttl: ttl,
                  isLive: isLive,
                );
              }).toList(),
            ),
    );
  }

  String _formatTtl(AuthorizedAgent agent) {
    if (agent.status != AgentStatus.active) return 'expired';
    final remaining = agent.expirationDate.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final min = remaining.inMinutes;
    final sec = remaining.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

// ---------------------------------------------------------------------------
// Recent Activity — top 4 from auditProvider
// ---------------------------------------------------------------------------

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.auditAsync});

  final AsyncValue<List<AuditLogEntry>> auditAsync;

  @override
  Widget build(BuildContext context) {
    final entries = auditAsync.valueOrNull ?? [];
    final recent = entries.take(4).toList();

    return _DashCard(
      title: 'Recent Activity',
      child: recent.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No activity yet',
                  style: TextStyle(
                      fontSize: 12, color: TrulanaColors.textTertiary)),
            )
          : Column(
              children: recent
                  .map((e) => _AuditEntryRow(entry: e, compact: true))
                  .toList(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audit Trail — full list from auditProvider
// ---------------------------------------------------------------------------

class _AuditTrailCard extends StatelessWidget {
  const _AuditTrailCard({required this.auditAsync});

  final AsyncValue<List<AuditLogEntry>> auditAsync;

  @override
  Widget build(BuildContext context) {
    final entries = auditAsync.valueOrNull ?? [];

    return _DashCard(
      title: 'Audit Trail',
      badge: 'encrypted \u00b7 tamper-evident',
      badgeColor: TrulanaColors.successGreen,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No audit entries',
                  style: TextStyle(
                      fontSize: 12, color: TrulanaColors.textTertiary)),
            )
          : Column(
              children: entries
                  .map((e) => _AuditEntryRow(entry: e, compact: false))
                  .toList(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared audit entry row — renders from real AuditLogEntry
// ---------------------------------------------------------------------------

class _AuditEntryRow extends StatelessWidget {
  const _AuditEntryRow({required this.entry, this.compact = false});

  final AuditLogEntry entry;
  final bool compact;

  String get _actionLabel => switch (entry.actionTaken) {
        AuditAction.approved => 'auth',
        AuditAction.blocked => 'deny',
        AuditAction.redacted => 'redact',
        AuditAction.negotiated => 'query',
      };

  Color get _actionColor => switch (entry.actionTaken) {
        AuditAction.approved => TrulanaColors.primaryCyan,
        AuditAction.blocked => const Color(0xFFF05858),
        AuditAction.redacted => const Color(0xFFE0C85C),
        AuditAction.negotiated => TrulanaColors.successGreen,
      };

  String get _timeStr {
    final t = entry.timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  String get _detail {
    if (compact) {
      return '${entry.agentId} \u00b7 ${_truncate(entry.requestIntent, 40)}';
    }
    return '${entry.agentId} ${entry.requestIntent}';
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x05FFFFFF)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 65,
              child: Text(_timeStr,
                  style: TrulanaTheme.monoStyle.copyWith(
                      fontSize: 11, color: TrulanaColors.textTertiary))),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _actionColor.withValues(alpha: 0.1)),
            child: Text(_actionLabel.toUpperCase(),
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.3,
                    color: _actionColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_detail,
                  style: TrulanaTheme.monoStyle.copyWith(
                      fontSize: 11,
                      color: TrulanaColors.textSecondary,
                      height: 1.5))),
        ],
      ),
    );
  }
}
