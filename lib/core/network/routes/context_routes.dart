import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'package:sovereign/core/network/middleware/auth_middleware.dart';
import 'package:sovereign/core/network/token_manager.dart';
import 'package:sovereign/core/services/context_query_service.dart';

/// Thin HTTP adapter for [ContextQueryService.queryContext].
/// Parses the shelf request, delegates to the service, formats the response.
Future<Response> handleContextQuery(Request request) async {
  try {
    final AccessToken? token =
        request.context[kAccessTokenContextKey] as AccessToken?;

    if (token == null) {
      return Response(
        401,
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{
          'status': 'error',
          'message': 'Authentication required.',
        }),
      );
    }

    final String rawBody = await request.readAsString();
    final Map<String, Object?> body =
        (jsonDecode(rawBody) as Map<String, Object?>);

    final ContextQueryResult result =
        await ContextQueryService.instance.queryContext(
      accessToken: token.token,
      query: body['query'] as String?,
    );

    if (!result.isSuccess) {
      return Response(
        result.errorCode,
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{
          'status': 'error',
          'message': result.errorMessage,
        }),
      );
    }

    return Response.ok(
      jsonEncode(<String, Object>{
        'status': 'success',
        'data': result.sanitizedText,
        'privacy_level': result.privacyLevel,
        'redactions_applied': result.redactionsApplied,
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
