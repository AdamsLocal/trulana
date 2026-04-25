import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/core/services/preferences_service.dart';
import 'package:trulana/features/engine/auto_redact_engine.dart';
import 'package:trulana/features/engine/context_vault.dart';
import 'package:trulana/features/engine/models/redaction_result.dart';
import 'package:trulana/models/models.dart';

const Uuid _uuid = Uuid();

/// Transport-agnostic result from [ContextQueryService.queryContext].
class ContextQueryResult {
  final bool isSuccess;
  final int errorCode;
  final String errorMessage;

  final String sanitizedText;
  final String privacyLevel;
  final int redactionsApplied;
  final int vaultHits;

  const ContextQueryResult._({
    required this.isSuccess,
    this.errorCode = 0,
    this.errorMessage = '',
    this.sanitizedText = '',
    this.privacyLevel = '',
    this.redactionsApplied = 0,
    this.vaultHits = 0,
  });

  factory ContextQueryResult.success({
    required String sanitizedText,
    required String privacyLevel,
    required int redactionsApplied,
    required int vaultHits,
  }) =>
      ContextQueryResult._(
        isSuccess: true,
        sanitizedText: sanitizedText,
        privacyLevel: privacyLevel,
        redactionsApplied: redactionsApplied,
        vaultHits: vaultHits,
      );

  factory ContextQueryResult.failure({
    required int errorCode,
    required String errorMessage,
  }) =>
      ContextQueryResult._(
        isSuccess: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
}

/// Shared context query policy layer. Both REST and MCP call this —
/// same token validation, same privacy level, same redaction pipeline,
/// same audit logging.
class ContextQueryService {
  ContextQueryService._();
  static final ContextQueryService instance = ContextQueryService._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Validates the token, queries the vault, runs redaction, writes audit.
  Future<ContextQueryResult> queryContext({
    required String accessToken,
    required String? query,
  }) async {
    final AccessToken? token =
        TokenManager.instance.validateToken(accessToken);

    if (token == null) {
      SafeLogger.contextQueryRejected(statusCode: 401);
      return ContextQueryResult.failure(
        errorCode: 401,
        errorMessage: 'Invalid or expired access token.',
      );
    }

    if (!token.grantedScopes.contains('context.read')) {
      SafeLogger.contextQueryRejected(
        statusCode: 403,
        agentId: token.agentId,
      );
      return ContextQueryResult.failure(
        errorCode: 403,
        errorMessage: 'Token does not include the context.read scope.',
      );
    }

    if (query == null || query.isEmpty) {
      SafeLogger.contextQueryRejected(
        statusCode: 400,
        agentId: token.agentId,
      );
      return ContextQueryResult.failure(
        errorCode: 400,
        errorMessage: 'Missing required field: query.',
      );
    }

    final UserConfig? userConfig = await _db.getUserConfig();
    final PrivacyLevel level =
        userConfig?.privacyLevel ?? PrivacyLevel.strict;

    final List<String> vaultHits = ContextVault.instance.query(query);
    final List<String> prefHits =
        await PreferencesService.instance.queryPreferences(query);

    final List<String> allHits = <String>[...prefHits, ...vaultHits];

    // When the vault has no matching context, return an empty response
    // rather than reflecting the caller's raw query back through the
    // redaction engine. The redacted-query echo gave the caller an
    // oracle for probing the redaction pipeline and muddied the audit
    // trail (same 'Context query processed' entry for both "vault data
    // returned" and "nothing found").
    if (allHits.isEmpty) {
      final AuditLogEntry emptyAuditEntry = AuditLogEntry(
        logId: _uuid.v4(),
        agentId: token.agentId,
        requestIntent: 'Context query: no vault match',
        actionTaken: AuditAction.redacted,
        timestamp: DateTime.now(),
      );
      await _db.insertAuditEntry(emptyAuditEntry);

      SafeLogger.contextQuery(
        agentId: token.agentId,
        privacyLevel: level.name,
        redactions: 0,
        vaultHits: 0,
      );

      return ContextQueryResult.success(
        sanitizedText: '',
        privacyLevel: level.name,
        redactionsApplied: 0,
        vaultHits: 0,
      );
    }

    final String rawContext = allHits.join(' ');

    final AutoRedactEngine engine = AutoRedactEngine();
    final RedactionResult result = await engine.process(rawContext, level);

    final AuditLogEntry auditEntry = AuditLogEntry(
      logId: _uuid.v4(),
      agentId: token.agentId,
      requestIntent: 'Context query processed',
      actionTaken: AuditAction.redacted,
      timestamp: DateTime.now(),
    );
    await _db.insertAuditEntry(auditEntry);

    SafeLogger.contextQuery(
      agentId: token.agentId,
      privacyLevel: level.name,
      redactions: result.totalRedactions,
      vaultHits: allHits.length,
    );

    return ContextQueryResult.success(
      sanitizedText: result.sanitizedText,
      privacyLevel: level.name,
      redactionsApplied: result.totalRedactions,
      vaultHits: allHits.length,
    );
  }
}
