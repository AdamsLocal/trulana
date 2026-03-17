/// Centralised DDL definitions for the encrypted Trulana database.
///
/// Keeping all table schemas in one place makes it trivial to audit column
/// names, types, and constraints during security reviews — and ensures
/// [DatabaseHelper] and [Migrations] never disagree on structure.
class Schema {
  Schema._();

  static const int version = 1;
  static const String databaseName = 'trulana.db';

  static const String createUserConfig = '''
    CREATE TABLE user_config (
      id              TEXT    PRIMARY KEY,
      privacy_level   INTEGER DEFAULT 1,
      auto_monetize   INTEGER DEFAULT 0,
      wallet_address  TEXT,
      vault_status    TEXT
    )
  ''';

  static const String createAuthorizedAgents = '''
    CREATE TABLE authorized_agents (
      agent_id        TEXT PRIMARY KEY,
      agent_name      TEXT NOT NULL,
      granted_scopes  TEXT NOT NULL,
      status          TEXT NOT NULL DEFAULT 'active',
      expiration_date TEXT NOT NULL
    )
  ''';

  static const String createAuditLog = '''
    CREATE TABLE audit_log (
      log_id          TEXT PRIMARY KEY,
      agent_id        TEXT NOT NULL,
      request_intent  TEXT NOT NULL,
      action_taken    TEXT NOT NULL,
      timestamp       TEXT NOT NULL,
      FOREIGN KEY (agent_id) REFERENCES authorized_agents(agent_id)
    )
  ''';

  static const String createLedger = '''
    CREATE TABLE ledger (
      tx_id       TEXT PRIMARY KEY,
      buyer_name  TEXT NOT NULL,
      data_leased TEXT NOT NULL,
      amount_usd  REAL NOT NULL,
      timestamp   TEXT NOT NULL
    )
  ''';
}
