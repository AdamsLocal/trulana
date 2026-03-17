import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:trulana/core/network/token_manager.dart';

/// Context key used to stash the validated [AccessToken] on the
/// request so downstream handlers can access it without re-parsing
/// the Authorization header.
const String kAccessTokenContextKey = 'sovereign.accessToken';

/// Shelf middleware that enforces Bearer-token authentication.
///
/// Every request must carry an `Authorization: Bearer <token>` header.
/// The token is validated against the in-memory [TokenManager]; expired
/// or unknown tokens are rejected immediately with a 401 so that
/// unauthenticated traffic never reaches route handlers.
Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      final String? authHeader = request.headers['authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(
          401,
          headers: <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, String>{
            'status': 'error',
            'message': 'Missing or malformed Authorization header.',
          }),
        );
      }

      final String tokenString = authHeader.substring('Bearer '.length).trim();
      final AccessToken? accessToken =
          TokenManager.instance.validateToken(tokenString);

      if (accessToken == null) {
        return Response(
          401,
          headers: <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, String>{
            'status': 'error',
            'message': 'Invalid or expired access token.',
          }),
        );
      }

      final Request enrichedRequest = request.change(
        context: <String, Object>{kAccessTokenContextKey: accessToken},
      );

      return innerHandler(enrichedRequest);
    };
  };
}
