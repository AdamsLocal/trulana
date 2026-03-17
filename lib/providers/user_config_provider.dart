import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/models/models.dart';

/// Drives the onboarding-vs-dashboard redirect and every screen that
/// reads or mutates the vault owner's configuration.
final userConfigProvider =
    AsyncNotifierProvider<UserConfigNotifier, UserConfig?>(
  UserConfigNotifier.new,
);

class UserConfigNotifier extends AsyncNotifier<UserConfig?> {
  DatabaseHelper get _db => DatabaseHelper.instance;

  @override
  Future<UserConfig?> build() async {
    try {
      return await _db.getUserConfig();
    } catch (_) {
      return null;
    }
  }

  /// Persists a new or existing config (upsert via REPLACE).
  Future<void> saveConfig(UserConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.insertUserConfig(config);
      return config;
    });
  }

  Future<void> updatePrivacyLevel(PrivacyLevel level) async {
    final UserConfig? current = state.valueOrNull;
    if (current == null) return;

    final UserConfig updated = current.copyWith(privacyLevel: level);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.updateUserConfig(updated);
      return updated;
    });
  }

  Future<void> toggleAutoMonetize() async {
    final UserConfig? current = state.valueOrNull;
    if (current == null) return;

    final UserConfig updated =
        current.copyWith(autoMonetize: !current.autoMonetize);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.updateUserConfig(updated);
      return updated;
    });
  }

  /// Pass `null` to clear the wallet address entirely.
  Future<void> updateWalletAddress(String? address) async {
    final UserConfig? current = state.valueOrNull;
    if (current == null) return;

    final UserConfig updated = current.copyWith(walletAddress: address);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.updateUserConfig(updated);
      return updated;
    });
  }
}
