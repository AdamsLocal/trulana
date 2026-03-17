import 'package:trulana/features/engine/models/redaction_result.dart';
import 'package:trulana/features/engine/stages/ner_processor.dart';
import 'package:trulana/features/engine/stages/privacy_filter.dart';
import 'package:trulana/features/engine/stages/regex_filter.dart';
import 'package:trulana/models/models.dart';

/// Orchestrates the 3-stage Auto-Redact pipeline:
///   1. Regex filter  — deterministic PII stripping
///   2. NER processor — named-entity recognition (mock or on-device AI)
///   3. Privacy filter — level-dependent generalization & obfuscation
///
/// Dependencies are injectable so tests and future production code can
/// swap in alternative NER backends without touching the pipeline logic.
class AutoRedactEngine {
  final RegexFilter _regexFilter;
  final NerProcessor _nerProcessor;
  final PrivacyFilter _privacyFilter;

  AutoRedactEngine({
    RegexFilter? regexFilter,
    NerProcessor? nerProcessor,
    PrivacyFilter? privacyFilter,
  })  : _regexFilter = regexFilter ?? RegexFilter.instance,
        _nerProcessor = nerProcessor ?? MockNerProcessor(),
        _privacyFilter = privacyFilter ?? PrivacyFilter.instance;

  /// Runs the full 3-stage pipeline. The [level] determines how
  /// aggressively Stage 3 generalizes the already-sanitized text.
  Future<RedactionResult> process(
    String rawText,
    PrivacyLevel level,
  ) async {
    final regexResult = _regexFilter.process(rawText);

    final nerResult =
        await _nerProcessor.processEntities(regexResult.text);

    final privacyResult = _privacyFilter.apply(
      nerResult.processedText,
      level,
      [...regexResult.events, ...nerResult.events],
    );

    final allEvents = [
      ...regexResult.events,
      ...nerResult.events,
      ...privacyResult.events,
    ];

    return RedactionResult(
      sanitizedText: privacyResult.text,
      events: allEvents,
      appliedLevel: level,
    );
  }
}
