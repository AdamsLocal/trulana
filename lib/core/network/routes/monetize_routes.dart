import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/network/middleware/auth_middleware.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/models/models.dart';

const Uuid _uuid = Uuid();

/// Handles `POST /api/v1/monetize/lease_offer` — records an inbound
/// data-lease offer from a buyer so the user can review and approve
/// it from the Monetization Hub dashboard.
///
/// The offer is persisted immediately but marked as pending — no data
/// ever leaves the vault until the user explicitly accepts. This
/// inverts the traditional ad-tech model: the user sees the offer
/// *before* any data is shared.
Future<Response> handleLeaseOffer(Request request) async {
  try {
    final AccessToken? token =
        request.context[kAccessTokenContextKey] as AccessToken?;

    if (token == null) {
      SafeLogger.monetizeRejected(statusCode: 401);
      return Response(
        401,
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{
          'status': 'error',
          'message': 'Authentication required.',
        }),
      );
    }

    if (!token.grantedScopes.contains('monetize.write')) {
      SafeLogger.monetizeRejected(
        statusCode: 403,
        agentId: token.agentId,
      );
      return Response(
        403,
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{
          'status': 'error',
          'message': 'Token does not include the monetize.write scope.',
        }),
      );
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
      return Response(
        400,
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{
          'status': 'error',
          'message': 'Missing required fields: data_requested, '
              'price_usd, buyer_name.',
        }),
      );
    }

    final double priceUsd = priceRaw.toDouble();

    if (priceUsd <= 0) {
      return Response(
        400,
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{
          'status': 'error',
          'message': 'price_usd must be a positive value.',
        }),
      );
    }

    final String txId = _uuid.v4();

    final LedgerEntry ledgerEntry = LedgerEntry(
      txId: txId,
      buyerName: buyerName,
      dataLeased: dataRequested,
      amountUsd: priceUsd,
      timestamp: DateTime.now(),
    );

    final DatabaseHelper db = DatabaseHelper.instance;
    await db.insertLedgerEntry(ledgerEntry);

    final AuditLogEntry auditEntry = AuditLogEntry(
      logId: _uuid.v4(),
      agentId: token.agentId,
      requestIntent: 'Lease offer submitted',
      actionTaken: AuditAction.negotiated,
      timestamp: DateTime.now(),
    );
    await db.insertAuditEntry(auditEntry);

    return Response.ok(
      jsonEncode(<String, Object>{
        'status': 'pending_approval',
        'offer_id': txId,
        'message': 'Offer logged. Awaiting user approval.',
      }),
      headers: <String, String>{'content-type': 'application/json'},
    );
  } on FormatException {
    return Response(
      400,
      headers: <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, String>{
        'status': 'error',
        'message': 'Invalid JSON payload.',
      }),
    );
  } catch (_) {
    return Response.internalServerError(
      headers: <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, String>{
        'status': 'error',
        'message': 'Internal server error.',
      }),
    );
  }
}
