import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/models/models.dart';

void main() {
  group('Preference model', () {
    test('roundtrips through toMap/fromMap', () {
      final Preference pref = Preference(
        id: 'test-id',
        key: 'preferred_coffee',
        value: 'Philz',
        tags: <String>['routine', 'personal'],
        createdAt: DateTime(2026, 3, 18),
        updatedAt: DateTime(2026, 3, 18),
      );

      final Map<String, dynamic> map = pref.toMap();
      final Preference restored = Preference.fromMap(map);

      expect(restored.id, pref.id);
      expect(restored.key, pref.key);
      expect(restored.value, pref.value);
      expect(restored.tags, pref.tags);
      expect(restored.createdAt, pref.createdAt);
      expect(restored.updatedAt, pref.updatedAt);
    });

    test('handles null tags', () {
      final Map<String, dynamic> map = <String, dynamic>{
        'id': 'test-id',
        'key': 'test_key',
        'value': 'test_value',
        'tags': null,
        'created_at': '2026-03-18T00:00:00.000',
        'updated_at': '2026-03-18T00:00:00.000',
      };

      final Preference pref = Preference.fromMap(map);
      expect(pref.tags, isEmpty);
    });

    test('handles empty tags string', () {
      final Map<String, dynamic> map = <String, dynamic>{
        'id': 'test-id',
        'key': 'test_key',
        'value': 'test_value',
        'tags': '',
        'created_at': '2026-03-18T00:00:00.000',
        'updated_at': '2026-03-18T00:00:00.000',
      };

      final Preference pref = Preference.fromMap(map);
      expect(pref.tags, isEmpty);
    });

    test('serializes tags as JSON array', () {
      final Preference pref = Preference(
        id: 'x',
        key: 'k',
        value: 'v',
        tags: <String>['work', 'routine'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final Map<String, dynamic> map = pref.toMap();
      expect(map['tags'], '["work","routine"]');
    });

    test('null tags serializes as null', () {
      final Preference pref = Preference(
        id: 'x',
        key: 'k',
        value: 'v',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final Map<String, dynamic> map = pref.toMap();
      expect(map['tags'], isNull);
    });

    test('equality works', () {
      final DateTime now = DateTime(2026, 3, 18);
      final Preference a = Preference(
        id: 'x', key: 'k', value: 'v',
        createdAt: now, updatedAt: now,
      );
      final Preference b = Preference(
        id: 'x', key: 'k', value: 'v',
        createdAt: now, updatedAt: now,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on different values', () {
      final DateTime now = DateTime(2026, 3, 18);
      final Preference a = Preference(
        id: 'x', key: 'k', value: 'v1',
        createdAt: now, updatedAt: now,
      );
      final Preference b = Preference(
        id: 'x', key: 'k', value: 'v2',
        createdAt: now, updatedAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('copyWith preserves fields', () {
      final DateTime now = DateTime(2026, 3, 18);
      final Preference original = Preference(
        id: 'x', key: 'k', value: 'v',
        tags: <String>['a'],
        createdAt: now, updatedAt: now,
      );

      final Preference updated = original.copyWith(value: 'new_v');
      expect(updated.key, 'k');
      expect(updated.value, 'new_v');
      expect(updated.tags, <String>['a']);
      expect(updated.id, 'x');
    });

    test('toString shows key only', () {
      final Preference pref = Preference(
        id: 'x', key: 'secret_key', value: 'secret_value',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      expect(pref.toString(), 'Preference(key: secret_key)');
      expect(pref.toString(), isNot(contains('secret_value')));
    });
  });

  group('Preference keyword matching logic', () {
    List<String> matchPreferences(String query, List<Preference> prefs) {
      if (query.isEmpty) return <String>[];
      final List<String> tokens = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((String t) => t.length > 2)
          .toList();
      if (tokens.isEmpty) return <String>[];

      final List<String> matches = <String>[];
      for (final Preference pref in prefs) {
        final String keyLower = pref.key.toLowerCase();
        final String valueLower = pref.value.toLowerCase();
        final bool hit = tokens.any((String t) =>
            keyLower.contains(t) || t.contains(keyLower) ||
            valueLower.contains(t) || t.contains(valueLower));
        if (hit) matches.add('User prefers ${pref.key}: ${pref.value}');
      }
      return matches;
    }

    final DateTime now = DateTime(2026, 3, 18);
    final List<Preference> testPrefs = <Preference>[
      Preference(id: '1', key: 'preferred_coffee', value: 'Philz', createdAt: now, updatedAt: now),
      Preference(id: '2', key: 'response_style', value: 'concise', createdAt: now, updatedAt: now),
      Preference(id: '3', key: 'commute', value: 'Caltrain from San Francisco', createdAt: now, updatedAt: now),
      Preference(id: '4', key: 'workout_time', value: '6:30 AM', createdAt: now, updatedAt: now),
      Preference(id: '5', key: 'work_style', value: 'deep focus mornings, meetings after 2 PM', createdAt: now, updatedAt: now),
    ];

    test('matches on key (coffee)', () {
      final List<String> results = matchPreferences('coffee', testPrefs);
      expect(results.length, 1);
      expect(results.first, contains('Philz'));
    });

    test('matches on value (caltrain)', () {
      final List<String> results = matchPreferences('caltrain', testPrefs);
      expect(results.length, 1);
      expect(results.first, contains('Caltrain'));
    });

    test('matches on value (concise)', () {
      final List<String> results = matchPreferences('concise response', testPrefs);
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results.any((String r) => r.contains('concise')), isTrue);
    });

    test('matches workout', () {
      final List<String> results = matchPreferences('workout', testPrefs);
      expect(results.length, 1);
      expect(results.first, contains('6:30 AM'));
    });

    test('no match returns empty', () {
      final List<String> results = matchPreferences('quantum physics', testPrefs);
      expect(results, isEmpty);
    });

    test('empty query returns empty', () {
      expect(matchPreferences('', testPrefs), isEmpty);
    });

    test('short tokens are filtered', () {
      expect(matchPreferences('a b c', testPrefs), isEmpty);
    });

    test('matched text includes key and value', () {
      final List<String> results = matchPreferences('coffee', testPrefs);
      expect(results.first, startsWith('User prefers preferred_coffee:'));
      expect(results.first, contains('Philz'));
    });
  });
}
