import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:trulana/core/network/middleware/auth_middleware.dart';
import 'package:trulana/core/network/routes/monetize_routes.dart';
import 'package:trulana/core/network/token_manager.dart';

/// Handler-level tests for POST /api/v1/monetize/lease_offer.
///
/// Scope-check coverage is the main purpose: the handler must reject
/// tokens that do not carry `monetize.write` before any body parsing
/// or DB work happens. Body-validation coverage is included only to
/// confirm the scope check runs *before* body validation (so the 403
/// branch isn't hiding behind a 400 for malformed payloads).
///
/// Note: the happy-path (200 with persisted ledger entry) is not
/// asserted here because `DatabaseHelper.insertLedgerEntry` fails
/// silently in host `flutter test` (same `sqflite_sqlcipher` plugin
/// gap documented in the audit report).
AccessToken _mintAccessToken({
  required String agentId,
  required List<String> scopes,
}) {
  final DateTime now = DateTime.now();
  return AccessToken(
    token: 'test-token-$agentId-${now.microsecondsSinceEpoch}',
    agentId: agentId,
    grantedScopes: List<String>.unmodifiable(scopes),
    expiresAt: now.add(const Duration(minutes: 15)),
    createdAt: now,
  );
}

Request _buildRequest({
  required AccessToken? token,
  Map<String, Object?> body = const <String, Object?>{
    'data_requested': 'morning routine',
    'price_usd': 2.50,
    'buyer_name': 'Test Buyer',
  },
}) {
  return Request(
    'POST',
    Uri.parse('http://localhost/api/v1/monetize/lease_offer'),
    headers: <String, String>{'content-type': 'application/json'},
    body: jsonEncode(body),
    context: token == null
        ? const <String, Object>{}
        : <String, Object>{kAccessTokenContextKey: token},
  );
}

Future<Map<String, Object?>> _responseJson(Response response) async {
  return jsonDecode(await response.readAsString()) as Map<String, Object?>;
}

void main() {
  group('Monetize route scope enforcement', () {
    test('missing token returns 401', () async {
      final Response response = await handleLeaseOffer(_buildRequest(token: null));

      expect(response.statusCode, 401);
      final body = await _responseJson(response);
      expect(body['status'], 'error');
    });

    test('token without monetize.write scope returns 403', () async {
      final AccessToken token = _mintAccessToken(
        agentId: 'no-monetize-agent',
        scopes: <String>['context.read'],
      );

      final Response response = await handleLeaseOffer(_buildRequest(token: token));

      expect(response.statusCode, 403);
      final body = await _responseJson(response);
      expect(body['message'], contains('monetize.write'));
    });

    test('token with empty scopes returns 403', () async {
      final AccessToken token = _mintAccessToken(
        agentId: 'empty-scope-agent',
        scopes: const <String>[],
      );

      final Response response = await handleLeaseOffer(_buildRequest(token: token));

      expect(response.statusCode, 403);
    });

    test('scope check runs before body validation '
        '(403 beats 400 for malformed body)', () async {
      // Token lacks the scope AND body is empty — 403 must win so that
      // a caller probing the endpoint cannot infer validity of fields
      // from a 400 response.
      final AccessToken token = _mintAccessToken(
        agentId: 'scope-vs-body-agent',
        scopes: <String>['context.read'],
      );

      final Response response = await handleLeaseOffer(_buildRequest(
        token: token,
        body: const <String, Object?>{},
      ));

      expect(response.statusCode, 403);
    });

    test('token with monetize.write but malformed body returns 400', () async {
      // Now prove that WITH the scope, body validation kicks in — this
      // confirms the scope check doesn't suppress downstream validation.
      final AccessToken token = _mintAccessToken(
        agentId: 'monetize-malformed-agent',
        scopes: <String>['monetize.write'],
      );

      final Response response = await handleLeaseOffer(_buildRequest(
        token: token,
        body: const <String, Object?>{},
      ));

      expect(response.statusCode, 400);
      final body = await _responseJson(response);
      expect(body['message'], contains('Missing required fields'));
    });

    test('token with monetize.write and non-positive price returns 400',
        () async {
      final AccessToken token = _mintAccessToken(
        agentId: 'monetize-zero-price-agent',
        scopes: <String>['monetize.write'],
      );

      final Response response = await handleLeaseOffer(_buildRequest(
        token: token,
        body: const <String, Object?>{
          'data_requested': 'morning routine',
          'price_usd': 0,
          'buyer_name': 'Zero Buyer',
        },
      ));

      expect(response.statusCode, 400);
    });

    test('multi-scope token including monetize.write passes the scope gate',
        () async {
      final AccessToken token = _mintAccessToken(
        agentId: 'multi-scope-agent',
        scopes: <String>['context.read', 'monetize.write'],
      );

      final Response response = await handleLeaseOffer(_buildRequest(token: token));

      // Without a working DB the insert silently fails (returns -1)
      // but the handler still reaches the end and returns 200 with the
      // pending_approval envelope. We only assert the gate passed, not
      // the persisted state.
      expect(response.statusCode, anyOf(200, 500));
    });
  });
}
