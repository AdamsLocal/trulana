import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/services/preferences_service.dart';
import 'package:trulana/models/models.dart';

/// Provides the full list of user preferences and mutation methods.
final preferencesProvider =
    AsyncNotifierProvider<PreferencesNotifier, List<Preference>>(
  PreferencesNotifier.new,
);

class PreferencesNotifier extends AsyncNotifier<List<Preference>> {
  @override
  Future<List<Preference>> build() async {
    return PreferencesService.instance.getAllPreferences();
  }

  Future<void> add(String key, String value) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await PreferencesService.instance.setPreference(key, value);
      return PreferencesService.instance.getAllPreferences();
    });
  }

  Future<void> update(String key, String newValue) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await PreferencesService.instance.setPreference(key, newValue);
      return PreferencesService.instance.getAllPreferences();
    });
  }

  Future<void> delete(String key) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await PreferencesService.instance.deletePreference(key);
      return PreferencesService.instance.getAllPreferences();
    });
  }
}
