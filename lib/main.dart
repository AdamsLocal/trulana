import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/logging/safe_logger.dart';
import 'package:trulana/core/network/local_server.dart';
import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/router/app_router.dart';
import 'package:trulana/mcp/mcp_server.dart';
import 'package:trulana/models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _seedDefaultConfig();

  final bool mcpMode = Platform.environment['SOVEREIGN_MCP'] == '1';

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
