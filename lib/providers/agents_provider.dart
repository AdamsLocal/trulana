import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/models/models.dart';

const Uuid _uuid = Uuid();

/// Outcome of an approve or reject mutation. Callers (UI + tests)
/// can distinguish silent no-ops (agent not pending, not found) from
/// an actual state transition so the UI never implies approval when
/// none happened.
enum AgentMutationResult {
  success,
  notFound,
  notPending,
  invalidScopes,
}

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

  /// Promotes a pending agent to `active` with the scopes the user
  /// explicitly approved. The caller must supply [approvedScopes] —
  /// this method intentionally does not read the agent's originally
  /// requested scopes to guarantee that a user action is required
  /// for every bit of privilege granted.
  ///
  /// Returns [AgentMutationResult.notPending] (no state change) if the
  /// agent is not currently pending — preventing silent reactivation
  /// of a revoked or paused agent through the approval flow.
  Future<AgentMutationResult> approveAgent(
    String agentId, {
    required List<String> approvedScopes,
  }) async {
    if (approvedScopes.isEmpty) {
      return AgentMutationResult.invalidScopes;
    }

    final AuthorizedAgent? existing = await _db.getAgentById(agentId);
    if (existing == null) {
      return AgentMutationResult.notFound;
    }
    if (existing.status != AgentStatus.pending) {
      return AgentMutationResult.notPending;
    }

    // Ensure the approved set is a subset of the originally requested
    // set — the user narrows scopes; they never escalate beyond what
    // the agent asked for.
    final Set<String> requested = existing.grantedScopes.toSet();
    final List<String> narrowed = approvedScopes
        .where(requested.contains)
        .toList(growable: false);
    if (narrowed.isEmpty) {
      return AgentMutationResult.invalidScopes;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.updateAgent(
        existing.copyWith(
          status: AgentStatus.active,
          grantedScopes: narrowed,
        ),
      );

      await _db.insertAuditEntry(
        AuditLogEntry(
          logId: _uuid.v4(),
          agentId: agentId,
          requestIntent: 'User approved with scopes: ${narrowed.join(', ')}',
          actionTaken: AuditAction.approved,
          timestamp: DateTime.now(),
        ),
      );

      return _db.getAgents();
    });

    return AgentMutationResult.success;
  }

  /// Denies a pending access request. Sets the agent record to
  /// `revoked` (so the same appId cannot silently re-enter the
  /// pending pool) and invalidates any tokens that may somehow be
  /// outstanding for that agent as defence-in-depth.
  Future<AgentMutationResult> rejectAgent(String agentId) async {
    final AuthorizedAgent? existing = await _db.getAgentById(agentId);
    if (existing == null) {
      return AgentMutationResult.notFound;
    }
    if (existing.status != AgentStatus.pending) {
      return AgentMutationResult.notPending;
    }

    // Revoke tokens FIRST so the rejection takes effect before the
    // UI refetches — and independently of DB write success.
    TokenManager.instance.revokeAgentTokens(agentId);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.updateAgent(
        existing.copyWith(status: AgentStatus.revoked),
      );

      await _db.insertAuditEntry(
        AuditLogEntry(
          logId: _uuid.v4(),
          agentId: agentId,
          requestIntent: 'User rejected access request',
          actionTaken: AuditAction.blocked,
          timestamp: DateTime.now(),
        ),
      );

      return _db.getAgents();
    });

    return AgentMutationResult.success;
  }
}
