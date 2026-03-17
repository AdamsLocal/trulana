import 'package:uuid/uuid.dart';

/// Immutable representation of a scoped access token issued to a
/// third-party agent by the Gatekeeper Protocol.
///
/// Tokens are short-lived by design (default 15 min) — this limits
/// the blast radius if a token is ever exfiltrated from an agent's
/// memory space.
class AccessToken {
  final String token;
  final String agentId;
  final List<String> grantedScopes;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  const AccessToken({
    required this.token,
    required this.agentId,
    required this.grantedScopes,
    required this.expiresAt,
    required this.createdAt,
  });
}

/// In-memory token store with TTL enforcement, scope validation,
/// and per-agent mass revocation.
///
/// Held in RAM intentionally — tokens must not survive an app restart
/// so that every session starts with a clean auth slate. This is a
/// security property, not a limitation.
class TokenManager {
  TokenManager._();
  static final TokenManager instance = TokenManager._();

  static const Uuid _uuid = Uuid();

  final Map<String, AccessToken> _tokens = <String, AccessToken>{};

  /// Creates a new scoped access token for [agentId].
  ///
  /// Callers decide which scopes to grant (post-user-approval in
  /// production; auto-approved in the MVP). The default 15-minute TTL
  /// keeps the window of exposure small while still being usable for
  /// multi-step agent workflows.
  String generateToken({
    required String agentId,
    required List<String> scopes,
    Duration ttl = const Duration(minutes: 15),
  }) {
    final DateTime now = DateTime.now();
    final String tokenString = _uuid.v4();

    final AccessToken accessToken = AccessToken(
      token: tokenString,
      agentId: agentId,
      grantedScopes: List<String>.unmodifiable(scopes),
      expiresAt: now.add(ttl),
      createdAt: now,
    );

    _tokens[tokenString] = accessToken;
    return tokenString;
  }

  /// Validates a raw token string and returns the [AccessToken] if it
  /// exists and has not expired; `null` otherwise.
  ///
  /// Expired tokens are eagerly evicted on lookup so they cannot be
  /// reused after clock correction.
  AccessToken? validateToken(String tokenString) {
    final AccessToken? token = _tokens[tokenString];
    if (token == null) return null;

    if (token.isExpired) {
      _tokens.remove(tokenString);
      return null;
    }

    return token;
  }

  /// Returns `true` when [tokenString] maps to a valid, non-expired
  /// token that includes [scope] in its grant list.
  bool hasScope(String tokenString, String scope) {
    final AccessToken? token = validateToken(tokenString);
    if (token == null) return false;
    return token.grantedScopes.contains(scope);
  }

  /// Immediately invalidates a single token so it can no longer pass
  /// validation — used when an agent explicitly logs out or the user
  /// revokes access from the dashboard.
  void revokeToken(String tokenString) {
    _tokens.remove(tokenString);
  }

  /// Revokes every outstanding token for [agentId].
  ///
  /// Called when the user kills an agent's access from the Gatekeeper
  /// dashboard or when the agent's DB record is set to `revoked`.
  void revokeAgentTokens(String agentId) {
    _tokens.removeWhere(
      (String _, AccessToken token) => token.agentId == agentId,
    );
  }

  /// Evicts all expired tokens from the store.
  ///
  /// Should be called periodically (e.g. via a Timer) to prevent
  /// unbounded memory growth if many agents request tokens over time.
  void purgeExpired() {
    _tokens.removeWhere(
      (String _, AccessToken token) => token.isExpired,
    );
  }
}
