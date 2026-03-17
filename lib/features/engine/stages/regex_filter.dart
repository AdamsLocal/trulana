import 'package:trulana/features/engine/models/redaction_result.dart';

/// Stage 1 of the Auto-Redact pipeline: deterministic regex-based PII
/// stripping. Runs before NER so that obvious structured identifiers
/// (SSNs, emails, card numbers) are eliminated before the more expensive
/// entity recognition pass even sees the text.
class RegexFilter {
  RegexFilter._();
  static final RegexFilter instance = RegexFilter._();

  /// Ordered deliberately: SSNs first (shortest digit pattern) to avoid
  /// phone/card patterns accidentally consuming SSN-shaped substrings.
  static final List<_PiiPattern> _patterns = [
    _PiiPattern(
      type: 'ssn',
      regex: RegExp(r'\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b'),
      replacement: '[SSN REDACTED]',
    ),
    _PiiPattern(
      type: 'email',
      regex: RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      replacement: '[EMAIL REDACTED]',
    ),
    _PiiPattern(
      type: 'phone',
      regex: RegExp(r'(?<!\d)(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}(?!\d)'),
      replacement: '[PHONE REDACTED]',
    ),
    _PiiPattern(
      type: 'credit_card',
      regex: RegExp(r'\b(?:\d{4}[-\s]?){3}\d{1,4}\b|\b\d{4}[-\s]?\d{6}[-\s]?\d{5}\b'),
      replacement: '[CARD REDACTED]',
    ),
    _PiiPattern(
      type: 'ip',
      regex: RegExp(
        r'\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b'
        r'|'
        r'(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}',
      ),
      replacement: '[IP REDACTED]',
    ),
  ];

  /// Processes text through all regex patterns, returning sanitized text
  /// and the full event trail.
  ({String text, List<RedactionEvent> events}) process(String input) {
    if (input.isEmpty) return (text: input, events: <RedactionEvent>[]);

    var currentText = input;
    final allEvents = <RedactionEvent>[];

    for (final pattern in _patterns) {
      final result = _applyPattern(currentText, pattern);
      currentText = result.text;
      allEvents.addAll(result.events);
    }

    return (text: currentText, events: allEvents);
  }

  /// Applies a single pattern, building the output with a StringBuffer so
  /// event positions are tracked relative to the output string — not the
  /// input — which keeps indices meaningful for consumers.
  static ({String text, List<RedactionEvent> events}) _applyPattern(
    String input,
    _PiiPattern pattern,
  ) {
    final matches = pattern.regex.allMatches(input).toList();
    if (matches.isEmpty) return (text: input, events: <RedactionEvent>[]);

    final events = <RedactionEvent>[];
    final buffer = StringBuffer();
    var lastEnd = 0;

    for (final match in matches) {
      buffer.write(input.substring(lastEnd, match.start));
      final outputStart = buffer.length;
      buffer.write(pattern.replacement);

      events.add(RedactionEvent(
        type: pattern.type,
        original: match.group(0)!,
        replacement: pattern.replacement,
        startIndex: outputStart,
        endIndex: buffer.length,
      ));

      lastEnd = match.end;
    }

    buffer.write(input.substring(lastEnd));
    return (text: buffer.toString(), events: events);
  }
}

class _PiiPattern {
  final String type;
  final RegExp regex;
  final String replacement;

  _PiiPattern({
    required this.type,
    required this.regex,
    required this.replacement,
  });
}
