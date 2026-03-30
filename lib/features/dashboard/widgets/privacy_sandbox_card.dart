import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';
import 'package:trulana/features/engine/auto_redact_engine.dart';
import 'package:trulana/features/engine/context_vault.dart';
import 'package:trulana/features/engine/models/redaction_result.dart';
import 'package:trulana/core/services/preferences_service.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

// ── Query result model ─────────────────────────────────────────────────────────

@immutable
class _QueryResult {
  const _QueryResult({
    required this.sanitizedText,
    required this.privacyLevel,
    required this.redactionsApplied,
    required this.vaultHits,
  });

  final String sanitizedText;
  final PrivacyLevel privacyLevel;
  final int redactionsApplied;
  final int vaultHits;
}

// ── Preset queries ─────────────────────────────────────────────────────────────

const List<String> _presets = <String>[
  'coffee',
  'work',
  'commute',
  'health',
];

// ── PrivacySandboxCard ─────────────────────────────────────────────────────────

/// A native-app query sandbox that runs real queries through the local
/// vault → auto-redact pipeline and shows users exactly what an AI
/// agent receives: their data, stripped of PII.
///
/// Unlike the landing-page demo, this operates on the user's **real**
/// preferences (not pre-canned data), highlights every redacted token
/// inline, and links through to the [PreferencesScreen] where they can
/// manage what lives in their vault.
class PrivacySandboxCard extends ConsumerStatefulWidget {
  const PrivacySandboxCard({super.key});

  @override
  ConsumerState<PrivacySandboxCard> createState() => _PrivacySandboxCardState();
}

class _PrivacySandboxCardState extends ConsumerState<PrivacySandboxCard> {
  final TextEditingController _inputCtrl = TextEditingController();
  _QueryResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  // ── Query pipeline ───────────────────────────────────────────────────────────

  Future<void> _query(String input) async {
    input = input.trim();
    if (input.isEmpty || _busy) return;
    _inputCtrl.clear();

    setState(() {
      _busy = true;
      _result = null;
    });

    // Get the user's configured privacy level (default to strict).
    final PrivacyLevel level =
        ref.read(userConfigProvider).valueOrNull?.privacyLevel ??
            PrivacyLevel.strict;

    // Query vault + preferences directly — no token/auth required for the
    // sandbox because the data never leaves the device.
    final List<String> vaultHits = ContextVault.instance.query(input);
    final List<String> prefHits =
        await PreferencesService.instance.queryPreferences(input);

    final List<String> allHits = <String>[...prefHits, ...vaultHits];
    final String raw = allHits.isNotEmpty ? allHits.join(' ') : input;

    final RedactionResult redaction =
        await AutoRedactEngine().process(raw, level);

    setState(() {
      _result = _QueryResult(
        sanitizedText: redaction.sanitizedText,
        privacyLevel: level,
        redactionsApplied: redaction.totalRedactions,
        vaultHits: allHits.length,
      );
      _busy = false;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(context),
          const SizedBox(height: 14),
          _buildQueryRow(),
          const SizedBox(height: 10),
          _buildPresetChips(),
          if (_busy) ...<Widget>[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  color: TrulanaColors.primaryCyan,
                  strokeWidth: 2,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ] else if (_result != null) ...<Widget>[
            const SizedBox(height: 14),
            _buildResult(_result!),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.shield_outlined,
                    color: TrulanaColors.primaryCyan,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Privacy Sandbox',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TrulanaColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 26),
                child: Text(
                  'See exactly what AI agents receive from your vault.',
                  style: TextStyle(
                    fontSize: 11,
                    color: TrulanaColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/preferences'),
          child: Row(
            children: <Widget>[
              Text(
                'My vault',
                style: TextStyle(
                  fontSize: 11,
                  color: TrulanaColors.primaryCyan.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_ios,
                size: 10,
                color: TrulanaColors.primaryCyan.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQueryRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _inputCtrl,
            enabled: !_busy,
            style: const TextStyle(
              fontSize: 13,
              color: TrulanaColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Ask anything about your vault…',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onSubmitted: _query,
          ),
        ),
        const SizedBox(width: 10),
        TrulanaButton(
          label: 'Query',
          onPressed: _busy ? null : () => _query(_inputCtrl.text),
          icon: Icons.search_rounded,
        ),
      ],
    );
  }

  Widget _buildPresetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _presets
          .map(
            (String p) => _Chip(
              label: p,
              onTap: _busy ? null : () => _query(p),
            ),
          )
          .toList(),
    );
  }

  Widget _buildResult(_QueryResult result) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: TrulanaColors.glassBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildResultStats(result),
          const SizedBox(height: 10),
          _buildRedactedText(result.sanitizedText),
        ],
      ),
    );
  }

  Widget _buildResultStats(_QueryResult result) {
    return Row(
      children: <Widget>[
        _StatBadge(
          label: result.privacyLevel.name.toUpperCase(),
          color: TrulanaColors.primaryCyan,
        ),
        const SizedBox(width: 8),
        if (result.redactionsApplied > 0)
          _StatBadge(
            label: '${result.redactionsApplied} redacted',
            color: TrulanaColors.warningAmber,
          ),
        if (result.vaultHits == 0) ...<Widget>[
          const SizedBox(width: 8),
          _StatBadge(
            label: 'no vault match',
            color: TrulanaColors.textTertiary,
          ),
        ],
      ],
    );
  }

  /// Renders the sanitized text, highlighting redaction placeholders
  /// (e.g. `[EMAIL REDACTED]`) in amber so the privacy pipeline is
  /// visually obvious.
  Widget _buildRedactedText(String text) {
    final RegExp pattern =
        RegExp(r'\[[A-Z][A-Z\s]*(?:REDACTED|GENERALIZED)\]');
    final List<InlineSpan> spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: TrulanaColors.warningAmber,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: TrulanaColors.textSecondary,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
}

// ── Chip ───────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: TrulanaColors.primaryCyan
              .withValues(alpha: enabled ? 0.08 : 0.03),
          border: Border.all(
            color: TrulanaColors.primaryCyan
                .withValues(alpha: enabled ? 0.28 : 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: TrulanaColors.primaryCyan
                .withValues(alpha: enabled ? 1.0 : 0.35),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Stat badge ─────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
