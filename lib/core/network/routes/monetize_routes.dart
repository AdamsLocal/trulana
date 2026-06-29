import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/network/middleware/auth_middleware.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/features/monetization/commitment_store.dart';
import 'package:trulana/features/monetization/zk_commitment_engine.dart';
import 'package:trulana/features/security/watermark_engine.dart';

const Uuid _uuid = Uuid();

Response _json(int status, Map<String, Object?> body) => Response(
      status,
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(body),
    );

/// Handles `POST /api/v1/monetize/lease_offer` — records an inbound
/// data-lease offer from a buyer and opens an escrow commitment over the
/// requested payload.
///
/// The server commits to the payload (publishing `cryptographic_proof`,
/// a SHA-256 hash of `salt:payload`) while withholding the salt. The
/// agent later redeems the offer at `/monetize/settle`; only then is the
/// salt revealed, letting the agent confirm the payload was not altered.
Future<Response> handleLeaseOffer(Request request) async {
  try {
    final AccessToken? token =
        request.context[kAccessTokenContextKey] as AccessToken?;

    if (token == null) {
      SafeLogger.monetizeRejected(statusCode: 401);
      return _json(401, <String, Object?>{
        'status': 'error',
        'message': 'Authentication required.',
      });
    }

    if (!token.grantedScopes.contains('monetize.write')) {
      SafeLogger.monetizeRejected(statusCode: 403, agentId: token.agentId);
      return _json(403, <String, Object?>{
        'status': 'error',
        'message': 'Token does not include the monetize.write scope.',
      });
    }

    final String rawBody = await request.readAsString();
    final Map<String, Object?> body =
        (jsonDecode(rawBody) as Map<String, Object?>);

    final String? dataRequested = body['data_requested'] as String?;
    final num? priceRaw = body['price_usd'] as num?;
    final String? buyerName = body['buyer_name'] as String?;

    if (dataRequested == null ||
        dataRequested.isEmpty ||
        priceRaw == null ||
        buyerName == null ||
        buyerName.isEmpty) {
      return _json(400, <String, Object?>{
        'status': 'error',
        'message': 'Missing required fields: data_requested, '
            'price_usd, buyer_name.',
      });
    }

    final double priceUsd = priceRaw.toDouble();
    if (priceUsd <= 0) {
      return _json(400, <String, Object?>{
        'status': 'error',
        'message': 'price_usd must be a positive value.',
      });
    }

    final String txId = _uuid.v4();

    // Open the escrow commitment. This is the authoritative state for
    // settlement and is held in memory; the withheld salt is never
    // persisted to disk.
    final Map<String, String> commitment =
        ZkCommitmentEngine.instance.generateCommitment(dataRequested);
    final String publicHash = commitment['hash']!;
    CommitmentStore.instance.put(EscrowCommitment(
      offerId: txId,
      hash: publicHash,
      salt: commitment['salt']!,
      payload: dataRequested,
      createdAt: DateTime.now(),
    ));

    // Persist the offer to the ledger + audit trail. Best-effort: the
    // escrow itself does not depend on the DB, so a storage hiccup must
    // not abort the offer.
    await _persistOfferRecords(
      txId: txId,
      buyerName: buyerName,
      dataRequested: dataRequested,
      priceUsd: priceUsd,
      agentId: token.agentId,
    );

    return _json(200, <String, Object?>{
      'status': 'zk_escrow_initiated',
      'offer_id': txId,
      'message': 'Escrow opened. Submit offer_id + a cleared bounty token '
          'to /monetize/settle to reveal the salt and verify the payload.',
      'cryptographic_proof': publicHash,
    });
  } on FormatException {
    return _json(400, <String, Object?>{
      'status': 'error',
      'message': 'Invalid JSON payload.',
    });
  } catch (_) {
    return _json(500, <String, Object?>{
      'status': 'error',
      'message': 'Internal server error.',
    });
  }
}

