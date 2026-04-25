/// Privacy level tiers that control the Auto-Redact Engine's aggressiveness.
/// Stored as integers in SQLite for compact, indexed storage.
enum PrivacyLevel {
  standard(1),
  strict(2),
  paranoid(3);

  const PrivacyLevel(this.value);

  final int value;

  /// Reconstitutes from the integer stored in the database column.
  static PrivacyLevel fromValue(int value) => switch (value) {
        1 => PrivacyLevel.standard,
        2 => PrivacyLevel.strict,
        3 => PrivacyLevel.paranoid,
        _ => throw ArgumentError('Unknown PrivacyLevel value: $value'),
      };
}

/// Lifecycle state of a third-party agent's access grant.
/// Stored as lowercase strings so SQLite queries remain human-readable.
enum AgentStatus {
  pending('pending'),
  active('active'),
  revoked('revoked'),
  paused('paused');

  const AgentStatus(this.value);

  final String value;

  static AgentStatus fromValue(String value) => switch (value) {
        'pending' => AgentStatus.pending,
        'active' => AgentStatus.active,
        'revoked' => AgentStatus.revoked,
        'paused' => AgentStatus.paused,
        _ => throw ArgumentError('Unknown AgentStatus value: $value'),
      };
}

/// Gatekeeper decisions recorded in the audit log.
/// Each value maps to a lowercase string for SQLite storage.
enum AuditAction {
  approved('approved'),
  blocked('blocked'),
  redacted('redacted'),
  negotiated('negotiated');

  const AuditAction(this.value);

  final String value;

  static AuditAction fromValue(String value) => switch (value) {
        'approved' => AuditAction.approved,
        'blocked' => AuditAction.blocked,
        'redacted' => AuditAction.redacted,
        'negotiated' => AuditAction.negotiated,
        _ => throw ArgumentError('Unknown AuditAction value: $value'),
      };
}
