import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/network/local_server.dart';
import 'package:trulana/core/services/preferences_service.dart';
import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/router/app_router.dart';
import 'package:trulana/mcp/mcp_server.dart';
import 'package:trulana/models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _seedDefaultConfig();
  await _seedDefaultPreferences();
  await _seedDefaultAgents();
  await _seedDefaultAuditEntries();

  final bool mcpMode =
      Platform.environment['TRULANA_MCP'] == '1' ||
      Platform.environment['SOVEREIGN_MCP'] == '1';

  if (mcpMode) {
    SafeLogger.enableMcpMode();
    await McpServer.run();
  } else {
    await TrulanaServer.instance.start();
    runApp(const ProviderScope(child: TrulanaApp()));
  }
}

/// Ensures a UserConfig row exists on first launch so the privacy
/// level is explicit rather than a null-fallback in route handlers.
Future<void> _seedDefaultConfig() async {
  final DatabaseHelper db = DatabaseHelper.instance;
  final UserConfig? existing = await db.getUserConfig();
  if (existing != null) return;

  await db.insertUserConfig(UserConfig(
    id: const Uuid().v4(),
    privacyLevel: PrivacyLevel.strict,
    vaultStatus: DateTime.now(),
  ));
}

/// Seeds demo preferences on first launch. Skipped if any exist.
Future<void> _seedDefaultPreferences() async {
  final List<Preference> existing =
      await PreferencesService.instance.getAllPreferences();
  if (existing.isNotEmpty) return;

  const Map<String, String> seeds = <String, String>{
    'preferred_coffee': 'Philz, iced mint mojito',
    'response_style': 'concise',
    'commute': 'Caltrain from San Francisco',
    'workout_time': '6:30 AM',
    'work_style': 'deep focus mornings, meetings after 2 PM',
    'diet': 'Dairy-free, Mediterranean',
    'travel_airline': 'Delta, window, SkyMiles',
    'meeting_default': '25 min, agenda-first',
  };

  for (final MapEntry<String, String> entry in seeds.entries) {
    await PreferencesService.instance.setPreference(entry.key, entry.value);
  }
}

/// Seeds demo agents on first launch so the UI isn't empty.
Future<void> _seedDefaultAgents() async {
  final DatabaseHelper db = DatabaseHelper.instance;
  final List<AuthorizedAgent> existing = await db.getAgents();
  if (existing.isNotEmpty) return;

  const Uuid uuid = Uuid();
  final DateTime now = DateTime.now();

  await db.insertAgent(AuthorizedAgent(
    agentId: uuid.v4(),
    agentName: 'cursor-mcp',
    grantedScopes: const ['context.read'],
    status: AgentStatus.active,
    expirationDate: now.add(const Duration(minutes: 12)),
  ));
  await db.insertAgent(AuthorizedAgent(
    agentId: uuid.v4(),
    agentName: 'claude-desktop',
    grantedScopes: const ['context.read'],
    status: AgentStatus.active,
    expirationDate: now.add(const Duration(minutes: 8)),
  ));
  await db.insertAgent(AuthorizedAgent(
    agentId: uuid.v4(),
    agentName: 'demo-agent',
    grantedScopes: const ['context.read'],
    status: AgentStatus.revoked,
    expirationDate: now.subtract(const Duration(minutes: 12)),
  ));
}

/// Seeds demo audit log entries on first launch.
Future<void> _seedDefaultAuditEntries() async {
  final DatabaseHelper db = DatabaseHelper.instance;
  final List<AuditLogEntry> existing = await db.getAuditEntries(limit: 1);
  if (existing.isNotEmpty) return;

  const Uuid uuid = Uuid();
  final DateTime now = DateTime.now();

  final List<AuditLogEntry> seeds = [
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'cursor-mcp',
      requestIntent: 'query "work schedule" \u2192 [PERSON] [EMAIL] [LOCATION] [TIME] stripped \u00b7 7 redactions',
      actionTaken: AuditAction.redacted,
      timestamp: now.subtract(const Duration(minutes: 2)),
    ),
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'claude-desktop',
      requestIntent: 'handshake \u00b7 scopes: [context.read] \u00b7 intent: "code assistance" \u00b7 ttl=900s',
      actionTaken: AuditAction.approved,
      timestamp: now.subtract(const Duration(minutes: 5)),
    ),
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'unknown-app',
      requestIntent: 'no bearer token \u00b7 rejected',
      actionTaken: AuditAction.blocked,
      timestamp: now.subtract(const Duration(minutes: 12)),
    ),
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'cursor-mcp',
      requestIntent: 'query "morning routine" \u2192 [PERSON] [EMAIL] [PHONE] [LOCATION] \u00d72 [ORG] \u00b7 12 redactions',
      actionTaken: AuditAction.redacted,
      timestamp: now.subtract(const Duration(minutes: 18)),
    ),
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'cursor-mcp',
      requestIntent: 'handshake \u00b7 scopes: [context.read] \u00b7 intent: "IDE context" \u00b7 ttl=900s',
      actionTaken: AuditAction.approved,
      timestamp: now.subtract(const Duration(minutes: 19)),
    ),
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'demo-agent',
      requestIntent: 'query "financial info" \u2192 [CARD] [SSN] [AMOUNT] \u00d72 \u00b7 9 redactions',
      actionTaken: AuditAction.redacted,
      timestamp: now.subtract(const Duration(minutes: 32)),
    ),
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'demo-agent',
      requestIntent: 'handshake \u00b7 scopes: [context.read] \u00b7 ttl=900s',
      actionTaken: AuditAction.approved,
      timestamp: now.subtract(const Duration(minutes: 36)),
    ),
    AuditLogEntry(
      logId: uuid.v4(),
      agentId: 'system',
      requestIntent: 'server started \u00b7 vault unlocked \u00b7 REST bound to 127.0.0.1:8432',
      actionTaken: AuditAction.approved,
      timestamp: now.subtract(const Duration(minutes: 49)),
    ),
  ];

  for (final entry in seeds) {
    await db.insertAuditEntry(entry);
  }
}

/// App shell that wires Riverpod state to a GoRouter-driven
/// MaterialApp. All routing decisions (onboarding gate, dashboard
/// redirect) live in [appRouterProvider] so this widget stays thin.
class TrulanaApp extends ConsumerWidget {
  const TrulanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Trulana',
      theme: TrulanaTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
