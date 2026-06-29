import 'package:riverpod_annotation/riverpod_annotation.dart';

// This must match the filename exactly and stays relative to lib/providers/
part 'redaction_provider.g.dart';

/// Tracks the active redaction configurations and regex matching criteria.
@riverpod
class RedactionRules extends _$RedactionRules {
  @override
  Map<String, RegExp> build() {
    return {
      'email': RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      'ipv4': RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
    };
  }

  /// Dynamically add a new redaction rule from the app interface
  void addCustomPattern(String label, String regexPattern) {
    state = {
      ...state,
      label: RegExp(regexPattern),
    };
  }

  /// Remove a rule if explicit bypass authorization is granted
  void removePattern(String label) {
    final newState = Map<String, RegExp>.from(state)..remove(label);
    state = newState;
  }
}

/// The core functional engine that processes text against active rule structures.
@riverpod
String redactContext(RedactContextRef ref, String rawInput) {
  final rules = ref.watch(redactionRulesProvider);
  String processedText = rawInput;

  for (final entry in rules.entries) {
    processedText = processedText.replaceAllMapped(entry.value, (match) {
      return '[REDACTED:${entry.key.toUpperCase()}]';
    });
  }

  return processedText;
}
