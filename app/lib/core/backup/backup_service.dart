// Backup and restore as one JSON file: every table's rows as stored, plus the
// preferences, except the security settings (PIN, app lock, fingerprint),
// which stay on this device. Document files themselves are not included.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../prefs/app_settings.dart';

/// The file isn't a Daily Life backup this version can read.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// A checked backup, ready to restore.
class Backup {
  const Backup._(this.createdAt, this.tables, this.prefs);

  final DateTime? createdAt;
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, Object?> prefs;

  /// Row count per table, e.g. for tests.
  int rowsIn(String table) => tables[table]?.length ?? 0;
}

class BackupService {
  BackupService(this.db, this.prefs);

  static const format = 'dailylife-backup';
  static const formatVersion = 1;

  final AppDatabase db;
  final SharedPreferences prefs;

  /// Preferences a backup carries: the app's own (`pref.…`), minus the
  /// device-only security settings and the last-backup date.
  static bool backsUp(String key) => key.startsWith('pref.') && !PrefKeys.notBackedUp.contains(key);

  /// The whole database and the preferences as JSON.
  Future<String> export(DateTime now) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in db.allTables) {
      final rows = await db.customSelect('SELECT * FROM "${t.actualTableName}"').get();
      tables[t.actualTableName] = [for (final r in rows) r.data];
    }
    return const JsonEncoder.withIndent(' ').convert({
      'format': format,
      'version': formatVersion,
      'schema': db.schemaVersion,
      'createdAt': now.toIso8601String(),
      'prefs': {
        for (final key in prefs.getKeys().toList()..sort())
          if (backsUp(key)) key: prefs.get(key),
      },
      'tables': tables,
    });
  }

  /// Checks [source] is a backup this version can restore.
  Backup parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException('not JSON');
    }
    if (json is! Map<String, dynamic> || json['format'] != format) throw const BackupFormatException('not a Daily Life backup');
    if (json['version'] != formatVersion) throw BackupFormatException('backup format ${json['version']}');
    if (json['schema'] != db.schemaVersion) throw BackupFormatException('database schema ${json['schema']}');
    final tables = json['tables'];
    final prefsJson = json['prefs'];
    if (tables is! Map<String, dynamic> || prefsJson is! Map<String, dynamic>) throw const BackupFormatException('missing tables or prefs');
    final known = {for (final t in db.allTables) t.actualTableName};
    final out = <String, List<Map<String, Object?>>>{};
    for (final MapEntry(:key, :value) in tables.entries) {
      if (!known.contains(key)) continue;
      if (value is! List || value.any((r) => r is! Map<String, dynamic>)) throw BackupFormatException('bad rows in $key');
      out[key] = [for (final r in value) (r as Map<String, dynamic>).cast<String, Object?>()];
    }
    return Backup._(DateTime.tryParse('${json['createdAt']}'), out, prefsJson.cast<String, Object?>());
  }

  /// Replaces every table and the backed-up preferences with [backup]. The
  /// tables change in one transaction: if any row doesn't fit, nothing changes.
  /// A document whose file isn't on this phone ([fileExists]) keeps only its
  /// details, like the sample documents.
  Future<void> restore(Backup backup, {required Future<bool> Function(String path) fileExists}) async {
    // Checked before the transaction: file IO doesn't belong inside it.
    final missing = <String>{};
    for (final row in backup.tables[db.documents.actualTableName] ?? const <Map<String, Object?>>[]) {
      final path = row['file_path'];
      if (path is String && !await fileExists(path)) missing.add(path);
    }
    await db.transaction(() async {
      // Rows go in table order; foreign keys are checked once, at commit.
      await db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final t in db.allTables.toList().reversed) {
        await db.customStatement('DELETE FROM "${t.actualTableName}"');
      }
      for (final t in db.allTables) {
        final columns = {for (final c in t.$columns) c.name};
        for (final row in backup.tables[t.actualTableName] ?? const <Map<String, Object?>>[]) {
          final keys = [for (final k in row.keys) if (columns.contains(k)) k];
          if (keys.isEmpty) continue;
          Object? value(String k) => k == 'file_path' && missing.contains(row[k]) ? null : row[k];
          await db.customStatement(
            'INSERT INTO "${t.actualTableName}" (${keys.map((k) => '"$k"').join(', ')}) VALUES (${List.filled(keys.length, '?').join(', ')})',
            [for (final k in keys) value(k)],
          );
        }
      }
      // The single salary-settings and timer rows always exist.
      await db.into(db.salarySettings).insert(const SalarySettingsCompanion(id: Value(1)), mode: InsertMode.insertOrIgnore);
      await db.into(db.timerSessions).insert(const TimerSessionsCompanion(id: Value(1), state: Value(TimerState.idle)), mode: InsertMode.insertOrIgnore);
    });
    db.notifyUpdates({for (final t in db.allTables) TableUpdate.onTable(t)});

    for (final key in prefs.getKeys().toList()) {
      if (backsUp(key)) await prefs.remove(key);
    }
    for (final MapEntry(:key, :value) in backup.prefs.entries) {
      if (!backsUp(key)) continue;
      switch (value) {
        case bool v:
          await prefs.setBool(key, v);
        case int v:
          await prefs.setInt(key, v);
        case double v:
          await prefs.setDouble(key, v);
        case String v:
          await prefs.setString(key, v);
        case List<dynamic> v:
          await prefs.setStringList(key, [for (final s in v) '$s']);
      }
    }
  }
}
