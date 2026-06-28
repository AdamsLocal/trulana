import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/redaction_provider.dart';

class ApiRouter {
  final ProviderContainer container;

  ApiRouter(this.container);

  Router get router {
    final router = Router();

    // The endpoint your local AI tools hit to query state context
    router.post('/v1/context', (Request request) async {
      try {
        final payload = await request.readAsString();
        final Map<String, dynamic> body = jsonDecode(payload);
        
        final String rawContext = body['context'] ?? '';

        // Read our Riverpod provider state synchronously inside the request loop
        final String secureContext = container.read(
          redactContextProvider(rawContext),
        );

        return Response.ok(
          jsonEncode({
            'status': 'secure',
            'data': secureContext,
            'timestamp': DateTime.now().toIso8601String(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    return router;
  }
}
