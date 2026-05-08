import 'dart:developer' show log;

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import 'package:training_data_erasure/features/scan/document_scan_exception.dart';
import 'package:training_data_erasure/features/scan/image_pickup_result.dart';

/// ML Kit ドキュメントスキャナー（Android / iOS）。`spec.md` §5 §16。
class DocumentScanCoordinator {
  Future<ImagePickupResult> scanOnce() async {
    final options = DocumentScannerOptions(
      documentFormats: {DocumentFormat.jpeg},
      mode: ScannerMode.full,
      pageLimit: 1,
      isGalleryImport: true,
    );
    final scanner = DocumentScanner(options: options);
    Object? originalError;
    StackTrace? originalStackTrace;
    DocumentScanningResult? success;
    try {
      final Future<dynamic> scanFuture = scanner.scanDocument();
      final dynamic outcome = await scanFuture;
      if (outcome == null) {
        throw DocumentScanException(
          'スキャンがキャンセルされたか、プラットフォームから結果が返りませんでした。',
        );
      }
      if (outcome is! DocumentScanningResult) {
        throw DocumentScanException(
          '想定外のスキャン結果型: ${outcome.runtimeType}',
        );
      }
      final result = outcome;
      final imgs = result.images;
      if (imgs == null || imgs.isEmpty) {
        throw DocumentScanException('スキャン結果が空です。');
      }
      success = result;
    } catch (e, st) {
      originalError = e is DocumentScanException
          ? e
          : DocumentScanException('ドキュメントスキャンに失敗しました: $e');
      originalStackTrace = st;
    } finally {
      try {
        await scanner.close();
      } catch (e, st) {
        log(
          'DocumentScanner.close failed',
          name: 'DocumentScanCoordinator',
          error: e,
          stackTrace: st,
        );
        if (originalError == null) {
          originalError = e;
          originalStackTrace = st;
        }
      }
    }
    final err = originalError;
    if (err != null) {
      final st = originalStackTrace ?? StackTrace.empty;
      Error.throwWithStackTrace(err, st);
    }
    final r = success!;
    return ImagePickupResult(images: r.images!);
  }
}
