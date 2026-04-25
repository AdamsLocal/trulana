import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/models/models.dart';

const int _defaultTtlSeconds = 900;
const Uuid _uuid = Uuid();

/// Transport-agnostic result from [AuthService.requestAccess].
/// Both REST and MCP check [isSuccess] and read either the success
/// fields or [errorCode] + [errorMessage].
class AuthResult {
  final bool isSuccess;
  final int errorCode;
  final String errorMessage;

  final String accessToken;
  final int ttlSeconds;
  final List<String> grantedScopes;

  const AuthResult._({
    required this.isSuccess,
    this.errorCode = 0,
    this.errorMessage = '',
    this.accessToken = '',
    this.ttlSeconds = 0,
    this.grantedScopes = const <String>[],
  });

  factory AuthResult.success({
    required String accessToken,
    required int ttlSeconds,
    required List<String> grantedScopes,
  }) =>
      AuthResult._(
        isSuccess: true,
        accessToken: accessToken,
        ttlSeconds: ttlSeconds,
        grantedScopes: grantedScopes,
      );

  factory AuthResult.failure({
    required int errorCode,
    required String errorMessage,
  }) =>
      AuthResult._(
        isSuccess: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
}

/// Shared auth policy layer. Both REST route handlers and MCP tools
/// call this — one path, one policy, different transports.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<AuthResult> requestAccess({
    required String? appId,
    required String? appName,
    required List<String>? scopes,
    required String? intent,
    int? debugTtlSeconds,
  }) async {
    if (appId == null ||
        appId.isEmpty ||
        appName == null ||
        appName.isEmpty ||
        scopes == null ||
        scopes.isEmpty ||
        intent == null ||
        intent.isEmpty) {
      SafeLogger.authRejected(statusCode: 400);
      return AuthResult.failure(
        errorCode: 400,
        errorMessage: 'Missing required fields: app_id, app_name, '
            'requested_scopes, intent.',
      );
    }

    AuthorizedAgent? agent = await _db.getAgentById(appId);

    if (agent == null) {
      // First-contact agent: persist as pending and await explicit user
      // approval. No token is issued here — the user must promote the
      // agent to `active` from the Gatekeeper UI before calls succeed.
      final AuthorizedAgent newAgent = AuthorizedAgent(
        agentId: appId,
        agentName: appName,
        grantedScopes: scopes,
        status: AgentStatus.pending,
        expirationDate: DateTime.now().add(const Duration(days: 30)),
      );
      await _db.insertAgent(newAgent);

      final AuditLogEntry pendingAuditEntry = AuditLogEntry(
        logId: _uuid.v4(),
        agentId: appId,
        requestIntent: intent,
        actionTaken: AuditAction.blocked,
        timestamp: DateTime.now(),
      );
      await _db.insertAuditEntry(pendingAuditEntry);

      SafeLogger.authRejected(statusCode: 403, agentId: appId);
      return AuthResult.failure(
        errorCode: 403,
        errorMessage:
            'Access request pending user approval.',
      );
    }

    if (agent.status == AgentStatus.revoked) {
      SafeLogger.authRejected(statusCode: 403, agentId: appId);
      return AuthResult.failure(
        errorCode: 403,
        errorMessage: 'Agent access has been revoked by the user.',
      );
    }

    if (agent.status == AgentStatus.pending) {
      SafeLogger.authRejected(statusCode: 403, agentId: appId);
      return AuthResult.failure(
        errorCode: 403,
        errorMessage: 'Access request pending user approval.',
      );
    }

    if (agent.status == AgentStatus.paused) {
      SafeLogger.authRejected(statusCode: 403, agentId: appId);
      return AuthResult.failure(
        errorCode: 403,
        errorMessage: 'Agent access is paused.',
      );
    }

    // Authoritative scopes come from the persisted agent record — the
    // caller-supplied `scopes` parameter is only used to prove the
    // caller knows what it is asking for, not to grant new privileges.
    final List<String> grantedScopes = List<String>.unmodifiable(
      agent.grantedScopes,
    );

    final int ttl = _resolveTtl(debugTtlSeconds);
    final String tokenString = TokenManager.instance.generateToken(
      agentId: appId,
      scopes: grantedScopes,
      ttl: Duration(seconds: ttl),
    );

    final AuditLogEntry auditEntry = AuditLogEntry(
      logId: _uuid.v4(),
      agentId: appId,
      requestIntent: intent,
      actionTaken: AuditAction.approved,
      timestamp: DateTime.now(),
    );
    await _db.insertAuditEntry(auditEntry);

    SafeLogger.authGranted(agentId: appId, ttlSeconds: ttl);

    return AuthResult.success(
      accessToken: tokenString,
      ttlSeconds: ttl,
      grantedScopes: grantedScopes,
    );
  }

  static int _resolveTtl(int? debugTtl) {
    if (!kDebugMode || debugTtl == null) return _defaultTtlSeconds;
    return debugTtl.clamp(1, _defaultTtlSeconds);
  }
}
