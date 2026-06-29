import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

import 'package:trulana/core/network/middleware/auth_middleware.dart';
import 'package:trulana/core/network/routes/monetize_routes.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/features/monetization/commitment_store.dart';

/// End-to-end coverage for the escrow loop:
///   POST /monetize/lease_offer  -> opens a commitment, returns a hash
///   POST /monetize/settle       -> clears the token, reveals the salt,
///                                  returns the watermarked payload
///
/// These tests exercise the wired HTTP handlers (not just the engines),
/// which is what the `caas_pipeline_test.dart` suite does not cover.
/// They depend only on the in-memory CommitmentStore, so they are
/// deterministic under host `flutter test` despite the sqflite plugin gap.

// Zero-width characters used by WatermarkEngine, as explicit escapes
// (no invisible characters in source).
const String _zwnj = '\u200C'; // watermark '0'
const String _zwj = '\u200D'; // watermark '1'

AccessToken _token({
  required String agentId,
  List<String> scopes = const <String>['monetize.write'],
}) {
  final DateTime now = DateTime.now();
  return AccessToken(
    token: 'test-$agentId-${now.microsecondsSinceEpoch}',
    agentId: agentId,
    grantedScopes: List<String>.unmodifiable(scopes),
    expiresAt: now.add(const Duration(minutes: 15)),
    createdAt: now,
  );
}

Request _post(
  String path, {
  required AccessToken? token,
  required Map<String, Object?> body,
}) {
  return Request(
    'POST',
    Uri.parse('http://localhost$path'),
    headers: const <String, String>{'content-type': 'application/json'},
    body: jsonEncode(body),
    context: token == null
        ? const <String, Object>{}
        : <String, Object>{kAccessTokenContextKey: token},
  );
}

Future<Map<String, Object?>> _json(Response r) async =>
    jsonDecode(await r.readAsString()) as Map<String, Object?>;