/// Handles `POST /api/v1/monetize/settle` — closes the escrow loop.
///
/// The agent submits `offer_id` and a settlement (`bounty_token`). When
/// the token clears, the server verifies the open commitment, reveals
/// the withheld salt, and returns the payload watermarked with a
/// per-transaction trace for leak provenance. Reveal is one-time: the
/// commitment is consumed so the same offer cannot settle twice.
Future<Response> handleBountySettlement(Request request) async {
  try {
    final AccessToken? token =
        request.context[kAccessTokenContextKey] as AccessToken?;

    if (token == null) {
      return _json(401, <String, Object?>{
        'status': 'error',
        'message': 'Authentication required.',
      });
    }

    if (!token.grantedScopes.contains('monetize.write')) {
      SafeLogger.monetizeRejected(statusCode: 403, agentId: token.agentId);
      return _json(403, <String, Object?>{
        'status': 'error',
        'message': 'Token does not include the monetize.write scope.',
      });
    }

    final String rawBody = await request.readAsString();
    final Map<String, Object?> body =
        (jsonDecode(rawBody) as Map<String, Object?>);

    final String? offerId = body['offer_id'] as String?;
    final String? bountyToken = body['bounty_token'] as String?;
    // Optional: if the agent echoes back the proof it was issued, it must
    // match the commitment on file (defends against settling the wrong offer).
    final String? providedHash = body['cryptographic_proof'] as String?;

    if (offerId == null ||
        offerId.isEmpty ||
        bountyToken == null ||
        bountyToken.isEmpty) {
      return _json(400, <String, Object?>{
        'status': 'error',
        'message': 'Missing required fields: offer_id, bounty_token.',
      });
    }

    // Settlement-token clearing. The `caas_tk_` prefix is a stand-in for
    // real Stripe / on-chain settlement verification (tracked as future work).
    if (!bountyToken.startsWith('caas_tk_')) {
      return _json(403, <String, Object?>{
        'status': 'error',
        'message': 'Invalid or uncleared bounty token.',
      });
    }

    final EscrowCommitment? commitment =
        CommitmentStore.instance.get(offerId);
    if (commitment == null) {
      return _json(404, <String, Object?>{
        'status': 'error',
        'message': 'No open escrow for that offer_id '
            '(unknown or already settled).',
      });
    }

    if (providedHash != null && providedHash != commitment.hash) {
      return _json(409, <String, Object?>{
        'status': 'error',
        'message': 'Provided proof does not match the commitment on file.',
      });
    }

    // Re-derive the commitment from the withheld salt + payload to confirm
    // the revealed values actually hash to the published proof.
    final bool verified = ZkCommitmentEngine.instance.verifyProof(
      commitment.hash,
      commitment.salt,
      commitment.payload,
    );
    if (!verified) {
      return _json(500, <String, Object?>{
        'status': 'error',
        'message': 'Commitment integrity check failed.',
      });
    }

    // One-time reveal: consume the commitment so it cannot settle twice.
    CommitmentStore.instance.take(offerId);

    final String traceId =
        '${token.agentId}:${DateTime.now().millisecondsSinceEpoch}';
    final String watermarkedPayload = WatermarkEngine.instance.injectHologram(
      commitment.payload,
      traceId,
    );

    await _persistSettlementAudit(agentId: token.agentId, offerId: offerId);

    return _json(200, <String, Object?>{
      'status': 'bounty_cleared',
      'offer_id': offerId,
      'verified': true,
      'commitment_hash': commitment.hash,
      'revealed_salt': commitment.salt,
      'unlocked_context': watermarkedPayload,
      'message': 'Settlement token accepted. Commitment verified; payload '
          'revealed and watermarked. Recompute SHA-256(salt:payload) after '
          'stripping zero-width characters to verify.',
    });
  } on FormatException {
    return _json(400, <String, Object?>{
      'status': 'error',
      'message': 'Invalid JSON payload.',
    });
  } catch (_) {
    return _json(500, <String, Object?>{
      'status': 'error',
      'message': 'Internal server error.',
    });
  }
}

/// Best-effort persistence of an opened lease offer. Failures are
/// swallowed so a DB hiccup never aborts an otherwise valid offer.
Future<void> _persistOfferRecords({
  required String txId,
  required String buyerName,
  required String dataRequested,
  required double priceUsd,
  required String agentId,
}) async {
  try {
    final DatabaseHelper db = DatabaseHelper.instance;
    await db.insertLedgerEntry(LedgerEntry(
      txId: txId,
      buyerName: buyerName,
      dataLeased: dataRequested,
      amountUsd: priceUsd,
      timestamp: DateTime.now(),
    ));
    await db.insertAuditEntry(AuditLogEntry(
      logId: _uuid.v4(),
      agentId: agentId,
      requestIntent: 'Lease offer submitted',
      actionTaken: AuditAction.negotiated,
      timestamp: DateTime.now(),
    ));
  } catch (_) {
    // Audit/ledger persistence is best-effort here; the escrow state of
    // record lives in CommitmentStore.
  }
}

/// Best-effort audit of a settlement.
Future<void> _persistSettlementAudit({
  required String agentId,
  required String offerId,
}) async {
  try {
    await DatabaseHelper.instance.insertAuditEntry(AuditLogEntry(
      logId: _uuid.v4(),
      agentId: agentId,
      requestIntent: 'Escrow settled: $offerId',
      actionTaken: AuditAction.approved,
      timestamp: DateTime.now(),
    ));
  } catch (_) {
    // Best-effort.
  }
}
