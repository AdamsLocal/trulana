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
                    Expanded(child: _VaultStatusCard(configAsync: configAsync)),
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

/// Privacy level toggle: Standard / Strict / Paranoid.
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

/// Vault status card with entry counts.
class _VaultStatusCard extends StatelessWidget {
  const _VaultStatusCard({required this.configAsync});

  final AsyncValue<UserConfig?> configAsync;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: 'Vault Status',
      badge: 'encrypted',
      badgeColor: TrulanaColors.successGreen,
      child: Row(
        children: [
          _StatColumn(value: '6', label: 'Entries'),
          _StatColumn(value: '12', label: 'Preferences'),
          _StatColumn(value: '2', label: 'Agents'),
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

/// Connected agents card with status dots.
class _ConnectedAgentsCard extends StatelessWidget {
  const _ConnectedAgentsCard({required this.agentsAsync});

  final AsyncValue<List<AuthorizedAgent>> agentsAsync;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: 'Connected Agents',
      badge: '2 active',
      badgeColor: TrulanaColors.primaryCyan,
      child: Column(
        children: const [
          _AgentRow(name: 'cursor-mcp', scope: 'context.read', ttl: '11:42', isLive: true),
          _AgentRow(name: 'claude-desktop', scope: 'context.read', ttl: '8:15', isLive: true),
          _AgentRow(name: 'demo-agent', scope: 'context.read', ttl: 'expired', isLive: false),
        ],
      ),
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
          _AuditEntry(time: '14:32:01', action: 'redact', detail: 'cursor-mcp \u00b7 7 redactions', isRedactHighlight: true),
          _AuditEntry(time: '14:31:58', action: 'query', detail: 'cursor-mcp \u00b7 "work schedule"'),
          _AuditEntry(time: '14:28:44', action: 'auth', detail: 'claude-desktop \u00b7 granted ttl=900s'),
          _AuditEntry(time: '14:22:10', action: 'deny', detail: 'unknown-app \u00b7 no valid token'),
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
      badge: 'encrypted \u00b7 tamper-evident',
      badgeColor: TrulanaColors.successGreen,
      child: Column(
        children: const [
          _AuditEntry(
            time: '14:32:01',
            action: 'redact',
            detail: 'cursor-mcp queried "work schedule" \u2192 [PERSON] [EMAIL] [LOCATION] stripped',
            isRedactHighlight: true,
          ),
          _AuditEntry(
            time: '14:28:44',
            action: 'auth',
            detail: 'claude-desktop handshake \u00b7 scopes: context.read \u00b7 token issued \u00b7 ttl=900s',
          ),
          _AuditEntry(
            time: '14:22:10',
            action: 'deny',
            detail: 'unknown-app attempted query without token \u00b7 request rejected',
          ),
          _AuditEntry(
            time: '14:15:33',
            action: 'query',
            detail: 'cursor-mcp queried "morning routine" \u2192 matched 1 vault entry \u00b7 12 redactions',
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
