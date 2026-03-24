import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:trulana/core/database/schema.dart';

/// Handles incremental schema migrations between database versions.
///
/// Version 1 is the baseline — tables are created via [onCreate] in
/// [DatabaseHelper], so no migration logic runs for fresh installs.
/// Future versions add cases to the switch block so upgrades are applied
/// sequentially (e.g. v1->v2, then v2->v3) even if the user skips releases.
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
        default:
          break;
      }
    }
  }

  static Future<void> _migrateV1ToV2(Database db) async {
    await db.execute(Schema.createPreferences);
  }
}
