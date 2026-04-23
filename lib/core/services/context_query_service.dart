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
    final PrivacyLevel configuredLevel =
        userConfig?.privacyLevel ?? PrivacyLevel.strict;

    // The NER stage uses keyword dictionaries (MVP phase). Enforce a minimum
    // of strict so the privacy filter's time/amount/age rules always apply,
    // compensating for entities the mock NER cannot catch. When a production
    // NER is available this floor can be relaxed.
    final PrivacyLevel level = configuredLevel.value >= PrivacyLevel.strict.value
        ? configuredLevel
        : PrivacyLevel.strict;

    final List<String> vaultHits = ContextVault.instance.query(query);
    final List<String> prefHits =
        await PreferencesService.instance.queryPreferences(query);

    final List<String> allHits = <String>[...prefHits, ...vaultHits];
    final String rawContext =
        allHits.isNotEmpty ? allHits.join(' ') : query;

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
