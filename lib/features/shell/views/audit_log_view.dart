import 'package:flutter/material.dart';

import 'package:trulana/core/theme/theme.dart';

/// Audit Log view matching the desktop HTML mockup.
///
/// Detailed event log with timestamps, color-coded action types,
/// and redaction details.
class AuditLogView extends StatelessWidget {
  const AuditLogView({super.key});

  static const List<_AuditDisplayEntry> _entries = [
    _AuditDisplayEntry(
      time: '14:32:01',
      action: 'redact',
      detail:
          'cursor-mcp "work schedule" \u2192 [PERSON] [EMAIL] [LOCATION] [TIME] stripped \u00b7 7 total',
    ),
    _AuditDisplayEntry(
      time: '14:28:44',
      action: 'auth',
      detail:
          'claude-desktop handshake \u00b7 scopes: [context.read] \u00b7 intent: "code assistance" \u00b7 ttl=900s',
    ),
    _AuditDisplayEntry(
      time: '14:22:10',
      action: 'deny',
      detail: 'unknown-app \u00b7 no bearer token \u00b7 rejected',
    ),
    _AuditDisplayEntry(
      time: '14:15:33',
      action: 'redact',
      detail:
          'cursor-mcp "morning routine" \u2192 [PERSON] [EMAIL] [PHONE] [LOCATION] \u00d72 [ORG] \u00b7 12 total',
    ),
    _AuditDisplayEntry(
      time: '14:15:30',
      action: 'auth',
      detail:
          'cursor-mcp handshake \u00b7 scopes: [context.read] \u00b7 intent: "IDE context" \u00b7 ttl=900s',
    ),
    _AuditDisplayEntry(
      time: '14:02:17',
      action: 'redact',
      detail:
          'demo-agent "financial info" \u2192 [CARD] [SSN] [AMOUNT] \u00d72 \u00b7 9 total',
    ),
    _AuditDisplayEntry(
      time: '13:58:01',
      action: 'auth',
      detail:
          'demo-agent handshake \u00b7 scopes: [context.read] \u00b7 ttl=900s',
    ),
    _AuditDisplayEntry(
      time: '13:45:00',
      action: 'query',
      detail:
          'server started \u00b7 vault unlocked \u00b7 REST bound to 127.0.0.1:8432',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: _entries.length,
            itemBuilder: (context, index) =>
                _AuditRow(entry: _entries[index]),
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
      child: Row(
        children: [
          const Text(
            'Audit Log',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: TrulanaColors.surfaceLight),
            ),
            child: Text(
              'Export',
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 10,
                color: TrulanaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final _AuditDisplayEntry entry;

  Color get _actionColor => switch (entry.action) {
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
              entry.time,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 11,
                color: TrulanaColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: _actionColor.withValues(alpha: 0.1),
            ),
            child: Text(
              entry.action.toUpperCase(),
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 9,
                letterSpacing: 0.3,
                color: _actionColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HighlightedDetail(text: entry.detail),
          ),
        ],
      ),
    );
  }
}

/// Renders audit detail text with [REDACTED] tags highlighted.
class _HighlightedDetail extends StatelessWidget {
  const _HighlightedDetail({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final pattern = RegExp(r'\[([A-Z]+)\]');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    final baseStyle = TrulanaTheme.monoStyle.copyWith(
      fontSize: 11,
      color: TrulanaColors.textSecondary,
      height: 1.5,
    );

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: TrulanaColors.primaryCyan.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            match.group(0)!,
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 10,
              color: TrulanaColors.primaryCyan,
            ),
          ),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _AuditDisplayEntry {
  final String time;
  final String action;
  final String detail;

  const _AuditDisplayEntry({
    required this.time,
    required this.action,
    required this.detail,
  });
}
