import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'package:training_data_erasure/data/web_temp_image_store.dart';
import 'package:training_data_erasure/features/scan/document_scan_exception.dart';
import 'package:training_data_erasure/features/scan/image_pickup_result.dart';

/// PWA / Safari 向け: カメラまたはギャラリーで 1 枚取得し、一時バイト参照を返す。
class DocumentScanCoordinator {
  Future<ImagePickupResult> scanOnce() async {
    final picker = ImagePicker();
    var x = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    x ??= await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (x == null) {
      throw DocumentScanException(
        '画像の撮影・選択がキャンセルされたか、ブラウザがカメラに対応していません。',
      );
    }
    late final Uint8List bytes;
    try {
      bytes = await x.readAsBytes();
    } catch (e, stackTrace) {
      log(
        'pickImage readAsBytes failed',
        name: 'DocumentScanCoordinator',
        error: e,
        stackTrace: stackTrace,
      );
      throw DocumentScanException(
        '画像データの読み取りに失敗しました。別の画像を試すか、ブラウザの権限・ストレージを確認してください。',
      );
    }
    late final String ref;
    try {
      ref = WebTempImageStore.instance.register(bytes);
    } catch (e, stackTrace) {
      log(
        'WebTempImageStore.register failed',
        name: 'DocumentScanCoordinator',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is StateError) {
        throw DocumentScanException(e.message);
      }
      throw DocumentScanException(
        '一時保存に失敗しました。画像サイズやブラウザの空きメモリを確認してください。',
      );
    }
    return ImagePickupResult(images: [ref]);
  }
}