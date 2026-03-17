import 'package:sovereign/features/engine/models/redaction_result.dart';
import 'package:sovereign/models/models.dart';

/// Stage 3 of the Auto-Redact pipeline: applies privacy-level-specific
/// generalizations on top of the already-sanitized text from Stages 1 & 2.
/// Standard is a pass-through; each tier above it adds progressively
/// more aggressive obfuscation.
class PrivacyFilter {
  PrivacyFilter._();
  static final PrivacyFilter instance = PrivacyFilter._();

  static const String _noiseDisclaimer =
      ' [Context may contain deliberate inaccuracies for privacy protection.]';

  static final List<_FilterRule> _strictRules = [
    _FilterRule(
      type: 'time',
      pattern: RegExp(r'\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm|a\.m\.|p\.m\.)\b'),
      replacement: '[TIME GENERALIZED]',
    ),
    _FilterRule(
      type: 'time',
      pattern: RegExp(r'\bat\s+(?:noon|midnight)\b', caseSensitive: false),
      replacement: '[TIME GENERALIZED]',
    ),
    _FilterRule(
      type: 'currency',
      pattern: RegExp(r'[$€£¥]\s?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?'),
      replacement: '[AMOUNT GENERALIZED]',
    ),
    _FilterRule(
      type: 'age',
      pattern: RegExp(r'\bage(?:d)?\s+\d{1,3}\b'),
      replacement: '[AGE REDACTED]',
    ),
    _FilterRule(
      type: 'age',
      pattern: RegExp(r'\bborn\s+in\s+\d{4}\b'),
      replacement: '[AGE REDACTED]',
    ),
    _FilterRule(
      type: 'age',
      pattern: RegExp(r'\b\d{1,3}\s+years?\s+old\b'),
      replacement: '[AGE REDACTED]',
    ),
  ];

  /// Paranoid-only: catches remaining proper nouns that the mock NER missed.
  /// Lookbehind requires a lowercase letter + space before the capitalized
  /// sequence, which naturally skips sentence-initial words and text inside
  /// redaction brackets like [ORGANIZATION].
  static final _properNounPattern =
      RegExp(r'(?<=[a-z]\s)([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)');

  ({String text, List<RedactionEvent> events}) apply(
    String input,
    PrivacyLevel level,
    List<RedactionEvent> priorEvents,
  ) {
    return switch (level) {
      PrivacyLevel.standard => (text: input, events: <RedactionEvent>[]),
      PrivacyLevel.strict => _applyStrict(input),
      PrivacyLevel.paranoid => _applyParanoid(input),
    };
  }

  ({String text, List<RedactionEvent> events}) _applyStrict(String input) {
    var currentText = input;
    final allEvents = <RedactionEvent>[];

    for (final rule in _strictRules) {
      final result = _applyRule(currentText, rule);
      currentText = result.text;
      allEvents.addAll(result.events);
    }

    return (text: currentText, events: allEvents);
  }

  ({String text, List<RedactionEvent> events}) _applyParanoid(String input) {
    final strict = _applyStrict(input);
    var currentText = strict.text;
    final allEvents = [...strict.events];

    final nounResult = _applyRule(
      currentText,
      _FilterRule(
        type: 'noun',
        pattern: _properNounPattern,
        replacement: '[ENTITY]',
      ),
    );
    currentText = nounResult.text;
    allEvents.addAll(nounResult.events);

    currentText += _noiseDisclaimer;

    return (text: currentText, events: allEvents);
  }

  static ({String text, List<RedactionEvent> events}) _applyRule(
    String input,
    _FilterRule rule,
  ) {
    final matches = rule.pattern.allMatches(input).toList();
    if (matches.isEmpty) return (text: input, events: <RedactionEvent>[]);

    final events = <RedactionEvent>[];
    final buffer = StringBuffer();
    var lastEnd = 0;

    for (final match in matches) {
      buffer.write(input.substring(lastEnd, match.start));
      final outputStart = buffer.length;
      buffer.write(rule.replacement);

      events.add(RedactionEvent(
        type: rule.type,
        original: match.group(0)!,
        replacement: rule.replacement,
        startIndex: outputStart,
        endIndex: buffer.length,
      ));

      lastEnd = match.end;
    }

    buffer.write(input.substring(lastEnd));
    return (text: buffer.toString(), events: events);
  }
}

class _FilterRule {
  final String type;
  final RegExp pattern;
  final String replacement;

  _FilterRule({
    required this.type,
    required this.pattern,
    required this.replacement,
  });
}
