/// A single open escrow commitment held server-side between a lease
/// offer and its settlement.
///
/// At offer time the server commits to [payload] by publishing [hash]
/// (= SHA-256 of `salt:payload`) to the requesting agent while keeping
/// [salt] secret. The salt is revealed only once a settlement token
/// clears, at which point the agent can recompute the hash and confirm
/// the server did not alter the payload between offer and settlement.
class EscrowCommitment {
  final String offerId;
  final String hash;
  final String salt;
  final String payload;
  final DateTime createdAt;

  const EscrowCommitment({
    required this.offerId,
    required this.hash,
    required this.salt,
    required this.payload,
    required this.createdAt,
  });
}

/// In-memory store of open escrow commitments, keyed by offer id.
///
/// Held in RAM by design: like access tokens, an un-settled commitment
/// must not survive a process restart, and the withheld salt must never
/// be persisted to disk where it could be read without going through
/// settlement. Entries are removed on settlement (one-time reveal).
class CommitmentStore {
  CommitmentStore._();
  static final CommitmentStore instance = CommitmentStore._();

  final Map<String, EscrowCommitment> _byOfferId =
      <String, EscrowCommitment>{};

  /// Records [commitment] so it can be revealed at settlement time.
  void put(EscrowCommitment commitment) {
    _byOfferId[commitment.offerId] = commitment;
  }

  /// Returns the open commitment for [offerId], or `null` if there is
  /// none (unknown id, or already settled).
  EscrowCommitment? get(String offerId) => _byOfferId[offerId];

  /// Removes and returns the commitment for [offerId] so the same offer
  /// cannot be settled twice. Returns `null` if it was not present.
  EscrowCommitment? take(String offerId) => _byOfferId.remove(offerId);

  /// Number of open (un-settled) commitments. Exposed for diagnostics
  /// and tests.
  int get openCount => _byOfferId.length;

  /// Drops every open commitment. Test/maintenance hook.
  void clear() => _byOfferId.clear();
}
