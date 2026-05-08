import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:training_data_erasure/data/scan_record.dart';
import 'package:training_data_erasure/data/scan_repository_contract.dart';
import 'package:training_data_erasure/data/storage_ref.dart';
import 'package:training_data_erasure/data/web_temp_image_store.dart';

/// PWA / Flutter Web: Hive（IndexedDB）に画像バイトとメタデータを保存。
class WebScanRepository implements ScanRepository {
  WebScanRepository._();

  static final WebScanRepository instance = WebScanRepository._();
  static final Uuid _uuid = const Uuid();

  static const _blobBoxName = 'scan_image_blob';
  static const _metaBoxName = 'scan_meta_plain';

  static bool _ready = false;
  static late Box<Uint8List> _blobBox;
  static late Box<dynamic> _metaBox;

  static Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _blobBox = await Hive.openBox<Uint8List>(_blobBoxName);
    _metaBox = await Hive.openBox<dynamic>(_metaBoxName);
    _ready = true;
  }

  static void _ensureReady() {
    if (!_ready) {
      throw StateError('WebScanRepository.init() has not completed');
    }
  }

  @override
  Future<List<ScanRecord>> listRecent({int limit = 50}) async {
    _ensureReady();
    final entries = <ScanRecord>[];
    for (final key in _metaBox.keys) {
      if (key is! String) continue;
      final id = key;
      final raw = _metaBox.get(id);
      if (raw is! Map) continue;
      final created = raw['created_at'];
      if (created is! int) continue;
      entries.add(
        ScanRecord(
          id: id,
          sourcePath: '$kWebStorePrefix$id',
          thumbnailPath: null,
          createdAt: DateTime.fromMillisecondsSinceEpoch(created),
        ),
      );
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (entries.length > limit) {
      return entries.sublist(0, limit);
    }
    return entries;
  }

  @override
  Future<ScanRecord> persistFromTempFile(String pickedPath) async {
    _ensureReady();
    if (!isWebTempRef(pickedPath)) {
      throw StateError('Web persistence expects $kWebTempPrefix*, got $pickedPath');
    }
    final bytes = WebTempImageStore.instance.resolve(pickedPath);
    if (bytes == null) {
      throw StateError('一時画像が見つかりません: $pickedPath');
    }
    final id = _uuid.v4();
    final createdAt = DateTime.now();
    try {
      await _blobBox.put(id, bytes);
      await _metaBox.put(id, <String, int>{
        'created_at': createdAt.millisecondsSinceEpoch,
      });
    } catch (e, stackTrace) {
      try {
        await _blobBox.delete(id);
      } catch (_) {}
      try {
        await _metaBox.delete(id);
      } catch (_) {}
      log(
        'persistFromTempFile failed; rolled back Hive entries for $id',
        name: 'WebScanRepository',
        error: e,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(e, stackTrace);
    }
    WebTempImageStore.instance.unregister(pickedPath);
    return ScanRecord(
      id: id,
      sourcePath: '$kWebStorePrefix$id',
      thumbnailPath: null,
      createdAt: createdAt,
    );
  }

  @override
  Future<void> delete(String id) async {
    _ensureReady();
    await _blobBox.delete(id);
    await _metaBox.delete(id);
  }

  @override
  Future<Uint8List> readImageBytes(String pathOrRef) async {
    _ensureReady();
    if (isWebTempRef(pathOrRef)) {
      final b = WebTempImageStore.instance.resolve(pathOrRef);
      if (b == null) {
        throw StateError('一時画像が無効です: $pathOrRef');
      }
      return b;
    }
    if (isWebStoreRef(pathOrRef)) {
      final id = pathOrRef.substring(kWebStorePrefix.length);
      final b = _blobBox.get(id);
      if (b == null) {
        throw StateError('保存画像が見つかりません: $id');
      }
      return b;
    }
    throw StateError('未対応の参照: $pathOrRef');
  }

  @override
  Future<bool> canOpen(String pathOrRef) async {
    if (!_ready) return false;
    if (isWebTempRef(pathOrRef)) {
      return WebTempImageStore.instance.resolve(pathOrRef) != null;
    }
    if (isWebStoreRef(pathOrRef)) {
      final id = pathOrRef.substring(kWebStorePrefix.length);
      return _blobBox.containsKey(id);
    }
    return false;
  }

  @override
  String listLabelForPath(String pathOrRef) {
    if (isWebStoreRef(pathOrRef)) {
      final id = pathOrRef.substring(kWebStorePrefix.length);
      if (id.length >= 8) return '保存 ${id.substring(0, 8)}…';
      return '保存 $id';
    }
    if (isWebTempRef(pathOrRef)) {
      return 'プレビュー';
    }
    return pathOrRef;
  }
}

ScanRepository createScanRepositoryImpl() => WebScanRepository.instance;
