import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:training_data_erasure/data/storage_ref.dart';

class _TempEntry {
  _TempEntry(this.bytes)
      : createdAt = DateTime.now(),
        lastAccess = DateTime.now(),
        size = bytes.length;

  final Uint8List bytes;
  final DateTime createdAt;
  DateTime lastAccess;
  final int size;
}

/// Web: スキャン直後〜保存前のバイトをメモリに保持し、`pickedPath` として参照する。
class WebTempImageStore {
  WebTempImageStore._();
  static final WebTempImageStore instance = WebTempImageStore._();

  static const _ttl = Duration(minutes: 30);
  static const _maxEntries = 32;
  static const _maxTotalBytes = 64 * 1024 * 1024;
  static const _maxBytesPerImage = 25 * 1024 * 1024;

  final Map<String, _TempEntry> _byId = {};
  final Uuid _uuid = Uuid();

  int get _totalBytes =>
      _byId.values.fold<int>(0, (sum, e) => sum + e.size);

  void _cleanupStale() {
    final now = DateTime.now();
    final toRemove = <String>[];
    for (final MapEntry(:key, :value) in _byId.entries) {
      if (now.difference(value.createdAt) > _ttl) {
        toRemove.add(key);
      }
    }
    for (final id in toRemove) {
      final removed = _byId.remove(id);
      log(
        'TTL evict id=$id size=${removed?.size} age=${removed != null ? now.difference(removed.createdAt).inSeconds : null}s',
        name: 'WebTempImageStore',
      );
    }
  }

  void _evictUntilWithinLimits() {
    final now = DateTime.now();
    while (_byId.isNotEmpty) {
      final count = _byId.length;
      final total = _totalBytes;
      if (count <= _maxEntries && total <= _maxTotalBytes) {
        break;
      }
      String? lruId;
      DateTime? lruTime;
      for (final MapEntry(:key, :value) in _byId.entries) {
        if (lruTime == null || value.lastAccess.isBefore(lruTime)) {
          lruTime = value.lastAccess;
          lruId = key;
        }
      }
      if (lruId == null) {
        break;
      }
      final removed = _byId.remove(lruId);
      log(
        'LRU evict id=$lruId size=${removed?.size} lastAccess=${removed != null ? now.difference(removed.lastAccess).inSeconds : null}s ago (count=$count total=$total)',
        name: 'WebTempImageStore',
      );
    }
  }

  /// 参照文字列（`webtemp:uuid`）を返す。
  String register(Uint8List bytes) {
    _cleanupStale();
    final n = bytes.length;
    if (n > _maxBytesPerImage) {
      log(
        'register rejected: $n bytes exceeds max $_maxBytesPerImage',
        name: 'WebTempImageStore',
      );
      throw StateError(
        '一時画像が大きすぎます（最大 ${_maxBytesPerImage ~/ (1024 * 1024)} MiB）',
      );
    }
    final id = _uuid.v4();
    _byId[id] = _TempEntry(bytes);
    _evictUntilWithinLimits();
    log(
      'register id=$id size=$n count=${_byId.length} totalBytes=$_totalBytes',
      name: 'WebTempImageStore',
    );
    return '$kWebTempPrefix$id';
  }

  Uint8List? resolve(String pathOrRef) {
    _cleanupStale();
    if (!isWebTempRef(pathOrRef)) {
      return null;
    }
    final id = pathOrRef.substring(kWebTempPrefix.length);
    final entry = _byId[id];
    if (entry == null) {
      log('resolve miss id=$id', name: 'WebTempImageStore');
      return null;
    }
    entry.lastAccess = DateTime.now();
    log('resolve hit id=$id size=${entry.size}', name: 'WebTempImageStore');
    return entry.bytes;
  }

  void unregister(String pathOrRef) {
    _cleanupStale();
    if (!isWebTempRef(pathOrRef)) {
      return;
    }
    final id = pathOrRef.substring(kWebTempPrefix.length);
    final removed = _byId.remove(id);
    log(
      'unregister id=$id removed=${removed != null} size=${removed?.size}',
      name: 'WebTempImageStore',
    );
  }
}
