import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:trulana/core/services/auth_service.dart';
import 'package:trulana/core/services/context_query_service.dart';
import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';

// ── Terminal line model ────────────────────────────────────────────────────────

enum _LineKind { info, command, response, spacer }

@immutable
class _TermLine {
  const _TermLine(this.kind, this.text);

  final _LineKind kind;
  final String text;
}

// ── Guided-step definitions ────────────────────────────────────────────────────

const List<String> _stepQueries = <String>[
  '',                // step 0 – auth
  'morning routine', // step 1 – query
  'work colleagues', // step 2 – query
];

const List<String> _presets = <String>[
  'health',
  'finance',
  'travel',
  'family',
];

// ── VaultDemoCard ──────────────────────────────────────────────────────────────

/// Interactive terminal demo card that mirrors the landing-page walkthrough
/// but calls the real [AuthService] and [ContextQueryService] pipeline.
///
/// Three guided steps take the user through an auth request and two vault
/// queries, after which a free-form input lets them run arbitrary queries.
/// Redacted tokens like `[EMAIL REDACTED]` are highlighted in amber so the
/// privacy pipeline is visually obvious.
class VaultDemoCard extends StatefulWidget {
  const VaultDemoCard({super.key});

  @override
  State<VaultDemoCard> createState() => _VaultDemoCardState();
}

class _VaultDemoCardState extends State<VaultDemoCard> {
  final List<_TermLine> _lines = <_TermLine>[];
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  int _step = 0;
  bool _busy = false;
  String? _token;

  static const int _totalGuidedSteps = 3;
  static const JsonEncoder _json = JsonEncoder.withIndent('  ');

