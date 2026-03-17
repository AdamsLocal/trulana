import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sovereign/core/database/database_helper.dart';
import 'package:sovereign/models/models.dart';

/// Provides the monetisation ledger for the Data Monetization Hub.
final ledgerProvider =
    AsyncNotifierProvider<LedgerNotifier, List<LedgerEntry>>(
  LedgerNotifier.new,
);

/// Aggregated lifetime earnings — consumed by the dashboard header.
final totalEarningsProvider = FutureProvider<double>((Ref ref) async {
  try {
    return await DatabaseHelper.instance.getTotalEarnings();
  } catch (_) {
    return 0.0;
  }
});

class LedgerNotifier extends AsyncNotifier<List<LedgerEntry>> {
  DatabaseHelper get _db => DatabaseHelper.instance;

  @override
  Future<List<LedgerEntry>> build() async {
    try {
      return await _db.getLedgerEntries();
    } catch (_) {
      return const <LedgerEntry>[];
    }
  }

  Future<void> addEntry(LedgerEntry entry) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.insertLedgerEntry(entry);
      ref.invalidate(totalEarningsProvider);
      return _db.getLedgerEntries();
    });
  }
}
