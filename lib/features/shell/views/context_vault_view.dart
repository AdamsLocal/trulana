import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/features/engine/auto_redact_engine.dart';
import 'package:trulana/features/engine/context_vault.dart';
import 'package:trulana/features/engine/models/redaction_result.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

/// Category labels for the 6 vault entries (matches ContextVault order).
const _categories = ['routine', 'work', 'financial', 'health', 'travel', 'personal'];

/// Provider that runs every vault entry through the Auto-Redact Engine
/// at the user's current privacy level, producing display-ready text.
final _redactedVaultProvider =
    FutureProvider<List<_VaultDisplayEntry>>((ref) async {
  final config = await ref.watch(userConfigProvider.future);
  final level = config?.privacyLevel ?? PrivacyLevel.strict;

  final engine = AutoRedactEngine();
  final allRaw = ContextVault.instance.queryAll();

  final List<_VaultDisplayEntry> results = [];
  for (int i = 0; i < allRaw.length; i++) {
    final result = await engine.process(allRaw[i], level);
    results.add(_VaultDisplayEntry(
      category: i < _categories.length ? _categories[i] : 'general',
      date: _recentDate(i),
      preview: result.sanitizedText,
      redactionCount: result.totalRedactions,
    ));
  }
  return results;
});

/// Generates staggered recent dates for display.
String _recentDate(int index) {
  final now = DateTime.now();
  final d = now.subtract(Duration(days: index));
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}';
}

/// Context Vault view — shows real vault entries run through the
/// Auto-Redact Engine at the user's current privacy level.
class ContextVaultView extends ConsumerWidget {
  const ContextVaultView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultAsync = ref.watch(_redactedVaultProvider);

    return Column(
      children: [
        _header(context),
        Expanded(
          child: vaultAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: TrulanaColors.primaryCyan,
                strokeWidth: 2,
              ),
            ),
            error: (e, s) => Center(
              child: Text('Failed to load vault entries',
                  style: TextStyle(color: TrulanaColors.dangerRed)),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Text('Vault is empty',
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
                    _EntryTile(entry: entries[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF14142A))),
      ),
      child: Row(
        children: [
          const Text('Context Vault',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TrulanaColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Context entry creation coming in a future release.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2A8A84)),
                  color: TrulanaColors.primaryCyan.withValues(alpha: 0.1),
                ),
                child: Text('+ Add Entry',
                    style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 10, color: TrulanaColors.primaryCyan)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final _VaultDisplayEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color:
                      TrulanaColors.primaryCyan.withValues(alpha: 0.08),
                ),
                child: Text(entry.category.toUpperCase(),
                    style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.4,
                        color: TrulanaColors.primaryCyan)),
              ),
              const SizedBox(width: 8),
              Text(entry.date,
                  style: TrulanaTheme.monoStyle.copyWith(
                      fontSize: 10, color: TrulanaColors.textTertiary)),
              const Spacer(),
              if (entry.redactionCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: const Color(0xFFE0C85C).withValues(alpha: 0.1),
                  ),
                  child: Text('${entry.redactionCount} redacted',
                      style: TrulanaTheme.monoStyle.copyWith(
                          fontSize: 9, color: const Color(0xFFE0C85C))),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _RedactedText(text: entry.preview),
        ],
      ),
    );
  }
}

/// Renders text with [REDACTED_TAG] markers highlighted in cyan.
class _RedactedText extends StatelessWidget {
  const _RedactedText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final pattern = RegExp(r'\[([A-Z_ ]+)\]');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
              fontSize: 13, color: TrulanaColors.textSecondary, height: 1.5),
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
          child: Text(match.group(0)!,
              style: TrulanaTheme.monoStyle.copyWith(
                  fontSize: 11, color: TrulanaColors.primaryCyan)),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
            fontSize: 13, color: TrulanaColors.textSecondary, height: 1.5),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _VaultDisplayEntry {
  final String category;
  final String date;
  final String preview;
  final int redactionCount;

  const _VaultDisplayEntry({
    required this.category,
    required this.date,
    required this.preview,
    required this.redactionCount,
  });
}
