import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

/// Audit Log view — live from auditProvider.
class AuditLogView extends ConsumerWidget {
  const AuditLogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditProvider);

    return Column(
      children: [
        _header(),
        Expanded(
          child: auditAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: TrulanaColors.primaryCyan,
                strokeWidth: 2,
              ),
            ),
            error: (e, s) => Center(
              child: Text('Failed to load audit log',
                  style: TextStyle(color: TrulanaColors.dangerRed)),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Text('No audit entries yet',
                      style: TextStyle(
                          fontSize: 14,
                          color: TrulanaColors.textTertiary)),
                );
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                itemCount: entries.length,
                itemBuilder: (context, index) =>
                    _AuditRow(entry: entries[index]),
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
      child: Row(
        children: [
          const Text('Audit Log',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TrulanaColors.textPrimary)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: TrulanaColors.surfaceLight),
            ),
            child: Text('Export',
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 10, color: TrulanaColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditLogEntry entry;

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
          const SizedBox(width: 10),
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
            child: _HighlightedDetail(
              text: '${entry.agentId} ${entry.requestIntent}',
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders audit detail text with [REDACTED] tags highlighted in cyan.
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
            text: text.substring(lastEnd, match.start), style: baseStyle));
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
          child: Text(match.group(0)!,
              style: TrulanaTheme.monoStyle.copyWith(
                  fontSize: 10, color: TrulanaColors.primaryCyan)),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
          TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
