import 'package:flutter_test/flutter_test.dart';
import 'package:sovereign/core/logging/safe_logger.dart';

/// Verifies SafeLogger never includes tokens, PII, query content,
/// DB paths, or encryption keys in its output. Tests by capturing
/// the formatted log lines through a test sink.
void main() {
  final List<String> captured = <String>[];

  setUp(() {
    captured.clear();
    SafeLogger.setTestSink((String line) => captured.add(line));
  });

  tearDown(() {
    SafeLogger.setTestSink(null);
  });

  group('Log hygiene', () {
    test('authGranted does not log token value', () {
      SafeLogger.authGranted(agentId: 'test-agent', ttlSeconds: 900);

      expect(captured.length, 1);
      expect(captured.first, contains('test-agent'));
      expect(captured.first, contains('900'));
      expect(captured.first, isNot(contains('Bearer')));
    });

    test('authGranted only contains agent ID and TTL', () {
      SafeLogger.authGranted(agentId: 'agent-x', ttlSeconds: 15);

      final String line = captured.first;
      expect(line, contains('agent=agent-x'));
      expect(line, contains('ttl=15s'));
      expect(line, contains('granted'));
    });

    test('authRejected does not log request body or intent', () {
      SafeLogger.authRejected(statusCode: 400, agentId: 'bad-agent');

      final String line = captured.first;
      expect(line, contains('400'));
      expect(line, contains('bad-agent'));
      expect(line, contains('rejected'));
      expect(line, isNot(contains('password')));
      expect(line, isNot(contains('secret')));
    });

    test('contextQuery does not log query text or response data', () {
      SafeLogger.contextQuery(
        agentId: 'query-agent',
        privacyLevel: 'strict',
        redactions: 7,
        vaultHits: 1,
      );

      final String line = captured.first;
      expect(line, contains('query-agent'));
      expect(line, contains('redactions=7'));
      expect(line, contains('level=strict'));
      expect(line, contains('vault_hits=1'));
      expect(line, isNot(contains('morning')));
      expect(line, isNot(contains('routine')));
      expect(line, isNot(contains('michael')));
      expect(line, isNot(contains('@')));
    });

    test('contextQueryRejected does not log query or token', () {
      SafeLogger.contextQueryRejected(statusCode: 401, agentId: 'bad');

      final String line = captured.first;
      expect(line, contains('401'));
      expect(line, contains('bad'));
      expect(line, isNot(contains('Bearer')));
      expect(line, isNot(contains('token')));
    });

    test('no log method accepts raw text, query content, or key material', () {
      SafeLogger.serverStart(8432);
      SafeLogger.serverStop();
      SafeLogger.mcpStart();
      SafeLogger.authGranted(agentId: 'a', ttlSeconds: 1);
      SafeLogger.authRejected(statusCode: 400);
      SafeLogger.contextQuery(
        agentId: 'a',
        privacyLevel: 'strict',
        redactions: 0,
        vaultHits: 0,
      );
      SafeLogger.contextQueryRejected(statusCode: 401);

      for (final String line in captured) {
        expect(line, isNot(contains('key=')));
        expect(line, isNot(contains('password')));
        expect(line, isNot(contains('sovereign.db')));
        expect(line, isNot(contains('.com')));
        expect(line, isNot(contains('SSN')));
      }
    });
  });
}
