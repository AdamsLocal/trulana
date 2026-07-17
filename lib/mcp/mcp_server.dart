import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/services/auth_service.dart';
import 'package:trulana/core/services/context_query_service.dart';
import 'package:trulana/mcp/mcp_caller_auth.dart';
import 'package:trulana/models/models.dart';

const String _serverName = 'trulana';
const String _serverVersion = '1.2.1';
const Uuid _uuid = Uuid();

/// MCP stdio server that exposes Trulana's shared services over the
/// Model Context Protocol. Reads JSON-RPC 2.0 from stdin, dispatches
/// to shared services, and writes responses to stdout.
class McpServer {
  McpServer._();

  static final McpCallerAuth _callerAuth = McpCallerAuth();
  static final DatabaseHelper _db = DatabaseHelper.instance;

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

        final Map<String, Object?>? response = await _handleMessage(decoded);
        if (response != null) stdout.writeln(jsonEncode(response));
      } on FormatException {
        stdout.writeln(jsonEncode(_errorResponse(null, -32700, 'Parse error')));
      }
    }
  }

  static Future<Map<String, Object?>?> _handleMessage(
    Map<String, Object?> message,
  ) async {
    final String? method = message['method'] as String?;
    final Object? id = message['id'];
    if (method == null || id == null) return null;

    switch (method) {
      case 'initialize':
        return _handleInitialize(id);
      case 'tools/list':
        return _handleToolsList(id);
      case 'tools/call':
        return _handleToolsCall(id, message);
      case 'ping':
        return _successResponse(id, <String, Object?>{});
      default:
        return _errorResponse(id, -32601, 'Method not found: $method');
    }
  }

  static Map<String, Object?> _handleInitialize(Object id) {
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
          'name': 'sovereign_auth_challenge',
          'description': 'Enroll an Ed25519 public key or request a fresh '
              'single-use challenge for an approved MCP caller.',
          'inputSchema': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'app_id': <String, Object?>{
                'type': 'string',
                'description': 'Stable identifier for the requesting agent.',
              },
              'app_name': <String, Object?>{
                'type': 'string',
                'description': 'Human-readable name shown for approval.',
              },
              'scopes': <String, Object?>{
                'type': 'array',
                'items': <String, Object?>{'type': 'string'},
                'description': 'Requested scopes, such as context.read.',
              },
              'intent': <String, Object?>{
                'type': 'string',
                'description': 'Why the agent needs access.',
              },
              'public_key': <String, Object?>{
                'type': 'string',
                'description': 'Raw 32-byte Ed25519 public key in base64url.',
              },
            },
            'required': <String>[
              'app_id',
              'app_name',
              'scopes',
              'intent',
              'public_key',
            ],
          },
        },
        <String, Object?>{
          'name': 'sovereign_auth_prove',
          'description': 'Prove possession of the approved Ed25519 key by '
              'signing a fresh challenge. Returns a short-lived token.',
          'inputSchema': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'challenge_id': <String, Object?>{
                'type': 'string',
                'description': 'ID returned by sovereign_auth_challenge.',
              },
              'signature': <String, Object?>{
                'type': 'string',
                'description': 'Raw 64-byte Ed25519 signature in base64url.',
              },
            },
            'required': <String>['challenge_id', 'signature'],
          },
        },
        <String, Object?>{
          'name': 'sovereign_query_context',
          'description': 'Query personal context using a token returned by '
              'sovereign_auth_prove. Responses are automatically redacted.',
          'inputSchema': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'access_token': <String, Object?>{
                'type': 'string',
                'description': 'Bearer token from sovereign_auth_prove.',
              },
              'query': <String, Object?>{
                'type': 'string',
                'description': 'Natural-language context query.',
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
      return _errorResponse(
        id,
        -32602,
        'Invalid params: name and arguments required.',
      );
    }

    switch (toolName) {
      case 'sovereign_auth_challenge':
        return _callAuthChallenge(id, args);
      case 'sovereign_auth_prove':
        return _callAuthProve(id, args);
      case 'sovereign_request_access':
        return _toolResult(
          id,
          isError: true,
          text: 'Cryptographic MCP authentication is required. Use '
              'sovereign_auth_challenge, sign its payload with the approved '
              'Ed25519 key, then call sovereign_auth_prove.',
        );
      case 'sovereign_query_context':
        return _callQueryContext(id, args);
      default:
        return _errorResponse(id, -32602, 'Unknown tool: $toolName');
    }
  }

  static Future<Map<String, Object?>> _callAuthChallenge(
    Object id,
    Map<String, Object?> args,
  ) async {
    try {
      final String? appId = args['app_id'] as String?;
      final String? appName = args['app_name'] as String?;
      final String? intent = args['intent'] as String?;
      final String? publicKey = args['public_key'] as String?;
      final List<Object?>? rawScopes = args['scopes'] as List<Object?>?;
      if (appId == null ||
          appId.isEmpty ||
          appName == null ||
          appName.isEmpty ||
          intent == null ||
          intent.isEmpty ||
          publicKey == null ||
          rawScopes == null ||
          rawScopes.isEmpty ||
          rawScopes.any((Object? value) => value is! String)) {
        return _toolResult(
          id,
          isError: true,
          text: 'app_id, app_name, non-empty string scopes, intent, and '
              'public_key are required.',
        );
      }

      final List<String> scopes = rawScopes.cast<String>();
      final String normalizedKey = McpCallerAuth.normalizePublicKey(publicKey);
      final AuthorizedAgent? agent = await _db.getAgentById(appId);

      if (agent == null) {
        await AuthService.instance.requestAccess(
          appId: appId,
          appName: appName,
          scopes: scopes,
          intent: intent,
          mcpPublicKey: normalizedKey,
        );
        return _toolResult(
          id,
          isError: true,
          text: jsonEncode(<String, Object>{
            'status': 'pending_user_approval',
            'public_key_fingerprint':
                McpCallerAuth.publicKeyFingerprint(normalizedKey),
          }),
        );
      }

      if (agent.mcpPublicKey == null) {
        return _toolResult(
          id,
          isError: true,
          text: 'This approval predates MCP key binding. Revoke it and '
              'submit a new enrollment so the key fingerprint can be reviewed.',
        );
      }
      if (agent.mcpPublicKey != normalizedKey) {
        SafeLogger.authRejected(statusCode: 401, agentId: appId);
        return _toolResult(
          id,
          isError: true,
          text: 'MCP public key does not match the user-approved identity.',
        );
      }
      if (agent.status != AgentStatus.active) {
        SafeLogger.authRejected(statusCode: 403, agentId: appId);
        final String state = agent.status == AgentStatus.pending
            ? 'pending user approval'
            : 'not active';
        return _toolResult(id, isError: true, text: 'Agent access is $state.');
      }

      final McpCallerChallenge challenge = _callerAuth.issue(
        appId: agent.agentId,
        appName: agent.agentName,
        scopes: agent.grantedScopes,
        intent: intent,
        publicKey: normalizedKey,
      );
      return _toolResult(id, text: jsonEncode(challenge.toPublicMap()));
    } on McpCallerAuthException catch (error) {
      SafeLogger.authRejected(statusCode: 400, agentId: error.appId);
      return _toolResult(id, isError: true, text: error.message);
    } on TypeError {
      SafeLogger.authRejected(statusCode: 400);
      return _toolResult(id, isError: true, text: 'Invalid argument types.');
    }
  }

  static Future<Map<String, Object?>> _callAuthProve(
    Object id,
    Map<String, Object?> args,
  ) async {
    final Object? rawChallengeId = args['challenge_id'];
    final Object? rawSignature = args['signature'];
    if (rawChallengeId is! String ||
        rawChallengeId.isEmpty ||
        rawSignature is! String ||
        rawSignature.isEmpty) {
      return _toolResult(
        id,
        isError: true,
        text: 'challenge_id and signature are required.',
      );
    }
    final String challengeId = rawChallengeId;
    final String signature = rawSignature;

    try {
      final McpCallerChallenge challenge = await _callerAuth.verify(
        challengeId: challengeId,
        signature: signature,
      );
      final AuthResult result = await AuthService.instance.requestAccess(
        appId: challenge.appId,
        appName: challenge.appName,
        scopes: challenge.scopes,
        intent: challenge.intent,
        mcpProofVerified: true,
      );
      if (!result.isSuccess) {
        return _toolResult(id, isError: true, text: result.errorMessage);
      }

      return _toolResult(id, text: jsonEncode(<String, Object>{
        'access_token': result.accessToken,
        'expires_in': result.ttlSeconds,
        'granted_scopes': result.grantedScopes,
      }));
    } on McpCallerAuthException catch (error) {
      await _auditProofFailure(error);
      SafeLogger.authRejected(statusCode: 401, agentId: error.appId);
      return _toolResult(id, isError: true, text: error.message);
    }
  }

  static Future<void> _auditProofFailure(McpCallerAuthException error) async {
    final String? appId = error.appId;
    if (appId == null) return;
    await _db.insertAuditEntry(
      AuditLogEntry(
        logId: _uuid.v4(),
        agentId: appId,
        requestIntent: 'MCP Ed25519 caller proof rejected',
        actionTaken: AuditAction.blocked,
        timestamp: DateTime.now(),
      ),
    );
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

  static Map<String, Object?> _successResponse(
    Object id,
    Map<String, Object?> result,
  ) =>
      <String, Object?>{'jsonrpc': '2.0', 'id': id, 'result': result};

  static Map<String, Object?> _errorResponse(
    Object? id,
    int code,
    String message,
  ) =>
      <String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'error': <String, Object?>{'code': code, 'message': message},
      };

  static Map<String, Object?> _toolResult(
    Object id, {
    required String text,
    bool isError = false,
  }) {
    return _successResponse(id, <String, Object?>{
      'content': <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': text},
      ],
      'isError': isError,
    });
  }
}