  @override
  void initState() {
    super.initState();
    _addInfo(
      'Step through the guided demo to see auth + redaction live, '
      'then run your own queries.',
    );
    _addSpacer();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  // ── Terminal helpers ─────────────────────────────────────────────────────────

  void _addInfo(String text) => _append(_TermLine(_LineKind.info, text));
  void _addCommand(String text) => _append(_TermLine(_LineKind.command, text));
  void _addResponse(String text) => _append(_TermLine(_LineKind.response, text));
  void _addSpacer() => _append(_TermLine(_LineKind.spacer, ''));

  void _append(_TermLine line) {
    setState(() => _lines.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Guided steps ─────────────────────────────────────────────────────────────

  Future<void> _runNextStep() async {
    if (_busy || _step >= _totalGuidedSteps) return;
    setState(() => _busy = true);

    if (_step == 0) {
      await _runAuthStep();
    } else {
      await _runQueryStep(_stepQueries[_step], stepLabel: 'Step ${_step + 1}');
    }

    setState(() {
      _step++;
      _busy = false;
    });

    if (_step >= _totalGuidedSteps) {
      _addInfo('Try it yourself — click a preset or type a query below.');
      _addSpacer();
    }
  }

  Future<void> _runAuthStep() async {
    _addInfo('Step 1 of 3: Authenticate a demo agent');
    _addSpacer();
    _addCommand(
      'curl -X POST localhost:8432/api/v1/auth/request \\\n'
      '  -H "Content-Type: application/json" \\\n'
      '  -d \'{"app_id":"demo-agent","app_name":"Demo Agent",\n'
      '       "scopes":["context.read"],"intent":"interactive demo"}\'',
    );

    final AuthResult result = await AuthService.instance.requestAccess(
      appId: 'demo-agent',
      appName: 'Demo Agent',
      scopes: <String>['context.read'],
      intent: 'interactive demo',
    );

    _addSpacer();

    if (result.isSuccess) {
      _token = result.accessToken;
      final String snip = result.accessToken.substring(0, 8);
      _addResponse(_json.convert(<String, Object>{
        'status': 'success',
        'access_token': '${snip}...',
        'expires_in': result.ttlSeconds,
        'granted_scopes': result.grantedScopes,
      }));
    } else {
      _addResponse(_json.convert(<String, Object>{
        'status': 'error',
        'code': result.errorCode,
        'message': result.errorMessage,
      }));
    }

    _addSpacer();
  }

  Future<void> _runQueryStep(String query, {required String stepLabel}) async {
    _addInfo('$stepLabel of $_totalGuidedSteps: Query "$query"');
    _addSpacer();

    final String snip =
        _token != null ? '${_token!.substring(0, 8)}...' : '<no-token>';
    _addCommand(
      'curl -X POST localhost:8432/api/v1/context/query \\\n'
      '  -H "Authorization: Bearer $snip" \\\n'
      '  -d \'{"query":"$query"}\'',
    );

    _addSpacer();

    if (_token == null) {
      _addResponse(
        _json.convert(<String, Object>{
          'status': 'error',
          'message': 'No token — run Step 1 first.',
        }),
      );
      _addSpacer();
      return;
    }

    final ContextQueryResult result =
        await ContextQueryService.instance.queryContext(
      accessToken: _token!,
      query: query,
    );

    _addResponse(_buildQueryResponse(result));
    _addSpacer();
  }

  // ── Free-form query ──────────────────────────────────────────────────────────

  Future<void> _runFreeQuery(String query) async {
    query = query.trim();
    if (query.isEmpty || _busy) return;
    _inputCtrl.clear();
    setState(() => _busy = true);

    final String snip =
        _token != null ? '${_token!.substring(0, 8)}...' : '<no-token>';
    _addCommand(
      'curl -X POST localhost:8432/api/v1/context/query \\\n'
      '  -H "Authorization: Bearer $snip" \\\n'
      '  -d \'{"query":"$query"}\'',
    );
    _addSpacer();

    if (_token == null) {
      _addResponse(
        _json.convert(<String, Object>{
          'status': 'error',
          'message': 'Complete the guided steps first to obtain a token.',
        }),
      );
      _addSpacer();
      setState(() => _busy = false);
      return;
    }

    final ContextQueryResult result =
        await ContextQueryService.instance.queryContext(
      accessToken: _token!,
      query: query,
    );

    _addResponse(_buildQueryResponse(result));
    _addSpacer();

    setState(() => _busy = false);
  }

  String _buildQueryResponse(ContextQueryResult result) {
    if (result.isSuccess) {
      return _json.convert(<String, Object>{
        'status': 'success',
        'data': result.sanitizedText,
        'privacy_level': result.privacyLevel,
        'redactions_applied': result.redactionsApplied,
        'vault_hits': result.vaultHits,
      });
    } else {
      return _json.convert(<String, Object>{
        'status': 'error',
        'code': result.errorCode,
        'message': result.errorMessage,
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool showFreeInput = _step >= _totalGuidedSteps;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 12),
          _buildTerminal(),
          const SizedBox(height: 12),
          if (!showFreeInput)
            _buildGuidedButton()
          else
            _buildFreeInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Icon(Icons.terminal, color: TrulanaColors.primaryCyan, size: 18),
        const SizedBox(width: 8),
        const Text(
          'Vault Demo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: TrulanaColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: TrulanaColors.primaryCyan.withValues(alpha: 0.4),
            ),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.primaryCyan,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerminal() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TrulanaColors.glassBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: _lines.isEmpty
          ? const SizedBox.shrink()
          : ListView.builder(
              controller: _scrollCtrl,
              itemCount: _lines.length,
              itemBuilder: (BuildContext context, int index) =>
                  _buildLine(_lines[index]),
            ),
    );
  }

  Widget _buildGuidedButton() {
    final String label;
    if (_busy) {
      label = 'Running…';
    } else if (_step == 0) {
      label = 'Step 1 of 3 — Authenticate';
    } else if (_step == 1) {
      label = 'Step 2 of 3 — Morning Routine';
    } else {
      label = 'Step 3 of 3 — Work Colleagues';
    }

    return TrulanaButton(
      label: label,
      onPressed: _busy ? null : _runNextStep,
      icon: Icons.play_arrow_rounded,
    );
  }

  Widget _buildFreeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Try it yourself',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: TrulanaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets
              .map(
                (String preset) => _PresetChip(
                  label: preset,
                  onTap: _busy ? null : () => _runFreeQuery(preset),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                enabled: !_busy,
                style: TrulanaTheme.monoStyle.copyWith(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Query your vault…',
                ),
                onSubmitted: _runFreeQuery,
              ),
            ),
            const SizedBox(width: 10),
            TrulanaButton(
              label: 'Query',
              onPressed: _busy
                  ? null
                  : () => _runFreeQuery(_inputCtrl.text),
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ],
    );
  }

  // ── Terminal line rendering ──────────────────────────────────────────────────

  Widget _buildLine(_TermLine line) {
    switch (line.kind) {
      case _LineKind.info:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '▸ ${line.text}',
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 11,
              color: TrulanaColors.primaryCyan.withValues(alpha: 0.8),
            ),
          ),
        );

      case _LineKind.command:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '$ ${line.text}',
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 11,
              color: TrulanaColors.textSecondary,
            ),
          ),
        );

      case _LineKind.response:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildResponseRichText(line.text),
        );

      case _LineKind.spacer:
        return const SizedBox(height: 6);
    }
  }

  /// Parses `[XXX REDACTED]` / `[XXX GENERALIZED]` tokens in the response JSON
  /// and renders them in amber so the redaction pipeline is visually obvious.
  Widget _buildResponseRichText(String text) {
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
        style: TrulanaTheme.monoStyle.copyWith(
          fontSize: 11,
          color: TrulanaColors.textPrimary.withValues(alpha: 0.85),
        ),
        children: spans,
      ),
    );
  }
}

// ── Preset chip ────────────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color color = enabled
        ? TrulanaColors.primaryCyan
        : TrulanaColors.primaryCyan.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: TrulanaColors.primaryCyan.withValues(alpha: enabled ? 0.08 : 0.03),
          border: Border.all(
            color: TrulanaColors.primaryCyan.withValues(alpha: enabled ? 0.3 : 0.12),
          ),
        ),
        child: Text(
          label,
          style: TrulanaTheme.monoStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
