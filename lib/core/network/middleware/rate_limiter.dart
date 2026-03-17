import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:trulana/core/network/middleware/auth_middleware.dart';
import 'package:trulana/core/network/token_manager.dart';

/// Sliding-window rate limiter that caps requests per agent.
///
/// Sits *after* the auth middleware in the pipeline so it can read
/// the agent ID from the already-validated [AccessToken]. Agents
/// that exceed the window are told to back off with a 429, preventing
/// a rogue integration from hammering the local vault.
Middleware rateLimitMiddleware({
  int maxRequests = 60,
  Duration window = const Duration(minutes: 1),
}) {
  final Map<String, List<DateTime>> requestLog =
      <String, List<DateTime>>{};

  return (Handler innerHandler) {
    return (Request request) {
      final AccessToken? token =
          request.context[kAccessTokenContextKey] as AccessToken?;

      if (token == null) {
        return innerHandler(request);
      }

      final String agentId = token.agentId;
      final DateTime now = DateTime.now();
      final DateTime windowStart = now.subtract(window);

      final List<DateTime> timestamps =
          requestLog.putIfAbsent(agentId, () => <DateTime>[]);

      timestamps.removeWhere(
        (DateTime ts) => ts.isBefore(windowStart),
      );

      if (timestamps.length >= maxRequests) {
        return Response(
          429,
          headers: <String, String>{
            'content-type': 'application/json',
            'retry-after': '60',
          },
          body: jsonEncode(<String, String>{
            'status': 'error',
            'message': 'Rate limit exceeded. Max $maxRequests requests per '
                '${window.inSeconds} seconds.',
          }),
        );
      }

      timestamps.add(now);

      return innerHandler(request);
    };
  };
}
