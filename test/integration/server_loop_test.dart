import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/core/services/auth_service.dart';
import 'package:trulana/core/services/context_query_service.dart';

/// End-to-end tests for the full service loop:
///   auth request -> token -> context query -> redact -> response
///
/// These run at the service layer (transport-agnostic), proving that
/// both REST and MCP paths produce identical outcomes since they
/// call the same service instances.
void main() {
  group('Full auth -> query loop', () {
    test('auth then query returns redacted context', () async {
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'loop-test-agent',
        appName: 'Loop Test',
        scopes: <String>['context.read'],
        intent: 'integration test',
      );

      expect(auth.isSuccess, isTrue);
      expect(auth.accessToken, isNotEmpty);
      expect(auth.ttlSeconds, greaterThan(0));
      expect(auth.grantedScopes, contains('context.read'));

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
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

    test('auth then query with work context strips SSN', () async {
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'ssn-test-agent',
        appName: 'SSN Test',
        scopes: <String>['context.read'],
        intent: 'SSN redaction test',
      );

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: 'work colleagues',
      );

      expect(query.isSuccess, isTrue);
      expect(query.sanitizedText, isNot(contains('478-33-9182')));
      expect(query.sanitizedText, contains('[SSN REDACTED]'));
      expect(query.sanitizedText, contains('[ORGANIZATION]'));
    });

    test('auth then query with finance strips cards and amounts', () async {
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'fin-test-agent',
        appName: 'Finance Test',
        scopes: <String>['context.read'],
        intent: 'financial redaction test',
      );

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: 'financial info',
      );

      expect(query.isSuccess, isTrue);
      expect(query.sanitizedText, isNot(contains('4111 1111 1111 1234')));
      expect(query.sanitizedText, isNot(contains('3782 822463 10005')));
      expect(query.sanitizedText, contains('[CARD REDACTED]'));
      expect(query.sanitizedText, contains('[AMOUNT GENERALIZED]'));
    });

    test('no vault match falls back to redacting the query itself', () async {
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'fallback-agent',
        appName: 'Fallback Test',
        scopes: <String>['context.read'],
        intent: 'fallback test',
      );

      final ContextQueryResult query =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: 'random weather question',
      );

      expect(query.isSuccess, isTrue);
      expect(query.sanitizedText, 'random weather question');
      expect(query.redactionsApplied, 0);
      expect(query.vaultHits, 0);
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
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'query-val-agent',
        appName: 'Query Val',
        scopes: <String>['context.read'],
        intent: 'validation test',
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: '',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 400);
    });

    test('null query is rejected', () async {
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'null-query-agent',
        appName: 'Null Query',
        scopes: <String>['context.read'],
        intent: 'null test',
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: null,
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 400);
    });
  });

  group('Token lifecycle', () {
    test('token can be used immediately after issuance', () async {
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'lifecycle-agent',
        appName: 'Lifecycle',
        scopes: <String>['context.read'],
        intent: 'lifecycle test',
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: 'morning',
      );
      expect(result.isSuccess, isTrue);
    });

    test('revoked token is rejected', () async {
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'revoke-test-agent',
        appName: 'Revoke Test',
        scopes: <String>['context.read'],
        intent: 'revoke test',
      );

      TokenManager.instance.revokeToken(auth.accessToken);

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: 'morning',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 401);
    });

    test('per-agent revocation invalidates all tokens for that agent', () async {
      final AuthResult auth1 = await AuthService.instance.requestAccess(
        appId: 'multi-token-agent',
        appName: 'Multi Token',
        scopes: <String>['context.read'],
        intent: 'token 1',
      );

      final String token2 = TokenManager.instance.generateToken(
        agentId: 'multi-token-agent',
        scopes: <String>['context.read'],
      );

      TokenManager.instance.revokeAgentTokens('multi-token-agent');

      final ContextQueryResult r1 =
          await ContextQueryService.instance.queryContext(
        accessToken: auth1.accessToken,
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
      final AuthResult auth = await AuthService.instance.requestAccess(
        appId: 'strict-agent',
        appName: 'Strict Test',
        scopes: <String>['context.read'],
        intent: 'privacy test',
      );

      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: auth.accessToken,
        query: 'morning routine',
      );

      expect(result.isSuccess, isTrue);
      expect(result.privacyLevel, 'strict');
      expect(result.sanitizedText, isNot(contains('6:30 AM')));
      expect(result.sanitizedText, isNot(contains('7:15 AM')));
      expect(result.sanitizedText, contains('[TIME GENERALIZED]'));
    });
  });
}
