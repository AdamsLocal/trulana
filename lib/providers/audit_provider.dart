import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sovereign/core/database/database_helper.dart';
import 'package:sovereign/models/models.dart';

/// Exposes the Gatekeeper audit trail with infinite-scroll pagination.
final auditProvider =
    AsyncNotifierProvider<AuditNotifier, List<AuditLogEntry>>(
  AuditNotifier.new,
);

class AuditNotifier extends AsyncNotifier<List<AuditLogEntry>> {
  static const int _pageSize = 50;

  DatabaseHelper get _db => DatabaseHelper.instance;

  /// Tracks how many entries have been fetched so far for offset pagination.
  int _loadedCount = 0;

  @override
  Future<List<AuditLogEntry>> build() async {
    _loadedCount = 0;
    try {
      final List<AuditLogEntry> entries = await _db.getAuditEntries(
        limit: _pageSize,
        offset: 0,
      );
      _loadedCount = entries.length;
      return entries;
    } catch (_) {
      return const <AuditLogEntry>[];
    }
  }

  Future<void> logEntry(AuditLogEntry entry) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.insertAuditEntry(entry);
      _loadedCount = 0;
      final List<AuditLogEntry> entries = await _db.getAuditEntries(
        limit: _pageSize,
        offset: 0,
      );
      _loadedCount = entries.length;
      return entries;
    });
  }

  /// Appends the next page of entries without discarding existing ones.
  Future<void> loadMore() async {
    final List<AuditLogEntry> current = state.valueOrNull ?? const [];
    state = await AsyncValue.guard(() async {
      final List<AuditLogEntry> next = await _db.getAuditEntries(
        limit: _pageSize,
        offset: _loadedCount,
      );
      _loadedCount += next.length;
      return [...current, ...next];
    });
  }
}
