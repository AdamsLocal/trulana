import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:sovereign/core/database/migrations.dart';
import 'package:sovereign/core/database/schema.dart';
import 'package:sovereign/core/security/key_manager.dart';
import 'package:sovereign/models/models.dart';

/// Singleton gateway to the encrypted Sovereign database.
///
/// All reads and writes flow through this class so the encryption key is
/// resolved exactly once per session, and every operation is wrapped in
/// try/catch to prevent unhandled SQLite exceptions from propagating to
/// the UI layer.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  /// Lazily opens (and encrypts) the database on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String dbPath = p.join(await getDatabasesPath(), Schema.databaseName);
    final String key = await KeyManager.instance.getOrCreateDatabaseKey();

    return openDatabase(
      dbPath,
      version: Schema.version,
      password: key,
      onCreate: (Database db, int version) async {
        await db.execute(Schema.createUserConfig);
        await db.execute(Schema.createAuthorizedAgents);
        await db.execute(Schema.createAuditLog);
        await db.execute(Schema.createLedger);
      },
      onUpgrade: Migrations.migrate,
    );
  }

  // ---------------------------------------------------------------------------
  // UserConfig CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertUserConfig(UserConfig config) async {
    try {
      final Database db = await database;
      return await db.insert(
        'user_config',
        config.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      return -1;
    }
  }

  /// Returns the single user configuration row, or `null` on a fresh install.
  Future<UserConfig?> getUserConfig() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        'user_config',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return UserConfig.fromMap(rows.first);
    } catch (e) {
      return null;
    }
  }

  Future<int> updateUserConfig(UserConfig config) async {
    try {
      final Database db = await database;
      return await db.update(
        'user_config',
        config.toMap(),
        where: 'id = ?',
        whereArgs: [config.id],
      );
    } catch (e) {
      return -1;
    }
  }

  Future<int> deleteUserConfig(String id) async {
    try {
      final Database db = await database;
      return await db.delete(
        'user_config',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      return -1;
    }
  }

  // ---------------------------------------------------------------------------
  // AuthorizedAgent CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertAgent(AuthorizedAgent agent) async {
    try {
      final Database db = await database;
      return await db.insert(
        'authorized_agents',
        agent.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      return -1;
    }
  }

  /// Retrieves agents, optionally filtered by [filterStatus].
  Future<List<AuthorizedAgent>> getAgents({AgentStatus? filterStatus}) async {
    try {
      final Database db = await database;

      final List<Map<String, dynamic>> rows;
      if (filterStatus != null) {
        rows = await db.query(
          'authorized_agents',
          where: 'status = ?',
          whereArgs: [filterStatus.value],
        );
      } else {
        rows = await db.query('authorized_agents');
      }

      return rows.map(AuthorizedAgent.fromMap).toList();
    } catch (e) {
      return [];
    }
  }

  Future<AuthorizedAgent?> getAgentById(String agentId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        'authorized_agents',
        where: 'agent_id = ?',
        whereArgs: [agentId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AuthorizedAgent.fromMap(rows.first);
    } catch (e) {
      return null;
    }
  }

  Future<int> updateAgent(AuthorizedAgent agent) async {
    try {
      final Database db = await database;
      return await db.update(
        'authorized_agents',
        agent.toMap(),
        where: 'agent_id = ?',
        whereArgs: [agent.agentId],
      );
    } catch (e) {
      return -1;
    }
  }

  Future<int> deleteAgent(String agentId) async {
    try {
      final Database db = await database;
      return await db.delete(
        'authorized_agents',
        where: 'agent_id = ?',
        whereArgs: [agentId],
      );
    } catch (e) {
      return -1;
    }
  }

  /// Atomically revokes every active agent — used when the user hits the
  /// emergency "kill all access" button in the Gatekeeper dashboard.
  Future<int> revokeAllAgents() async {
    try {
      final Database db = await database;
      return await db.update(
        'authorized_agents',
        {'status': AgentStatus.revoked.value},
        where: 'status = ?',
        whereArgs: [AgentStatus.active.value],
      );
    } catch (e) {
      return -1;
    }
  }

  // ---------------------------------------------------------------------------
  // AuditLog CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertAuditEntry(AuditLogEntry entry) async {
    try {
      final Database db = await database;
      return await db.insert(
        'audit_log',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      return -1;
    }
  }

  /// Returns audit entries newest-first with cursor-based pagination.
  Future<List<AuditLogEntry>> getAuditEntries({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        'audit_log',
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map(AuditLogEntry.fromMap).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<AuditLogEntry>> getAuditEntriesByAgent(String agentId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        'audit_log',
        where: 'agent_id = ?',
        whereArgs: [agentId],
        orderBy: 'timestamp DESC',
      );
      return rows.map(AuditLogEntry.fromMap).toList();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Ledger CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertLedgerEntry(LedgerEntry entry) async {
    try {
      final Database db = await database;
      return await db.insert(
        'ledger',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      return -1;
    }
  }

  /// Returns ledger entries newest-first with cursor-based pagination.
  Future<List<LedgerEntry>> getLedgerEntries({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        'ledger',
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map(LedgerEntry.fromMap).toList();
    } catch (e) {
      return [];
    }
  }

  /// Aggregate lifetime earnings across all ledger transactions.
  Future<double> getTotalEarnings() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_usd), 0.0) AS total FROM ledger',
      );
      final dynamic raw = result.first['total'];
      if (raw is num) return raw.toDouble();
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Placeholder query — treats any positive-amount entry as a pending lease
  /// until a dedicated status column is introduced.
  Future<List<LedgerEntry>> getPendingLeases() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> rows = await db.query(
        'ledger',
        where: 'amount_usd > 0',
        orderBy: 'timestamp DESC',
      );
      return rows.map(LedgerEntry.fromMap).toList();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Gracefully closes the database connection (e.g. before app termination).
  Future<void> close() async {
    try {
      final Database db = await database;
      await db.close();
      _database = null;
    } catch (_) {
      _database = null;
    }
  }

  /// Irreversibly destroys the database file — intended only for account
  /// deletion or factory-reset flows.
  Future<void> deleteDatabase() async {
    try {
      await close();
      final String dbPath = p.join(
        await getDatabasesPath(),
        Schema.databaseName,
      );
      await databaseFactory.deleteDatabase(dbPath);
    } catch (_) {
      // Deletion is best-effort; the file may already be gone.
    }
  }
}
