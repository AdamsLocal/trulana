import 'package:flutter/material.dart';

import 'package:trulana/core/theme/theme.dart';

/// Context Vault view — shows vault entries with redacted PII markers.
///
/// Mirrors the desktop HTML mockup "Context Vault" sidebar view with
/// category tags, dates, and redacted text previews.
class ContextVaultView extends StatelessWidget {
  const ContextVaultView({super.key});

  static const List<_VaultDisplayEntry> _entries = [
    _VaultDisplayEntry(
      category: 'routine',
      date: 'Mar 28',
      preview:
          'Wakes up at [TIME], takes the Caltrain from [LOCATION] to [LOCATION]. '
          'Goes to [ORG] for a 45-min session, picks up coffee. '
          'Contact: [PERSON] at [EMAIL].',
    ),
    _VaultDisplayEntry(
      category: 'work',
      date: 'Mar 28',
      preview:
          'Works at [ORG] as a senior PM. Reports: [PERSON] ([EMAIL]) and '
          '[PERSON] ([EMAIL]). Weekly 1:1 with VP [PERSON] at [TIME]. '
          'Badge ID tied to [SSN].',
    ),
    _VaultDisplayEntry(
      category: 'financial',
      date: 'Mar 27',
      preview:
          'Primary checking at [ORG], card [CARD]. Monthly take-home [AMOUNT]. '
          'Rent [AMOUNT]/mo in [LOCATION].',
    ),
    _VaultDisplayEntry(
      category: 'health',
      date: 'Mar 27',
      preview:
          'PCP is Dr. [PERSON] at [ORG], [LOCATION]. [AGE], blood type O+. '
          'Rx atorvastatin. Portal: [EMAIL]. IP: [IP].',
    ),
    _VaultDisplayEntry(
      category: 'travel',
      date: 'Mar 26',
      preview:
          'Trip to [LOCATION]. Delta DL1847 from [LOCATION] at [TIME]. '
          'Hotel under [PERSON], [EMAIL]. SSN on file: [SSN].',
    ),
    _VaultDisplayEntry(
      category: 'personal',
      date: 'Mar 25',
      preview:
          'Lives with [PERSON] in [LOCATION]. [PERSON] works at [ORG]. '
          'Two kids at [LOCATION] Elementary. Savings goal: [AMOUNT].',
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
            itemBuilder: (context, index) => _EntryTile(entry: _entries[index]),
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
            'Context Vault',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.textPrimary,
            ),
          ),
          const Spacer(),
          _HeaderButton(label: '+ Add Entry', isPrimary: true),
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
        border: Border(bottom: BorderSide(color: Color(0x08FFFFFF))),
      ),
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
                  color: TrulanaColors.primaryCyan.withValues(alpha: 0.08),
                ),
                child: Text(
                  entry.category.toUpperCase(),
                  style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.4,
                    color: TrulanaColors.primaryCyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.date,
                style: TrulanaTheme.monoStyle.copyWith(
                  fontSize: 10,
                  color: TrulanaColors.textTertiary,
                ),
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
    final pattern = RegExp(r'\[([A-Z]+)\]');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 13,
            color: TrulanaColors.textSecondary,
            height: 1.5,
          ),
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
              fontSize: 11,
              color: TrulanaColors.primaryCyan,
            ),
          ),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 13,
          color: TrulanaColors.textSecondary,
          height: 1.5,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, this.isPrimary = false});

  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPrimary
              ? const Color(0xFF2A8A84)
              : TrulanaColors.surfaceLight,
        ),
        color: isPrimary
            ? TrulanaColors.primaryCyan.withValues(alpha: 0.1)
            : Colors.transparent,
      ),
      child: Text(
        label,
        style: TrulanaTheme.monoStyle.copyWith(
          fontSize: 10,
          color: isPrimary ? TrulanaColors.primaryCyan : TrulanaColors.textSecondary,
        ),
      ),
    );
  }
}

class _VaultDisplayEntry {
  final String category;
  final String date;
  final String preview;

  const _VaultDisplayEntry({
    required this.category,
    required this.date,
    required this.preview,
  });
}
