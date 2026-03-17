import 'package:flutter_test/flutter_test.dart';
import 'package:sovereign/features/engine/context_vault.dart';

void main() {
  final ContextVault vault = ContextVault.instance;

  group('Keyword matching', () {
    test('matches morning routine entry', () {
      final List<String> results = vault.query('morning routine');
      expect(results.length, 1);
      expect(results.first, contains('6:30 AM'));
      expect(results.first, contains('Equinox'));
    });

    test('matches work entry', () {
      final List<String> results = vault.query('work colleagues');
      expect(results.length, 1);
      expect(results.first, contains('Google'));
      expect(results.first, contains('Sarah'));
    });

    test('matches finance entry', () {
      final List<String> results = vault.query('financial info');
      expect(results.length, 1);
      expect(results.first, contains('Chase'));
      expect(results.first, contains('4111'));
    });

    test('matches health entry', () {
      final List<String> results = vault.query('doctor appointment');
      expect(results.length, 1);
      expect(results.first, contains('Kaiser'));
    });

    test('matches travel entry', () {
      final List<String> results = vault.query('upcoming trip');
      expect(results.length, 1);
      expect(results.first, contains('Nashville'));
    });

    test('matches family entry', () {
      final List<String> results = vault.query('family home');
      expect(results.length, 1);
      expect(results.first, contains('Lisa'));
    });
  });

  group('Multi-match', () {
    test('query matching multiple entries returns all', () {
      final List<String> results = vault.query('gym fitness');
      expect(results.length, greaterThanOrEqualTo(1));
      final String combined = results.join(' ');
      expect(combined, contains('Equinox'));
    });

    test('partial keyword match works', () {
      final List<String> results = vault.query('coffee');
      expect(results.length, 1);
      expect(results.first, contains('Philz'));
    });
  });

  group('No match', () {
    test('unrelated query returns empty', () {
      final List<String> results = vault.query('quantum physics lecture');
      expect(results, isEmpty);
    });

    test('empty string returns empty', () {
      expect(vault.query(''), isEmpty);
    });

    test('short tokens under 3 chars are filtered out', () {
      expect(vault.query('a b c'), isEmpty);
    });

    test('whitespace-only returns empty', () {
      expect(vault.query('   '), isEmpty);
    });
  });

  group('Case insensitivity', () {
    test('uppercase query matches lowercase keywords', () {
      final List<String> results = vault.query('MORNING ROUTINE');
      expect(results.length, 1);
      expect(results.first, contains('6:30 AM'));
    });

    test('mixed case query matches', () {
      final List<String> results = vault.query('Doctor Medical');
      expect(results.length, 1);
      expect(results.first, contains('Kaiser'));
    });
  });

  group('PII content verification', () {
    test('morning entry contains email for redaction testing', () {
      final List<String> results = vault.query('morning');
      expect(results.first, contains('michael.fit@gmail.com'));
    });

    test('work entry contains SSN for redaction testing', () {
      final List<String> results = vault.query('work');
      expect(results.first, contains('478-33-9182'));
    });

    test('finance entry contains credit cards for redaction testing', () {
      final List<String> results = vault.query('financial');
      expect(results.first, contains('4111 1111 1111 1234'));
      expect(results.first, contains('3782 822463 10005'));
    });

    test('health entry contains IP for redaction testing', () {
      final List<String> results = vault.query('doctor');
      expect(results.first, contains('192.168.1.42'));
    });

    test('travel entry contains phone for redaction testing', () {
      final List<String> results = vault.query('trip');
      expect(results.first, contains('+1-615-555-0123'));
    });

    test('family entry contains dollar amounts for redaction testing', () {
      final List<String> results = vault.query('family');
      expect(results.first, contains('\$50,000'));
    });
  });
}
