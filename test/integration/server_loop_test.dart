import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/core/services/auth_service.dart';
import 'package:trulana/core/services/context_query_service.dart';

/// End-to-end tests for the service loop:
///   token -> context query -> redact -> response
///
/// These run at the service layer (transport-agnostic), proving that
/// both REST and MCP paths produce identical outcomes since they
/// call the same service instances.
///
/// Security-model note: first-contact agents are persisted as
/// `AgentStatus.pending` and denied a token until the user approves
/// them from the Gatekeeper UI. The production auth flow therefore
/// requires a persisted `AgentStatus.active` record before a token
/// can be issued.
///
/// TEST-ENVIRONMENT LIMITATION: `DatabaseHelper` wraps `sqflite_sqlcipher`,
/// whose native plugin is not loaded inside `flutter test`. Every DB
/// call is silently swallowed by the service layer's error handling,
/// so there is no way to pre-insert an `active` agent from a test.
/// To keep coverage of the post-token security surface, tests that
/// need a valid token mint one directly via [TokenManager.generateToken]
/// with the exact scope list they want to assert on — bypassing the
/// DB-dependent `AuthService.requestAccess` path for those cases.
/// Pre-insert-based tests (e.g. "existing active agent's stored scopes
/// are used on re-auth") are covered under `Auth flow behavior` only to
/// the extent that they do not require DB read-back.
String _mintToken(String agentId, {required List<String> scopes}) {
  return TokenManager.instance.generateToken(
    agentId: agentId,
    scopes: scopes,
  );
}

