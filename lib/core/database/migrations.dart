import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:trulana/core/database/schema.dart';

/// Handles incremental schema migrations between database versions.
///
/// Version 1 is the baseline — tables are created via [onCreate] in
/// [DatabaseHelper], so no migration logic runs for fresh installs.
class Migrations {
  Migrations._();

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 2:
          await _migrateV1ToV2(db);
          break;
        case 3:
          await _migrateV2ToV3(db);
          break;
        default:
          break;
      }
    }
  }

  static Future<void> _migrateV1ToV2(Database db) async {
    await db.execute(Schema.createPreferences);
  }

  static Future<void> _migrateV2ToV3(Database db) async {
    await db.execute(
      'ALTER TABLE authorized_agents ADD COLUMN mcp_public_key TEXT',
    );
  }
}
