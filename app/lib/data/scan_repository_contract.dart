import 'dart:typed_data';

import 'package:training_data_erasure/data/scan_record.dart';

/// モバイル（ファイル）と Web（Hive 内バイナリ）の共通インターフェース。
abstract class ScanRepository {
  Future<List<ScanRecord>> listRecent({int limit = 50});

  /// スキャン直後の参照（モバイル: 実パス、Web: [kWebTempPrefix] 付き）を永続化する。
  Future<ScanRecord> persistFromTempFile(String pickedPath);

  Future<void> delete(String id);

  Future<Uint8List> readImageBytes(String pathOrRef);

  /// UI が参照を開けるか（モバイルは実ファイル、Web は内部キー）。
  Future<bool> canOpen(String pathOrRef);

  /// 一覧サブタイトル等に使う短い表記。
  String listLabelForPath(String pathOrRef);
}
