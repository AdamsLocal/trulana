import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/features/engine/stages/ner_processor.dart';

void main() {
  late MockNerProcessor processor;

  setUp(() {
    processor = MockNerProcessor();
  });

  group('Name detection', () {
    test('detects common first name', () async {
      final result = await processor.processEntities('I spoke with John today.');
      expect(result.processedText, contains('[PERSON]'));
      expect(result.processedText, isNot(contains('John')));
      expect(result.events.first.type, 'name');
      expect(result.events.first.original, 'John');
    });

    test('detects multiple names', () async {
      final result = await processor.processEntities(
        'Sarah and Michael went to lunch.',
      );
      expect(result.processedText, contains('[PERSON] and [PERSON]'));
      expect(result.events.length, 2);
    });

    test('detects name at start of sentence', () async {
      final result = await processor.processEntities('Emily is here.');
      expect(result.processedText, startsWith('[PERSON]'));
    });

    test('detects name at end of sentence', () async {
      final result = await processor.processEntities('I met with Lisa');
      expect(result.processedText, endsWith('[PERSON]'));
    });
  });

  group('City detection', () {
    test('detects single-word city', () async {
      final result = await processor.processEntities('I live in Seattle.');
      expect(result.processedText, contains('[LOCATION]'));
      expect(result.processedText, isNot(contains('Seattle')));
      expect(result.events.first.type, 'location');
    });

    test('detects multi-word city name', () async {
      final result = await processor.processEntities(
        'Flying to San Francisco tomorrow.',
      );
      expect(result.processedText, contains('[LOCATION]'));
      expect(result.processedText, isNot(contains('San Francisco')));
      expect(result.events.first.original, 'San Francisco');
    });

    test('detects multiple cities', () async {
      final result = await processor.processEntities(
        'Moved from Boston to Denver.',
      );
      expect(result.events.length, 2);
      expect(result.processedText, contains('from [LOCATION] to [LOCATION]'));
    });
  });

  group('Organization detection', () {
    test('detects organization name', () async {
      final result = await processor.processEntities('I work at Google.');
      expect(result.processedText, contains('[ORGANIZATION]'));
      expect(result.processedText, isNot(contains('Google')));
      expect(result.events.first.type, 'organization');
    });

    test('detects multiple organizations', () async {
      final result = await processor.processEntities(
        'Comparing Apple and Microsoft products.',
      );
      expect(result.events.length, 2);
      expect(
        result.processedText,
        contains('[ORGANIZATION] and [ORGANIZATION]'),
      );
    });
  });

  group('Case sensitivity', () {
    test('does not match lowercase version of a name', () async {
      final result = await processor.processEntities('the john doe protocol');
      expect(result.processedText, 'the john doe protocol');
      expect(result.events, isEmpty);
    });

    test('does not match all-uppercase version', () async {
      final result = await processor.processEntities('GOOGLE SEATTLE');
      expect(result.processedText, 'GOOGLE SEATTLE');
      expect(result.events, isEmpty);
    });
  });

  group('Partial match prevention', () {
    test('does not match name inside a longer word', () async {
      final result = await processor.processEntities(
        'Johnson visited the Appleton museum.',
      );
      expect(result.processedText, 'Johnson visited the Appleton museum.');
      expect(result.events, isEmpty);
    });

    test('does not match city inside compound word', () async {
      final result = await processor.processEntities(
        'The Seattleite drove a Porsche.',
      );
      expect(result.processedText, contains('Seattleite'));
      expect(result.events, isEmpty);
    });
  });

  group('Clean text', () {
    test('clean text passes through unchanged', () async {
      const clean = 'The weather is nice today.';
      final result = await processor.processEntities(clean);
      expect(result.processedText, clean);
      expect(result.events, isEmpty);
    });

    test('empty text passes through unchanged', () async {
      final result = await processor.processEntities('');
      expect(result.processedText, '');
      expect(result.events, isEmpty);
    });
  });

  group('Mixed entity types', () {
    test('detects name, city, and org in same text', () async {
      final result = await processor.processEntities(
        'David works at Uber in Austin.',
      );
      expect(result.processedText, isNot(contains('David')));
      expect(result.processedText, isNot(contains('Uber')));
      expect(result.processedText, isNot(contains('Austin')));
      expect(result.events.length, 3);
    });
  });
}
