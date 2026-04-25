import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/services/auth_service.dart';
import 'package:trulana/core/services/context_query_service.dart';

const String _serverName = 'trulana';
const String _serverVersion = '1.2.1';

/// MCP stdio server that exposes Trulana's shared services over the
/// Model Context Protocol. Reads JSON-RPC 2.0 from stdin, dispatches
/// to [AuthService] and [ContextQueryService], writes responses to
/// stdout. All logging goes to stderr via [SafeLogger].
///
/// This runs inside the same Flutter macOS process as the main app,
/// giving it full access to the encrypted database, Keychain, and
/// all registered plugins.
class McpServer {
  McpServer._();

  static Future<void> run() async {
    SafeLogger.mcpStart();

    final Stream<String> lines = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final String line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final Object? decoded = jsonDecode(line);
        if (decoded is! Map<String, Object?>) continue;

        final response = await _handleMessage(decoded);
        if (response != null) {
          stdout.writeln(jsonEncode(response));
        }
      } on FormatException {
        stdout.writeln(jsonEncode(_errorResponse(
          null,
          -32700,
          'Parse error',
        )));
      }
    }
  }

  static Future<Map<String, Object?>?> _handleMessage(
    Map<String, Object?> message,
  ) async {
    final String? method = message['method'] as String?;
    final Object? id = message['id'];

    if (method == null) return null;

    // Notifications (no id) don't get responses.
    if (id == null) return null;

    switch (method) {
      case 'initialize':
        return _handleInitialize(id, message);
      case 'tools/list':
        return _handleToolsList(id);
      case 'tools/call':
        return await _handleToolsCall(id, message);
      case 'ping':
        return _successResponse(id, <String, Object?>{});
      default:
        return _errorResponse(id, -32601, 'Method not found: $method');
    }
  }

  static Map<String, Object?> _handleInitialize(
    Object id,
    Map<String, Object?> message,
  ) {
    return _successResponse(id, <String, Object?>{
      'protocolVersion': '2024-11-05',
      'capabilities': <String, Object?>{
        'tools': <String, Object?>{},
      },
      'serverInfo': <String, Object?>{
        'name': _serverName,
        'version': _serverVersion,
      },
    });
  }

  static Map<String, Object?> _handleToolsList(Object id) {
    return _successResponse(id, <String, Object?>{
      'tools': <Map<String, Object?>>[
        <String, Object?>{
          'name': 'sovereign_request_access',
          'description':
              'Request scoped access to the user\'s Trulana vault. '
              'Returns a short-lived access token.',
          'inputSchema': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'app_id': <String, Object?>{
                'type': 'string',
                'description': 'Unique identifier for the requesting agent.',
              },
              'app_name': <String, Object?>{
                'type': 'string',
                'description': 'Human-readable name of the agent.',
              },
              'scopes': <String, Object?>{
                'type': 'array',
                'items': <String, Object?>{'type': 'string'},
                'description': 'Requested access scopes (e.g. context.read).',
              },
              'intent': <String, Object?>{
                'type': 'string',
                'description': 'Why the agent needs access.',
              },
            },
            'required': <String>['app_id', 'app_name', 'scopes', 'intent'],
          },
        },
        <String, Object?>{
          'name': 'sovereign_query_context',
          'description':
              'Query the user\'s personal context. The response is '
              'automatically redacted based on the user\'s privacy level. '
              'Requires a valid access token from sovereign_request_access.',
          'inputSchema': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'access_token': <String, Object?>{
                'type': 'string',
                'description': 'Bearer token from sovereign_request_access.',
              },
              'query': <String, Object?>{
                'type': 'string',
                'description':
                    'Natural language query (e.g. "morning routine").',
              },
            },
            'required': <String>['access_token', 'query'],
          },
        },
      ],
    });
  }

  static Future<Map<String, Object?>> _handleToolsCall(
    Object id,
    Map<String, Object?> message,
  ) async {
    final Map<String, Object?>? params =
        message['params'] as Map<String, Object?>?;
    final String? toolName = params?['name'] as String?;
    final Map<String, Object?>? args =
        params?['arguments'] as Map<String, Object?>?;

    if (toolName == null || args == null) {
      return _errorResponse(id, -32602, 'Invalid params: name and arguments required.');
    }

    switch (toolName) {
      case 'sovereign_request_access':
        return await _callRequestAccess(id, args);
      case 'sovereign_query_context':
        return await _callQueryContext(id, args);
      default:
        return _errorResponse(id, -32602, 'Unknown tool: $toolName');
    }
  }

  // ── Tool implementations ────────────────────────────────────────

  static Future<Map<String, Object?>> _callRequestAccess(
    Object id,
    Map<String, Object?> args,
  ) async {
    final List<Object?>? rawScopes = args['scopes'] as List<Object?>?;

    final AuthResult result = await AuthService.instance.requestAccess(
      appId: args['app_id'] as String?,
      appName: args['app_name'] as String?,
      scopes: rawScopes?.cast<String>(),
      intent: args['intent'] as String?,
    );

    if (!result.isSuccess) {
      return _toolResult(id, isError: true, text: result.errorMessage);
    }

    return _toolResult(id, text: jsonEncode(<String, Object>{
      'access_token': result.accessToken,
      'expires_in': result.ttlSeconds,
      'granted_scopes': result.grantedScopes,
    }));
  }

  static Future<Map<String, Object?>> _callQueryContext(
    Object id,
    Map<String, Object?> args,
  ) async {
    final String? accessToken = args['access_token'] as String?;

    if (accessToken == null || accessToken.isEmpty) {
      return _toolResult(id, isError: true, text: 'Missing access_token.');
    }

    final ContextQueryResult result =
        await ContextQueryService.instance.queryContext(
      accessToken: accessToken,
      query: args['query'] as String?,
    );

    if (!result.isSuccess) {
      return _toolResult(id, isError: true, text: result.errorMessage);
    }

    return _toolResult(id, text: jsonEncode(<String, Object>{
      'data': result.sanitizedText,
      'privacy_level': result.privacyLevel,
      'redactions_applied': result.redactionsApplied,
    }));
  }

  // ── JSON-RPC helpers ────────────────────────────────────────────

  static Map<String, Object?> _successResponse(
    Object id,
    Map<String, Object?> result,
  ) {
    return <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };
  }

  static Map<String, Object?> _errorResponse(
    Object? id,
    int code,
    String message,
  ) {
    return <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, Object?>{
        'code': code,
        'message': message,
      },
    };
  }

  static Map<String, Object?> _toolResult(
    Object id, {
    required String text,
    bool isError = false,
  }) {
    return _successResponse(id, <String, Object?>{
      'content': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'text',
          'text': text,
        },
      ],
      'isError': isError,
    });
  }
}
