import 'dart:developer' show log;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:training_data_erasure/data/app_database.dart';

class ScanRecord {
  ScanRecord({
    required this.id,
    required this.sourcePath,
    this.thumbnailPath,
    required this.createdAt,
  });

  final String id;
  final String sourcePath;
  final String? thumbnailPath;
  final DateTime createdAt;
}

/// Persists scanned page files into app sandbox and SQLite metadata.
class ScanRepository {
  ScanRepository(this._db);

  final AppDatabase _db;
  static final Uuid _uuid = Uuid();

  Future<List<ScanRecord>> listRecent({int limit = 50}) async {
    final database = await _db.database;
    final rows = await database.query(
      'scans',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    final out = <ScanRecord>[];
    for (final raw in rows) {
      final m = Map<String, Object?>.from(raw);
      final record = _scanRecordFromRow(m);
      if (record != null) out.add(record);
    }
    return out;
  }

  /// Returns null and logs if required columns are missing or wrong type (schema drift / corruption).
  static ScanRecord? _scanRecordFromRow(Map<String, Object?> m) {
    final idRaw = m['id'];
    final pathRaw = m['source_path'];
    final createdRaw = m['created_at'];
    final thumbRaw = m['thumbnail_path'];

    if (idRaw is! String || idRaw.isEmpty) {
      log(
        'skipped scan row: invalid id ($idRaw)',
        name: 'ScanRepository',
        error: m,
      );
      return null;
    }
    if (pathRaw is! String || pathRaw.isEmpty) {
      log(
        'skipped scan row: invalid source_path ($pathRaw)',
        name: 'ScanRepository',
        error: m,
      );
      return null;
    }

    final int millis;
    if (createdRaw is int) {
      millis = createdRaw;
    } else if (createdRaw is num) {
      millis = createdRaw.round();
    } else {
      log(
        'skipped scan row: invalid created_at ($createdRaw)',
        name: 'ScanRepository',
        error: m,
      );
      return null;
    }

    final String? thumb;
    if (thumbRaw == null) {
      thumb = null;
    } else if (thumbRaw is String) {
      thumb = thumbRaw;
    } else {
      log(
        'thumbnail_path ignored (expected String?, got ${thumbRaw.runtimeType})',
        name: 'ScanRepository',
        error: m,
      );
      thumb = null;
    }

    return ScanRecord(
      id: idRaw,
      sourcePath: pathRaw,
      thumbnailPath: thumb,
      createdAt: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  /// Copies a temp/export path from ML Kit into [applicationDocuments]/scans.
  Future<ScanRecord> persistFromTempFile(String pickedPath) async {
    final src = File(pickedPath);
    if (!await src.exists()) {
      throw StateError('Source file missing: $pickedPath');
    }
    final docs = await getApplicationDocumentsDirectory();
    final scansDir = Directory(p.join(docs.path, 'scans'));
    await scansDir.create(recursive: true);
    final id = _uuid.v4();
    final ext = p.extension(pickedPath);
    final safeExt = ext.isEmpty ? '.jpg' : ext;
    final dest = File(p.join(scansDir.path, '$id$safeExt'));
    await src.copy(dest.path);
    final database = await _db.database;
    final record = ScanRecord(
      id: id,
      sourcePath: dest.path,
      thumbnailPath: null,
      createdAt: DateTime.now(),
    );
    try {
      await database.transaction((txn) async {
        await txn.insert('scans', {
          'id': record.id,
          'source_path': record.sourcePath,
          'thumbnail_path': record.thumbnailPath,
          'created_at': record.createdAt.millisecondsSinceEpoch,
        });
      });
    } catch (e, stackTrace) {
      if (await dest.exists()) {
        try {
          await dest.delete();
        } catch (_) {
          /* best-effort orphan cleanup */
        }
      }
      Error.throwWithStackTrace(e, stackTrace);
    }
    return record;
  }

  Future<void> delete(String id) async {
    final database = await _db.database;
    final rows = await database.query(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );
    for (final m in rows) {
      final path = m['source_path'] as String?;
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      final thumb = m['thumbnail_path'] as String?;
      if (thumb != null) {
        final tf = File(thumb);
        if (await tf.exists()) await tf.delete();
      }
    }
    await database.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
