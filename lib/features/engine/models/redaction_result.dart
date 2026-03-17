import 'package:trulana/models/models.dart';

/// A single PII detection event capturing what was found, where, and how
/// it was neutralized. Immutable by design so events can safely accumulate
/// across pipeline stages without defensive copying.
class RedactionEvent {
  final String type;
  final String original;
  final String replacement;
  final int startIndex;
  final int endIndex;

  const RedactionEvent({
    required this.type,
    required this.original,
    required this.replacement,
    required this.startIndex,
    required this.endIndex,
  });
}

/// Aggregate output from the full 3-stage Auto-Redact pipeline.
/// Carries the sanitized text alongside a complete audit trail of
/// every redaction applied, enabling downstream logging without
/// ever needing to touch the raw input again.
class RedactionResult {
  final String sanitizedText;
  final List<RedactionEvent> events;
  final PrivacyLevel appliedLevel;

  const RedactionResult({
    required this.sanitizedText,
    required this.events,
    required this.appliedLevel,
  });

  bool get hadRedactions => events.isNotEmpty;
  int get totalRedactions => events.length;
}
