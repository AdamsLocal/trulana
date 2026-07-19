import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/services/preferences_service.dart';

const String _kRequireBiometric = 'settings.require_biometric';
const String _kAutoStartServer = 'settings.auto_start_server';
const String _kMcpAdapter = 'settings.mcp_adapter';

/// Persisted boolean knobs for the Settings view: biometric gate,
/// server auto-start, MCP adapter.
///
/// Values are stored as plain-text `'true'`/`'false'` preferences so that
/// [PreferencesService] remains the single source of truth for all app
/// settings.
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

  static bool _parseBool(String? raw, {required bool defaultValue}) {
    if (raw == null) return defaultValue;
    return switch (raw.trim().toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => defaultValue,
    };
  }

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
    final previous = state.requireValue;
    state = AsyncData(previous.copyWith(requireBiometric: value));
    try {
      await _prefs.setPreference(_kRequireBiometric, value.toString());
    } catch (_) {
      state = AsyncData(previous);
    }
  }

  Future<void> setAutoStartServer(bool value) async {
    final previous = state.requireValue;
    state = AsyncData(previous.copyWith(autoStartServer: value));
    try {
      await _prefs.setPreference(_kAutoStartServer, value.toString());
    } catch (_) {
      state = AsyncData(previous);
    }
  }

  Future<void> setMcpAdapter(bool value) async {
    final previous = state.requireValue;
    state = AsyncData(previous.copyWith(mcpAdapter: value));
    try {
      await _prefs.setPreference(_kMcpAdapter, value.toString());
    } catch (_) {
      state = AsyncData(previous);
    }
  }
}
