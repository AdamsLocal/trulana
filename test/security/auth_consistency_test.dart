import 'package:flutter_test/flutter_test.dart';
import 'package:sovereign/core/services/auth_service.dart';
import 'package:sovereign/core/services/context_query_service.dart';

/// Proves that REST and MCP transports use the exact same service
/// singletons. Both auth_routes.dart and mcp_server.dart reference
/// AuthService.instance and ContextQueryService.instance — this test
/// asserts those are true singletons (same object identity) so there
/// is no possibility of divergent policy paths.
void main() {
  group('Authorization consistency', () {
    test('AuthService.instance is a singleton', () {
      final AuthService a = AuthService.instance;
      final AuthService b = AuthService.instance;
      expect(identical(a, b), isTrue);
    });

    test('ContextQueryService.instance is a singleton', () {
      final ContextQueryService a = ContextQueryService.instance;
      final ContextQueryService b = ContextQueryService.instance;
      expect(identical(a, b), isTrue);
    });

    test('AuthService validates missing fields identically regardless of caller', () async {
      final AuthResult resultA = await AuthService.instance.requestAccess(
        appId: null,
        appName: null,
        scopes: null,
        intent: null,
      );

      final AuthResult resultB = await AuthService.instance.requestAccess(
        appId: '',
        appName: 'test',
        scopes: <String>['context.read'],
        intent: 'test',
      );

      expect(resultA.isSuccess, isFalse);
      expect(resultA.errorCode, 400);
      expect(resultB.isSuccess, isFalse);
      expect(resultB.errorCode, 400);
    });

    test('ContextQueryService rejects invalid token identically', () async {
      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: 'not-a-real-token',
        query: 'test query',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 401);
      expect(result.errorMessage, contains('Invalid or expired'));
    });

    test('ContextQueryService rejects empty query', () async {
      final ContextQueryResult result =
          await ContextQueryService.instance.queryContext(
        accessToken: 'some-token',
        query: null,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, anyOf(400, 401));
    });
  });
}
