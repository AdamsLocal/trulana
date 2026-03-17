import 'package:flutter_test/flutter_test.dart';
import 'package:sovereign/features/engine/models/redaction_result.dart';
import 'package:sovereign/features/engine/stages/privacy_filter.dart';
import 'package:sovereign/models/models.dart';

void main() {
  final filter = PrivacyFilter.instance;
  const noPriorEvents = <RedactionEvent>[];

  group('Standard level', () {
    test('text passes through unchanged', () {
      final result = filter.apply(
        'Meeting at 6:30 AM for \$500 budget review.',
        PrivacyLevel.standard,
        noPriorEvents,
      );
      expect(result.text, 'Meeting at 6:30 AM for \$500 budget review.');
      expect(result.events, isEmpty);
    });

    test('empty text stays empty', () {
      final result = filter.apply('', PrivacyLevel.standard, noPriorEvents);
      expect(result.text, '');
      expect(result.events, isEmpty);
    });
  });

  group('Strict level', () {
    test('generalizes time with AM/PM', () {
      final result = filter.apply(
        'Woke up at 6:30 AM today.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[TIME GENERALIZED]'));
      expect(result.text, isNot(contains('6:30 AM')));
    });

    test('generalizes time with pm lowercase', () {
      final result = filter.apply(
        'Lunch at 2:15 pm.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[TIME GENERALIZED]'));
      expect(result.text, isNot(contains('2:15 pm')));
    });

    test('generalizes noon reference', () {
      final result = filter.apply(
        'We meet at noon.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[TIME GENERALIZED]'));
      expect(result.text, isNot(contains('at noon')));
    });

    test('generalizes dollar amounts', () {
      final result = filter.apply(
        'Spent \$1,200 on supplies.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[AMOUNT GENERALIZED]'));
      expect(result.text, isNot(contains('\$1,200')));
    });

    test('generalizes euro amounts', () {
      final result = filter.apply(
        'Price is €500 total.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[AMOUNT GENERALIZED]'));
      expect(result.text, isNot(contains('€500')));
    });

    test('generalizes amounts with decimals', () {
      final result = filter.apply(
        'Coffee was \$42.50.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[AMOUNT GENERALIZED]'));
      expect(result.text, isNot(contains('\$42.50')));
    });

    test('redacts age references', () {
      final result = filter.apply(
        'She is age 32 and thriving.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[AGE REDACTED]'));
      expect(result.text, isNot(contains('age 32')));
    });

    test('redacts born-in references', () {
      final result = filter.apply(
        'He was born in 1994.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[AGE REDACTED]'));
      expect(result.text, isNot(contains('born in 1994')));
    });

    test('redacts years-old references', () {
      final result = filter.apply(
        'A 25 years old engineer.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[AGE REDACTED]'));
      expect(result.text, isNot(contains('25 years old')));
    });

    test('handles multiple strict patterns in one string', () {
      final result = filter.apply(
        'At 6:30 AM she spent \$100 on coffee.',
        PrivacyLevel.strict,
        noPriorEvents,
      );
      expect(result.text, contains('[TIME GENERALIZED]'));
      expect(result.text, contains('[AMOUNT GENERALIZED]'));
      expect(result.events.length, 2);
    });

    test('text with no strict-triggering content passes through', () {
      const text = 'Just a regular sentence.';
      final result = filter.apply(text, PrivacyLevel.strict, noPriorEvents);
      expect(result.text, text);
      expect(result.events, isEmpty);
    });
  });

  group('Paranoid level', () {
    test('applies all strict rules', () {
      final result = filter.apply(
        'At 6:30 AM she spent \$100.',
        PrivacyLevel.paranoid,
        noPriorEvents,
      );
      expect(result.text, contains('[TIME GENERALIZED]'));
      expect(result.text, contains('[AMOUNT GENERALIZED]'));
    });

    test('replaces remaining proper nouns with entity marker', () {
      final result = filter.apply(
        'She visited Philz Coffee downtown.',
        PrivacyLevel.paranoid,
        noPriorEvents,
      );
      expect(result.text, contains('[ENTITY]'));
      expect(result.text, isNot(contains('Philz Coffee')));
    });

    test('appends noise disclaimer', () {
      final result = filter.apply(
        'Some text here.',
        PrivacyLevel.paranoid,
        noPriorEvents,
      );
      expect(
        result.text,
        endsWith(
          '[Context may contain deliberate inaccuracies for privacy protection.]',
        ),
      );
    });

    test('does not replace sentence-initial capitalized words', () {
      final result = filter.apply(
        'Weather is nice today.',
        PrivacyLevel.paranoid,
        noPriorEvents,
      );
      expect(result.text, startsWith('Weather'));
    });

    test('does not alter existing redaction markers', () {
      final result = filter.apply(
        'Lives in [LOCATION] near [ORGANIZATION].',
        PrivacyLevel.paranoid,
        noPriorEvents,
      );
      expect(result.text, contains('[LOCATION]'));
      expect(result.text, contains('[ORGANIZATION]'));
    });
  });
}
