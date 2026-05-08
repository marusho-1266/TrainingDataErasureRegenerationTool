import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite for scan metadata (paths under app documents).
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'erasure.db';
  static const _version = 1;

  Database? _db;

  /// Shared open future: concurrent [ready] awaits the same work; see [_doOpenDatabase].
  Future<void>? _initFuture;

  /// Ensures [openDatabase], [onCreate], and [_db] assignment ran once (per successful attempt).
  /// Failures clear [_initFuture] so a later call may retry; errors surface to awaiters (same as [Completer.completeError]).
  Future<void> ready() async {
    if (_initFuture != null) {
      await _initFuture!;
      return;
    }
    final fut = _doOpenDatabase();
    _initFuture = fut;
    try {
      await fut;
    } catch (e, st) {
      if (identical(_initFuture, fut)) {
        _initFuture = null;
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> _doOpenDatabase() async {
    late final String dbPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, _dbName);
    } catch (e, st) {
      Error.throwWithStackTrace(
        StateError(
            'AppDatabase: path resolution failed before openDatabase: $e'),
        st,
      );
    }
    try {
      _db = await openDatabase(
        dbPath,
        version: _version,
        onCreate: (db, _) async {
          await db.execute('''
CREATE TABLE scans (
  id TEXT PRIMARY KEY NOT NULL,
  source_path TEXT NOT NULL,
  thumbnail_path TEXT,
  created_at INTEGER NOT NULL
);
''');
        },
      );
    } catch (e, st) {
      _db = null;
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Database> get database async {
    await ready();
    final db = _db;
    if (db == null) {
      throw StateError(
        'SQLite database not initialized: _db is null after ready(); '
        'openDatabase likely failed silently or logic regressed.',
      );
    }
    return db;
  }
}
