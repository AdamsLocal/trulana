import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/models/models.dart';

/// Provides the full list of structured user preferences stored in the
/// encrypted local vault.
final preferencesProvider =
    AsyncNotifierProvider<PreferencesNotifier, List<Preference>>(
  PreferencesNotifier.new,
);

class PreferencesNotifier extends AsyncNotifier<List<Preference>> {
  DatabaseHelper get _db => DatabaseHelper.instance;

  @override
  Future<List<Preference>> build() async {
    try {
      return await _db.getAllPreferences();
    } catch (e) {
      debugPrint('[Trulana] preferencesProvider: failed to load preferences: $e');
      return const <Preference>[];
    }
  }
}
