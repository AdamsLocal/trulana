import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'package:sovereign/core/services/auth_service.dart';

/// Thin HTTP adapter for [AuthService.requestAccess].
/// Parses the shelf request, delegates to the service, formats the response.
Future<Response> handleAuthRequest(Request request) async {
  try {
    final String rawBody = await request.readAsString();
    final Map<String, Object?> body =
        (jsonDecode(rawBody) as Map<String, Object?>);

    final List<Object?>? rawScopes =
        body['requested_scopes'] as List<Object?>?;

    final AuthResult result = await AuthService.instance.requestAccess(
      appId: body['app_id'] as String?,
      appName: body['app_name'] as String?,
      scopes: rawScopes?.cast<String>(),
      intent: body['intent'] as String?,
      debugTtlSeconds: (body['debug_ttl_seconds'] as num?)?.toInt(),
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
        'access_token': result.accessToken,
        'expires_in': result.ttlSeconds,
        'granted_scopes': result.grantedScopes,
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
