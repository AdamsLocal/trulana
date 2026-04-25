import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/core/network/token_manager.dart';
import 'package:trulana/providers/agents_provider.dart';

/// Defensive-path tests for [AgentsNotifier.approveAgent] / [rejectAgent].
///
/// The happy path (promote pending -> active, narrow scopes, write audit
/// log, refresh state) depends on `DatabaseHelper` / `sqflite_sqlcipher`,
/// which has no host-side plugin in `flutter test`. These tests cover
/// the validation branches that do not require DB persistence:
///
///   - empty scope list -> invalidScopes
///   - agent not found  -> notFound
///   - agent not pending (in test env every lookup returns null) -> notFound
///   - reject side effect: TokenManager.revokeAgentTokens is guarded by
///     the same "is pending" precondition, so the side effect must NOT
///     fire for a non-pending agent
///
/// Full happy-path coverage is tracked under "Known Test Coverage Gaps"
/// in the audit report.
void main() {
  group('approveAgent defensive paths', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('empty approvedScopes is rejected without touching state',
        () async {
      final AgentsNotifier notifier =
          container.read(agentsProvider.notifier);

      final AgentMutationResult result = await notifier.approveAgent(
        'any-agent',
        approvedScopes: const <String>[],
      );

      expect(result, AgentMutationResult.invalidScopes);
    });

    test('non-existent agent returns notFound', () async {
      final AgentsNotifier notifier =
          container.read(agentsProvider.notifier);

      final AgentMutationResult result = await notifier.approveAgent(
        'ghost-agent-${DateTime.now().microsecondsSinceEpoch}',
        approvedScopes: <String>['context.read'],
      );

      // In the test env DatabaseHelper.getAgentById silently returns
      // null (no sqflite_sqlcipher plugin), so every lookup is a miss.
      expect(result, AgentMutationResult.notFound);
    });
  });

  group('rejectAgent defensive paths', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('non-existent agent returns notFound', () async {
      final AgentsNotifier notifier =
          container.read(agentsProvider.notifier);

      final AgentMutationResult result = await notifier.rejectAgent(
        'ghost-agent-${DateTime.now().microsecondsSinceEpoch}',
      );

      expect(result, AgentMutationResult.notFound);
    });

    test('rejection does NOT revoke tokens for non-pending agents',
        () async {
      // Mint a token for an agent that is not in a pending state (in
      // test env, no agent is ever in a pending state because DB is
      // inert). If rejectAgent incorrectly revoked tokens before the
      // status check, this token would be invalidated.
      final String tokenString = TokenManager.instance.generateToken(
        agentId: 'non-pending-agent',
        scopes: <String>['context.read'],
      );

      final AgentsNotifier notifier =
          container.read(agentsProvider.notifier);

      final AgentMutationResult result =
          await notifier.rejectAgent('non-pending-agent');

      expect(result, AgentMutationResult.notFound);

      // The token must still validate — rejectAgent must short-circuit
      // before calling TokenManager.revokeAgentTokens when the agent
      // is not pending.
      final AccessToken? stillValid =
          TokenManager.instance.validateToken(tokenString);
      expect(stillValid, isNotNull);
      expect(stillValid!.agentId, 'non-pending-agent');
    });
  });

  group('AgentMutationResult contract', () {
    test('enum has all four outcomes', () {
      expect(AgentMutationResult.values, <AgentMutationResult>[
        AgentMutationResult.success,
        AgentMutationResult.notFound,
        AgentMutationResult.notPending,
        AgentMutationResult.invalidScopes,
      ]);
    });
  });
}
