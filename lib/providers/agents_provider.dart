import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/models/models.dart';

/// Provides the full agent roster and mutation methods for the
/// Gatekeeper dashboard.
final agentsProvider =
    AsyncNotifierProvider<AgentsNotifier, List<AuthorizedAgent>>(
  AgentsNotifier.new,
);

class AgentsNotifier extends AsyncNotifier<List<AuthorizedAgent>> {
  DatabaseHelper get _db => DatabaseHelper.instance;

  @override
  Future<List<AuthorizedAgent>> build() async {
    try {
      return await _db.getAgents();
    } catch (_) {
      return const <AuthorizedAgent>[];
    }
  }

  Future<void> addAgent(AuthorizedAgent agent) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.insertAgent(agent);
      return _db.getAgents();
    });
  }

  Future<void> updateAgent(AuthorizedAgent agent) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.updateAgent(agent);
      return _db.getAgents();
    });
  }

  /// Marks a single agent as revoked while preserving its audit trail.
  Future<void> revokeAgent(String agentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final AuthorizedAgent? existing = await _db.getAgentById(agentId);
      if (existing != null) {
        await _db.updateAgent(
          existing.copyWith(status: AgentStatus.revoked),
        );
      }
      return _db.getAgents();
    });
  }

  /// Emergency kill-switch: revokes every active agent atomically.
  Future<void> revokeAll() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.revokeAllAgents();
      return _db.getAgents();
    });
  }

  /// Convenience accessor filtered to active agents only.
  Future<List<AuthorizedAgent>> getActiveAgents() async {
    try {
      return await _db.getAgents(filterStatus: AgentStatus.active);
    } catch (_) {
      return const <AuthorizedAgent>[];
    }
  }
}
