import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/services/preferences_service.dart';

const String _kRequireBiometric = 'settings.require_biometric';
const String _kAutoStartServer = 'settings.auto_start_server';
const String _kMcpAdapter = 'settings.mcp_adapter';

/// Persisted boolean knobs for the Settings view that do not belong in
/// the richer [UserConfig] model (biometric gate, server auto-start, MCP adapter).
///
/// Values are stored as plain-text `'true'`/`'false'` preferences so that
/// [PreferencesService] — which already flows through the redaction pipeline
/// — remains the single source of truth for all app settings.
class AppSettings {
  const AppSettings({
    this.requireBiometric = true,
    this.autoStartServer = true,
    this.mcpAdapter = true,
  });

  final bool requireBiometric;
  final bool autoStartServer;
  final bool mcpAdapter;

  AppSettings copyWith({
    bool? requireBiometric,
    bool? autoStartServer,
    bool? mcpAdapter,
  }) =>
      AppSettings(
        requireBiometric: requireBiometric ?? this.requireBiometric,
        autoStartServer: autoStartServer ?? this.autoStartServer,
        mcpAdapter: mcpAdapter ?? this.mcpAdapter,
      );
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  PreferencesService get _prefs => PreferencesService.instance;

  static bool _parseBool(String? raw, {required bool defaultValue}) =>
      raw == null ? defaultValue : raw == 'true';

  @override
  Future<AppSettings> build() async {
    final biometric = await _prefs.getPreference(_kRequireBiometric);
    final autoStart = await _prefs.getPreference(_kAutoStartServer);
    final mcp = await _prefs.getPreference(_kMcpAdapter);
    return AppSettings(
      requireBiometric: _parseBool(biometric?.value, defaultValue: true),
      autoStartServer: _parseBool(autoStart?.value, defaultValue: true),
      mcpAdapter: _parseBool(mcp?.value, defaultValue: true),
    );
  }

  Future<void> setRequireBiometric(bool value) async {
    await _prefs.setPreference(_kRequireBiometric, value.toString());
    state = AsyncData(state.requireValue.copyWith(requireBiometric: value));
  }

  Future<void> setAutoStartServer(bool value) async {
    await _prefs.setPreference(_kAutoStartServer, value.toString());
    state = AsyncData(state.requireValue.copyWith(autoStartServer: value));
  }

  Future<void> setMcpAdapter(bool value) async {
    await _prefs.setPreference(_kMcpAdapter, value.toString());
    state = AsyncData(state.requireValue.copyWith(mcpAdapter: value));
  }
}