void main() {
  group('Context query pipeline (with valid token)', () {
    test('token with context.read returns redacted context', () async {
      final String token = _mintToken(
        'loop-test-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'morning routine',
      );

      expect(query.isSuccess, isTrue);
      expect(query.redactionsApplied, greaterThan(0));
      expect(query.privacyLevel, isNotEmpty);
      expect(query.vaultHits, greaterThan(0));

      expect(query.sanitizedText, isNot(contains('michael.fit@gmail.com')));
      expect(query.sanitizedText, isNot(contains('415-555-0192')));
      expect(query.sanitizedText, isNot(contains('San Francisco')));
      expect(query.sanitizedText, contains('[EMAIL REDACTED]'));
      expect(query.sanitizedText, contains('[PHONE REDACTED]'));
      expect(query.sanitizedText, contains('[LOCATION]'));
    });

    test('work context is stripped of SSN and organization', () async {
      final String token = _mintToken(
        'ssn-test-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'work colleagues',
      );

      expect(query.isSuccess, isTrue);
      expect(query.sanitizedText, isNot(contains('478-33-9182')));
      expect(query.sanitizedText, contains('[SSN REDACTED]'));
      expect(query.sanitizedText, contains('[ORGANIZATION]'));
    });

    test('finance context is stripped of cards and amounts', () async {
      final String token = _mintToken(
        'fin-test-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'financial info',
      );

      expect(query.isSuccess, isTrue);
      expect(query.sanitizedText, isNot(contains('4111 1111 1111 1234')));
      expect(query.sanitizedText, isNot(contains('3782 822463 10005')));
      expect(query.sanitizedText, contains('[CARD REDACTED]'));
      expect(query.sanitizedText, contains('[AMOUNT GENERALIZED]'));
    });

    test('empty vault returns empty response without echoing the query',
        () async {
      final String token = _mintToken(
        'fallback-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'random weather question',
      );

      // Hardened contract: a query with no vault or preference matches
      // short-circuits with an empty sanitized response. The caller's
      // raw query is never reflected back through the redaction engine.
      expect(query.isSuccess, isTrue);
      expect(query.sanitizedText, '');
      expect(query.redactionsApplied, 0);
      expect(query.vaultHits, 0);
      expect(query.privacyLevel, isNotEmpty);
      expect(query.sanitizedText, isNot(contains('random weather question')));
    });
  });

  group('Auth rejection', () {
    test('missing fields returns 400', () async {
      final AuthResult result = await AuthService.instance.requestAccess(
        appId: null,
        appName: null,
        scopes: null,
        intent: null,
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 400);
    });

    test('empty app_id returns 400', () async {
      final AuthResult result = await AuthService.instance.requestAccess(
        appId: '',
        appName: 'Test',
        scopes: <String>['context.read'],
        intent: 'test',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 400);
    });

    test('empty scopes returns 400', () async {
      final AuthResult result = await AuthService.instance.requestAccess(
        appId: 'test',
        appName: 'Test',
        scopes: <String>[],
        intent: 'test',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 400);
    });

    test('first-contact agent is denied with 403 pending approval', () async {
      // No token is issued on first contact. Whether the pending record
      // is actually persisted depends on the DB layer (not verifiable in
      // `flutter test` without native sqflite_sqlcipher), but the
      // AuthResult contract is fully testable here.
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'first-contact-${DateTime.now().microsecondsSinceEpoch}',
        appName: 'First Contact',
        scopes: <String>['context.read'],
        intent: 'first contact',
      );

      expect(auth.isSuccess, isFalse);
      expect(auth.errorCode, 403);
      expect(auth.accessToken, isEmpty);
      expect(
        auth.errorMessage.toLowerCase(),
        contains('pending'),
      );
    });
  });

  group('Token validation', () {
    test('invalid token is rejected', () async {
      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: 'not-a-real-token',
        query: 'test',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 401);
    });

    test('empty query is rejected', () async {
      final String token = _mintToken(
        'query-val-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: '',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 400);
    });

    test('null query is rejected', () async {
      final String token = _mintToken(
        'null-query-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: null,
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 400);
    });
  });

  group('Token lifecycle', () {
    test('minted token can be used immediately', () async {
      final String token = _mintToken(
        'lifecycle-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'morning',
      );
      expect(result.isSuccess, isTrue);
    });

    test('revoked token is rejected', () async {
      final String token = _mintToken(
        'revoke-test-agent',
        scopes: <String>['context.read'],
      );

      TokenManager.instance.revokeToken(token);

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'morning',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 401);
    });

    test('per-agent revocation invalidates all tokens for that agent',
        () async {
      final String token1 = _mintToken(
        'multi-token-agent',
        scopes: <String>['context.read'],
      );
      final String token2 = _mintToken(
        'multi-token-agent',
        scopes: <String>['context.read'],
      );

      TokenManager.instance.revokeAgentTokens('multi-token-agent');

      final ContextQueryResult r1 =
          await ContextQueryService.instance.queryContext(
        accessToken: token1,
        query: 'test',
      );
      final ContextQueryResult r2 =
          await ContextQueryService.instance.queryContext(
        accessToken: token2,
        query: 'test',
      );

      expect(r1.isSuccess, isFalse);
      expect(r2.isSuccess, isFalse);
    });
  });

  group('Privacy level enforcement', () {
    test('strict level generalizes times and amounts', () async {
      final String token = _mintToken(
        'strict-agent',
        scopes: <String>['context.read'],
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'morning routine',
      );

      expect(result.isSuccess, isTrue);
      expect(result.privacyLevel, 'strict');
      expect(result.sanitizedText, isNot(contains('6:30 AM')));
      expect(result.sanitizedText, isNot(contains('7:15 AM')));
      expect(result.sanitizedText, contains('[TIME GENERALIZED]'));
    });
  });

  group('Scope enforcement', () {
    test('token without context.read scope cannot query context', () async {
      final String token = _mintToken(
        'scopeless-agent',
        scopes: const <String>[],
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'anything',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 403);
      expect(result.errorMessage, contains('context.read'));
    });

    test('token with unrelated scope cannot query context', () async {
      final String token = _mintToken(
        'monetize-only-agent',
        scopes: <String>['monetize.write'],
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'anything',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 403);
    });

    test('token with multiple scopes including context.read is accepted',
        () async {
      final String token = _mintToken(
        'multi-scope-agent',
        scopes: <String>['context.read', 'monetize.write'],
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: token,
        query: 'morning',
      );

      expect(result.isSuccess, isTrue);
    });
  });
}
