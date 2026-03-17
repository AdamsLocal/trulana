import 'package:flutter_test/flutter_test.dart';
import 'package:sovereign/features/engine/stages/regex_filter.dart';

void main() {
  final filter = RegexFilter.instance;

  group('SSN detection', () {
    test('redacts standard SSN with dashes', () {
      final result = filter.process('My SSN is 123-45-6789.');
      expect(result.text, contains('[SSN REDACTED]'));
      expect(result.text, isNot(contains('123-45-6789')));
      expect(result.events.length, 1);
      expect(result.events.first.type, 'ssn');
    });

    test('redacts SSN without dashes', () {
      final result = filter.process('SSN: 123456789 end');
      expect(result.text, contains('[SSN REDACTED]'));
      expect(result.text, isNot(contains('123456789')));
    });

    test('redacts SSN with spaces', () {
      final result = filter.process('SSN 123 45 6789 here');
      expect(result.text, contains('[SSN REDACTED]'));
      expect(result.text, isNot(contains('123 45 6789')));
    });
  });

  group('Email detection', () {
    test('redacts standard email', () {
      final result = filter.process('Contact user@example.com for info.');
      expect(result.text, contains('[EMAIL REDACTED]'));
      expect(result.text, isNot(contains('user@example.com')));
      expect(result.events.first.type, 'email');
    });

    test('redacts email with subdomain', () {
      final result = filter.process('Email: admin@mail.corp.example.com');
      expect(result.text, contains('[EMAIL REDACTED]'));
      expect(result.text, isNot(contains('admin@mail.corp.example.com')));
    });

    test('redacts email with plus addressing', () {
      final result = filter.process('Send to user+newsletter@gmail.com');
      expect(result.text, contains('[EMAIL REDACTED]'));
      expect(result.text, isNot(contains('user+newsletter@gmail.com')));
    });
  });

  group('Phone detection', () {
    test('redacts phone with dashes', () {
      final result = filter.process('Call 555-123-4567 today.');
      expect(result.text, contains('[PHONE REDACTED]'));
      expect(result.text, isNot(contains('555-123-4567')));
      expect(result.events.first.type, 'phone');
    });

    test('redacts phone with parentheses', () {
      final result = filter.process('Phone: (555) 123-4567');
      expect(result.text, contains('[PHONE REDACTED]'));
      expect(result.text, isNot(contains('(555) 123-4567')));
    });

    test('redacts phone with country code', () {
      final result = filter.process('Reach me at +15551234567.');
      expect(result.text, contains('[PHONE REDACTED]'));
      expect(result.text, isNot(contains('+15551234567')));
    });

    test('redacts phone with dots', () {
      final result = filter.process('Fax: 555.123.4567');
      expect(result.text, contains('[PHONE REDACTED]'));
      expect(result.text, isNot(contains('555.123.4567')));
    });

    test('redacts phone with country code and dashes', () {
      final result = filter.process('Dial +1-555-123-4567 now');
      expect(result.text, contains('[PHONE REDACTED]'));
      expect(result.text, isNot(contains('+1-555-123-4567')));
    });
  });

  group('Credit card detection', () {
    test('redacts Visa 16-digit card with spaces', () {
      final result = filter.process('Card: 4111 1111 1111 1111');
      expect(result.text, contains('[CARD REDACTED]'));
      expect(result.text, isNot(contains('4111 1111 1111 1111')));
      expect(result.events.first.type, 'credit_card');
    });

    test('redacts Amex 15-digit card with spaces', () {
      final result = filter.process('Amex: 3782 822463 10005');
      expect(result.text, contains('[CARD REDACTED]'));
      expect(result.text, isNot(contains('3782 822463 10005')));
    });

    test('redacts card with dashes', () {
      final result = filter.process('Visa: 4111-1111-1111-1111');
      expect(result.text, contains('[CARD REDACTED]'));
      expect(result.text, isNot(contains('4111-1111-1111-1111')));
    });

    test('redacts card with no separators', () {
      final result = filter.process('Number: 4111111111111111');
      expect(result.text, contains('[CARD REDACTED]'));
      expect(result.text, isNot(contains('4111111111111111')));
    });
  });

  group('IP address detection', () {
    test('redacts standard IPv4', () {
      final result = filter.process('Server at 192.168.1.1 is down.');
      expect(result.text, contains('[IP REDACTED]'));
      expect(result.text, isNot(contains('192.168.1.1')));
      expect(result.events.first.type, 'ip');
    });

    test('redacts IPv4 edge case with max octets', () {
      final result = filter.process('Broadcast: 255.255.255.255');
      expect(result.text, contains('[IP REDACTED]'));
      expect(result.text, isNot(contains('255.255.255.255')));
    });

    test('redacts IPv4 loopback', () {
      final result = filter.process('Localhost is 127.0.0.1');
      expect(result.text, contains('[IP REDACTED]'));
      expect(result.text, isNot(contains('127.0.0.1')));
    });

    test('redacts full IPv6 address', () {
      final result = filter.process(
        'IPv6: 2001:0db8:85a3:0000:0000:8a2e:0370:7334',
      );
      expect(result.text, contains('[IP REDACTED]'));
      expect(
        result.text,
        isNot(contains('2001:0db8:85a3:0000:0000:8a2e:0370:7334')),
      );
    });
  });

  group('Multiple PII in one string', () {
    test('redacts email and phone in same text', () {
      final result = filter.process(
        'Email user@test.com or call 555-867-5309.',
      );
      expect(result.text, contains('[EMAIL REDACTED]'));
      expect(result.text, contains('[PHONE REDACTED]'));
      expect(result.events.length, 2);
    });

    test('redacts SSN, email, and IP together', () {
      final result = filter.process(
        'SSN 111-22-3333, email a@b.com, IP 10.0.0.1',
      );
      expect(result.text, contains('[SSN REDACTED]'));
      expect(result.text, contains('[EMAIL REDACTED]'));
      expect(result.text, contains('[IP REDACTED]'));
      expect(result.events.length, 3);
    });
  });

  group('No false positives', () {
    test('clean text passes through unchanged', () {
      const clean = 'The quick brown fox jumps over the lazy dog.';
      final result = filter.process(clean);
      expect(result.text, clean);
      expect(result.events, isEmpty);
    });

    test('short numbers are not flagged as PII', () {
      const text = 'I have 42 apples and 7 oranges.';
      final result = filter.process(text);
      expect(result.text, text);
      expect(result.events, isEmpty);
    });
  });

  group('Edge cases', () {
    test('empty string returns empty result', () {
      final result = filter.process('');
      expect(result.text, '');
      expect(result.events, isEmpty);
    });

    test('unicode text with embedded PII is handled', () {
      final result = filter.process(
        'Héllo wörld, email: naïve@example.com — done!',
      );
      expect(result.text, contains('[EMAIL REDACTED]'));
      expect(result.text, isNot(contains('naïve@example.com')));
      expect(result.text, contains('Héllo wörld'));
    });
  });

  group('Event metadata', () {
    test('events capture original text and replacement', () {
      final result = filter.process('SSN is 111-22-3333.');
      final event = result.events.first;
      expect(event.original, '111-22-3333');
      expect(event.replacement, '[SSN REDACTED]');
      expect(event.type, 'ssn');
      expect(event.startIndex, greaterThanOrEqualTo(0));
      expect(event.endIndex, greaterThan(event.startIndex));
    });
  });
}
