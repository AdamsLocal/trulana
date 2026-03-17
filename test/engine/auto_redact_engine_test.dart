import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/features/engine/auto_redact_engine.dart';
import 'package:trulana/models/models.dart';

void main() {
  late AutoRedactEngine engine;

  setUp(() {
    engine = AutoRedactEngine();
  });

  group('Standard level end-to-end', () {
    test('strips regex PII and NER entities only', () async {
      final result = await engine.process(
        'Email john@acme.com, I live in Seattle.',
        PrivacyLevel.standard,
      );
      expect(result.sanitizedText, contains('[EMAIL REDACTED]'));
      expect(result.sanitizedText, isNot(contains('john@acme.com')));
      expect(result.sanitizedText, isNot(contains('Seattle')));
      expect(result.appliedLevel, PrivacyLevel.standard);
      expect(result.hadRedactions, isTrue);
    });

    test('clean text produces no events at standard level', () async {
      final result = await engine.process(
        'The weather is pleasant.',
        PrivacyLevel.standard,
      );
      expect(result.sanitizedText, 'The weather is pleasant.');
      expect(result.hadRedactions, isFalse);
      expect(result.totalRedactions, 0);
    });
  });

  group('Strict level end-to-end', () {
    test('applies regex, NER, and time/amount generalization', () async {
      final result = await engine.process(
        'John paid \$50 at 3:00 PM in Boston.',
        PrivacyLevel.strict,
      );
      expect(result.sanitizedText, isNot(contains('John')));
      expect(result.sanitizedText, isNot(contains('\$50')));
      expect(result.sanitizedText, isNot(contains('3:00 PM')));
      expect(result.sanitizedText, isNot(contains('Boston')));
      expect(result.sanitizedText, contains('[PERSON]'));
      expect(result.sanitizedText, contains('[AMOUNT GENERALIZED]'));
      expect(result.sanitizedText, contains('[TIME GENERALIZED]'));
      expect(result.sanitizedText, contains('[LOCATION]'));
    });
  });

  group('Paranoid level end-to-end', () {
    test('applies all stages plus noise disclaimer', () async {
      final result = await engine.process(
        'Sarah emailed sarah@work.com from Denver at 9:00 AM.',
        PrivacyLevel.paranoid,
      );
      expect(result.sanitizedText, isNot(contains('Sarah')));
      expect(result.sanitizedText, isNot(contains('sarah@work.com')));
      expect(result.sanitizedText, isNot(contains('Denver')));
      expect(result.sanitizedText, isNot(contains('9:00 AM')));
      expect(
        result.sanitizedText,
        contains(
          '[Context may contain deliberate inaccuracies for privacy protection.]',
        ),
      );
    });
  });

  group('Multiple PII types in one string', () {
    test('handles SSN, phone, and email together', () async {
      final result = await engine.process(
        'SSN 123-45-6789, call 555-867-5309, email x@y.com.',
        PrivacyLevel.standard,
      );
      expect(result.sanitizedText, contains('[SSN REDACTED]'));
      expect(result.sanitizedText, contains('[PHONE REDACTED]'));
      expect(result.sanitizedText, contains('[EMAIL REDACTED]'));
      expect(result.totalRedactions, greaterThanOrEqualTo(3));
    });
  });

  group('Clean text', () {
    test('text with no PII passes through at all levels', () async {
      const clean = 'Today is a good day for a walk.';

      for (final level in PrivacyLevel.values) {
        final result = await engine.process(clean, level);
        if (level == PrivacyLevel.paranoid) {
          expect(
            result.sanitizedText,
            contains(
              '[Context may contain deliberate inaccuracies for privacy protection.]',
            ),
          );
        } else {
          expect(result.sanitizedText, clean);
        }
      }
    });
  });

  group('PRD example scenario', () {
    const prdInput =
        'User wakes up at 6:30 AM, goes to Equinox in San Francisco, '
        'and buys Philz Coffee.';

    test('standard level: masks NER entities, preserves context', () async {
      final result = await engine.process(prdInput, PrivacyLevel.standard);

      expect(result.sanitizedText, contains('[ORGANIZATION]'));
      expect(result.sanitizedText, contains('[LOCATION]'));
      expect(result.sanitizedText, isNot(contains('Equinox')));
      expect(result.sanitizedText, isNot(contains('San Francisco')));

      expect(result.sanitizedText, contains('6:30 AM'));
      expect(result.sanitizedText, contains('Philz Coffee'));
      expect(result.totalRedactions, 2);
    });

    test('strict level: additionally generalizes time', () async {
      final result = await engine.process(prdInput, PrivacyLevel.strict);

      expect(result.sanitizedText, contains('[ORGANIZATION]'));
      expect(result.sanitizedText, contains('[LOCATION]'));
      expect(result.sanitizedText, contains('[TIME GENERALIZED]'));
      expect(result.sanitizedText, isNot(contains('6:30 AM')));
      expect(result.sanitizedText, isNot(contains('Equinox')));
      expect(result.sanitizedText, isNot(contains('San Francisco')));

      expect(result.sanitizedText, contains('Philz Coffee'));
      expect(result.totalRedactions, 3);
    });

    test('paranoid level: obfuscates everything and adds noise', () async {
      final result = await engine.process(prdInput, PrivacyLevel.paranoid);

      expect(result.sanitizedText, contains('[ORGANIZATION]'));
      expect(result.sanitizedText, contains('[LOCATION]'));
      expect(result.sanitizedText, contains('[TIME GENERALIZED]'));
      expect(result.sanitizedText, contains('[ENTITY]'));
      expect(result.sanitizedText, isNot(contains('6:30 AM')));
      expect(result.sanitizedText, isNot(contains('Equinox')));
      expect(result.sanitizedText, isNot(contains('San Francisco')));
      expect(result.sanitizedText, isNot(contains('Philz Coffee')));
      expect(
        result.sanitizedText,
        contains(
          '[Context may contain deliberate inaccuracies for privacy protection.]',
        ),
      );
      expect(result.totalRedactions, 4);
    });
  });
}
