import 'package:trulana/features/engine/models/redaction_result.dart';

/// Stage 2 result — kept separate from RedactionResult so individual
/// stages can evolve their return shapes independently.
class NerResult {
  final String processedText;
  final List<RedactionEvent> events;

  const NerResult({
    required this.processedText,
    required this.events,
  });
}

/// The contract for NER processing — implementations can range from
/// simple keyword matching (mock) to on-device llama.cpp inference.
/// Expressed as an abstract class rather than a typedef so future
/// implementations can carry state (model handles, warm caches).
abstract class NerProcessor {
  Future<NerResult> processEntities(String text);
}

/// Mock NER for MVP — uses keyword dictionaries to identify common
/// person names, city names, and organization names. Designed to be
/// swapped out for [LlamaCppNerProcessor] once the on-device model
/// pipeline is stable.
class MockNerProcessor implements NerProcessor {
  static const List<String> _commonFirstNames = [
    'John', 'Jane', 'Michael', 'Sarah', 'David', 'Emily',
    'Robert', 'Maria', 'James', 'Jennifer', 'William', 'Jessica',
    'Richard', 'Lisa', 'Daniel', 'Amanda',
  ];

  static const List<String> _commonCities = [
    'New York', 'Los Angeles', 'Chicago', 'San Francisco',
    'Seattle', 'Austin', 'Boston', 'Denver', 'Miami', 'Portland',
    'Nashville', 'Atlanta', 'Dallas', 'Phoenix', 'Philadelphia',
    'Pleasanton',
  ];

  static const List<String> _commonOrgs = [
    'Google', 'Apple', 'Microsoft', 'Amazon', 'Meta',
    'Netflix', 'Spotify', 'Uber', 'Nike', 'Equinox',
  ];

  /// Patterns are built once and reused. Entries within each category
  /// are sorted longest-first so multi-word entities like
  /// "San Francisco" are matched before a hypothetical "San".
  static final List<_EntityCategory> _categories = [
    _EntityCategory(
      type: 'name',
      replacement: '[PERSON]',
      pattern: _buildPattern(_commonFirstNames),
    ),
    _EntityCategory(
      type: 'location',
      replacement: '[LOCATION]',
      pattern: _buildPattern(_commonCities),
    ),
    _EntityCategory(
      type: 'organization',
      replacement: '[ORGANIZATION]',
      pattern: _buildPattern(_commonOrgs),
    ),
  ];

  static RegExp _buildPattern(List<String> entries) {
    final sorted = [...entries]..sort((a, b) => b.length.compareTo(a.length));
    final escaped = sorted.map(RegExp.escape).join('|');
    return RegExp('\\b(?:$escaped)\\b');
  }

  @override
  Future<NerResult> processEntities(String text) async {
    var currentText = text;
    final allEvents = <RedactionEvent>[];

    for (final category in _categories) {
      final result = _applyCategory(currentText, category);
      currentText = result.text;
      allEvents.addAll(result.events);
    }

    return NerResult(processedText: currentText, events: allEvents);
  }

  static ({String text, List<RedactionEvent> events}) _applyCategory(
    String input,
    _EntityCategory category,
  ) {
    final matches = category.pattern.allMatches(input).toList();
    if (matches.isEmpty) return (text: input, events: <RedactionEvent>[]);

    final events = <RedactionEvent>[];
    final buffer = StringBuffer();
    var lastEnd = 0;

    for (final match in matches) {
      buffer.write(input.substring(lastEnd, match.start));
      final outputStart = buffer.length;
      buffer.write(category.replacement);

      events.add(RedactionEvent(
        type: category.type,
        original: match.group(0)!,
        replacement: category.replacement,
        startIndex: outputStart,
        endIndex: buffer.length,
      ));

      lastEnd = match.end;
    }

    buffer.write(input.substring(lastEnd));
    return (text: buffer.toString(), events: events);
  }
}

class _EntityCategory {
  final String type;
  final String replacement;
  final RegExp pattern;

  _EntityCategory({
    required this.type,
    required this.replacement,
    required this.pattern,
  });
}

// Placeholder for future on-device AI implementations:
// class LlamaCppNerProcessor implements NerProcessor { ... }
// class AiCoreNerProcessor implements NerProcessor { ... }
