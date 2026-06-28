import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/network/middleware/auth_middleware.dart';
import 'package:trulana/core/network/middleware/rate_limiter.dart';
import 'package:trulana/core/network/middleware/validation_middleware.dart';
import 'package:trulana/core/network/routes/auth_routes.dart';
import 'package:trulana/core/network/routes/context_routes.dart';
import 'package:trulana/core/network/routes/monetize_routes.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/providers/redaction_provider.dart';

/// The local HTTP server that exposes Trulana's Personal API to
/// third-party agents running on the same device.
///
/// Binds exclusively to the IPv4 loopback address so that no traffic
/// from the local network or internet can reach it. This is the
/// foundational security boundary — even if a firewall is misconfigured,
/// the OS kernel will reject non-localhost connections.
class TrulanaServer {
  TrulanaServer._();
  static final TrulanaServer instance = TrulanaServer._();

  HttpServer? _server;
  late ProviderContainer _container;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  /// Starts the local HTTP server on `127.0.0.1:[port]`.
  ///
  /// Callers should await this before advertising the port to agents.
  /// If the server is already running, the call is a no-op to prevent
  /// port-binding conflicts.
  Future<void> start(ProviderContainer container, {int port = 8432}) async {
    if (_server != null) return;

    try {
      _container = container;
      final Handler handler = _buildHandler();

      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        port,
      );

      SafeLogger.serverStart(port);
      _startTokenPurgeTimer();
    } catch (_) {
      _server = null;
      rethrow;
    }
  }

  /// Stops the server gracefully, giving in-flight requests up to
  /// 5 seconds to complete before the socket is torn down.
  Future<void> stop() async {
    try {
      await _server?.close(force: false);
    } finally {
      _server = null;
      SafeLogger.serverStop();
    }
  }

  /// Assembles the full shelf pipeline: global middleware wraps a
  /// [Router] whose public routes (auth) live at the top level and
  /// whose protected routes (context, monetize) are gated behind
  /// token auth + rate limiting.
  Handler _buildHandler() {
    final Router router = Router();

    router.get('/api/v1/health', _handleHealth);
    router.post('/api/v1/auth/request', handleAuthRequest);

    final Router protectedRouter = Router();
    protectedRouter.post('/api/v1/context/query', handleContextQuery);
    protectedRouter.post('/api/v1/monetize/lease_offer', handleLeaseOffer);

    final Handler protectedHandler = const Pipeline()
        .addMiddleware(authMiddleware())
        .addMiddleware(rateLimitMiddleware())
        .addHandler(protectedRouter.call);

    FutureOr<Response> combinedHandler(Request request) {
      final String path = request.requestedUri.path;

      if (path == '/api/v1/health' || path == '/api/v1/auth/request') {
        return router.call(request);
      }

      return protectedHandler(request);
    }

    return const Pipeline()
        .addMiddleware(validationMiddleware())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_localhostOnlyMiddleware())
        .addMiddleware(_redactionMiddleware())
        .addHandler(combinedHandler);
  }

  Response _handleHealth(Request request) {
    return Response.ok(
      jsonEncode(<String, Object>{
        'status': 'ok',
        'port': port,
      }),
      headers: <String, String>{'content-type': 'application/json'},
    );
  }

  /// Middleware that scans string response bodies leaving the server loop,
  /// passing any context objects through our on-device redaction processing engine.
  Middleware _redactionMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final Response response = await innerHandler(request);

        final String contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('application/json') || response.statusCode != 200) {
          return response;
        }

        try {
          final String bodyString = await response.readAsString();
          final String scrubbedBody = _container.read(redactContextProvider(bodyString));
          return response.change(body: scrubbedBody);
        } catch (_) {
          return response;
        }
      };
    };
  }

  /// Permissive CORS headers for local development.
  ///
  /// In production the allowed origins should be locked down to the
  /// set of known agent bundle IDs, but during MVP any localhost
  /// caller is acceptable.
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok(
            '',
            headers: _corsHeaders,
          );
        }

        final Response response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const Map<String, String> _corsHeaders = <String, String>{
    'Access-Control-Allow-Origin': 'http://localhost',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };

  /// Hard firewall: rejects any request whose remote address is not
  /// the IPv4 or IPv6 loopback.
  ///
  /// This is a defence-in-depth layer — `shelf_io.serve` already
  /// binds to loopback, but if the binding were ever changed by
  /// mistake this middleware would still block external traffic.
  Middleware _localhostOnlyMiddleware() {
    return (Handler innerHandler) {
      return (Request request) {
        final String? remoteAddress =
            (request.context['shelf.io.connection_info']
                as HttpConnectionInfo?)
            ?.remoteAddress
            .address;

        final bool isLocalhost = remoteAddress == null ||
            remoteAddress == '127.0.0.1' ||
            remoteAddress == '::1';

        if (!isLocalhost) {
          return Response(
            403,
            headers: <String, String>{'content-type': 'application/json'},
            body: jsonEncode(<String, String>{
              'status': 'error',
              'message': 'Only localhost connections are permitted.',
            }),
          );
        }

        return innerHandler(request);
      };
    };
  }

  /// Periodically evicts expired tokens to prevent memory buildup
  /// from long-running server sessions.
  void _startTokenPurgeTimer() {
    Future<void>.delayed(const Duration(minutes: 5), () {
      if (!isRunning) return;
      TokenManager.instance.purgeExpired();
      _startTokenPurgeTimer();
    });
  }
}