void main() {
  setUp(CommitmentStore.instance.clear);

  group('Escrow lease_offer -> settle (end-to-end)', () {
    test('full loop verifies and reveals the committed payload', () async {
      const String payload = 'aggregated fitness trends Q1 2026';
      final AccessToken token = _token(agentId: 'buyer-agent');

      // 1. Open the escrow.
      final Response offerRes = await handleLeaseOffer(_post(
        '/api/v1/monetize/lease_offer',
        token: token,
        body: const <String, Object?>{
          'data_requested': payload,
          'price_usd': 4.20,
          'buyer_name': 'Acme Models Inc',
        },
      ));
      expect(offerRes.statusCode, 200);
      final offer = await _json(offerRes);
      expect(offer['status'], 'zk_escrow_initiated');
      final String offerId = offer['offer_id'] as String;
      final String proof = offer['cryptographic_proof'] as String;
      expect(offerId, isNotEmpty);
      expect(proof, isNotEmpty);
      // The salt is NOT handed out at offer time.
      expect(offer.containsKey('revealed_salt'), isFalse);

      // 2. Settle with a cleared token.
      final Response settleRes = await handleBountySettlement(_post(
        '/api/v1/monetize/settle',
        token: token,
        body: <String, Object?>{
          'offer_id': offerId,
          'bounty_token': 'caas_tk_demo_cleared',
          'cryptographic_proof': proof,
        },
      ));
      expect(settleRes.statusCode, 200);
      final settled = await _json(settleRes);
      expect(settled['status'], 'bounty_cleared');
      expect(settled['verified'], isTrue);
      expect(settled['commitment_hash'], proof);

      final String revealedSalt = settled['revealed_salt'] as String;
      final String unlocked = settled['unlocked_context'] as String;
      expect(revealedSalt, isNotEmpty);
      expect(unlocked, contains(payload));

      // 3. Independently verify the commitment the way an agent would:
      //    strip the zero-width watermark, then recompute the hash.
      final String stripped =
          unlocked.replaceAll(_zwnj, '').replaceAll(_zwj, '');
      expect(stripped, payload);
      final String recomputed =
          sha256.convert(utf8.encode('$revealedSalt:$stripped')).toString();
      expect(recomputed, proof,
          reason: 'revealed salt + payload must hash to the published proof');
    });

    test('settlement is one-time: re-settling a consumed offer is 404',
        () async {
      final AccessToken token = _token(agentId: 'replay-agent');
      final offer = await _json(await handleLeaseOffer(_post(
        '/api/v1/monetize/lease_offer',
        token: token,
        body: const <String, Object?>{
          'data_requested': 'x',
          'price_usd': 1,
          'buyer_name': 'b',
        },
      )));
      final String offerId = offer['offer_id'] as String;

      final Map<String, Object?> settleBody = <String, Object?>{
        'offer_id': offerId,
        'bounty_token': 'caas_tk_ok',
      };

      final Response first = await handleBountySettlement(
          _post('/api/v1/monetize/settle', token: token, body: settleBody));
      expect(first.statusCode, 200);

      final Response second = await handleBountySettlement(
          _post('/api/v1/monetize/settle', token: token, body: settleBody));
      expect(second.statusCode, 404);
    });
  });

  group('settle guards', () {
    test('missing token returns 401', () async {
      final Response r = await handleBountySettlement(_post(
        '/api/v1/monetize/settle',
        token: null,
        body: const <String, Object?>{
          'offer_id': 'x',
          'bounty_token': 'caas_tk_x',
        },
      ));
      expect(r.statusCode, 401);
    });

    test('token without monetize.write returns 403', () async {
      final Response r = await handleBountySettlement(_post(
        '/api/v1/monetize/settle',
        token:
            _token(agentId: 'reader', scopes: const <String>['context.read']),
        body: const <String, Object?>{
          'offer_id': 'x',
          'bounty_token': 'caas_tk_x',
        },
      ));
      expect(r.statusCode, 403);
      expect((await _json(r))['message'], contains('monetize.write'));
    });

    test('missing offer_id / bounty_token returns 400', () async {
      final Response r = await handleBountySettlement(_post(
        '/api/v1/monetize/settle',
        token: _token(agentId: 'a'),
        body: const <String, Object?>{'offer_id': ''},
      ));
      expect(r.statusCode, 400);
    });

    test('uncleared bounty token returns 403', () async {
      final AccessToken token = _token(agentId: 'a');
      final offer = await _json(await handleLeaseOffer(_post(
        '/api/v1/monetize/lease_offer',
        token: token,
        body: const <String, Object?>{
          'data_requested': 'y',
          'price_usd': 2,
          'buyer_name': 'b',
        },
      )));
      final Response r = await handleBountySettlement(_post(
        '/api/v1/monetize/settle',
        token: token,
        body: <String, Object?>{
          'offer_id': offer['offer_id'],
          'bounty_token': 'not_a_cleared_token',
        },
      ));
      expect(r.statusCode, 403);
    });

    test('unknown offer_id returns 404', () async {
      final Response r = await handleBountySettlement(_post(
        '/api/v1/monetize/settle',
        token: _token(agentId: 'a'),
        body: const <String, Object?>{
          'offer_id': 'no-such-offer',
          'bounty_token': 'caas_tk_x',
        },
      ));
      expect(r.statusCode, 404);
    });

    test('proof that does not match the commitment returns 409', () async {
      final AccessToken token = _token(agentId: 'a');
      final offer = await _json(await handleLeaseOffer(_post(
        '/api/v1/monetize/lease_offer',
        token: token,
        body: const <String, Object?>{
          'data_requested': 'z',
          'price_usd': 3,
          'buyer_name': 'b',
        },
      )));
      final Response r = await handleBountySettlement(_post(
        '/api/v1/monetize/settle',
        token: token,
        body: <String, Object?>{
          'offer_id': offer['offer_id'],
          'bounty_token': 'caas_tk_x',
          'cryptographic_proof': 'deadbeef-not-the-real-hash',
        },
      ));
      expect(r.statusCode, 409);
    });
  });
}
