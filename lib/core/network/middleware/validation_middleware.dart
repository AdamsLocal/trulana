import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Shelf middleware that rejects POST/PUT/PATCH requests whose
/// `Content-Type` is not `application/json`.
///
/// GET and DELETE requests pass through untouched because they
/// typically carry no body. This keeps the API surface predictable
/// and prevents route handlers from having to duplicate content-type
/// checks.
Middleware validationMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      final bool requiresBody = request.method == 'POST' ||
          request.method == 'PUT' ||
          request.method == 'PATCH';

      if (requiresBody) {
        final String? contentType = request.headers['content-type'];

        final bool isJson = contentType != null &&
            contentType.contains('application/json');

        if (!isJson) {
          return Response(
            415,
            headers: <String, String>{'content-type': 'application/json'},
            body: jsonEncode(<String, String>{
              'status': 'error',
              'message': 'Content-Type must be application/json.',
            }),
          );
        }
      }

      return innerHandler(request);
    };
  };
}
