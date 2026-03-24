import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/models/models.dart';

const Uuid _uuid = Uuid();

/// Service for managing structured user preferences.
///
/// Preferences are key-value pairs stored in the encrypted local vault.
/// They are included in context queries alongside vault entries and go
/// through the same redaction pipeline. Values are never logged.
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Sets a preference. If the key already exists, updates the value
  /// and updated_at timestamp while preserving created_at.
  Future<void> setPreference(
    String key,
    String value, {
    List<String>? tags,
  }) async {
    final Preference? existing = await _db.getPreferenceByKey(key);
    final DateTime now = DateTime.now();

    final Preference pref = Preference(
      id: existing?.id ?? _uuid.v4(),
      key: key,
      value: value,
      tags: tags ?? existing?.tags ?? const <String>[],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _db.insertPreference(pref);

    SafeLogger.preferenceUpdated(key: key);

    final AuditLogEntry auditEntry = AuditLogEntry(
      logId: _uuid.v4(),
      agentId: 'system',
      requestIntent: 'Preference set: $key',
      actionTaken: AuditAction.approved,
      timestamp: now,
    );
    await _db.insertAuditEntry(auditEntry);
  }

  Future<Preference?> getPreference(String key) async {
    return _db.getPreferenceByKey(key);
  }

  Future<List<Preference>> getAllPreferences() async {
    return _db.getAllPreferences();
  }

  Future<void> deletePreference(String key) async {
    await _db.deletePreference(key);
    SafeLogger.preferenceDeleted(key: key);
  }

  /// Returns raw text for all preferences that match query tokens.
  /// Used by [ContextQueryService] to include preferences in responses.
  Future<List<String>> queryPreferences(String input) async {
    if (input.isEmpty) return const <String>[];

    final List<String> tokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String t) => t.length > 2)
        .toList();

    if (tokens.isEmpty) return const <String>[];

    final List<Preference> all = await _db.getAllPreferences();
    final List<String> matches = <String>[];

    for (final Preference pref in all) {
      final String keyLower = pref.key.toLowerCase();
      final String valueLower = pref.value.toLowerCase();

      final bool hit = tokens.any((String t) =>
          keyLower.contains(t) ||
          t.contains(keyLower) ||
          valueLower.contains(t) ||
          t.contains(valueLower));

      if (hit) {
        matches.add('User prefers ${pref.key}: ${pref.value}');
      }
    }

    return matches;
  }
}
