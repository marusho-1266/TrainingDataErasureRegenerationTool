import 'dart:developer' show log;

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

/// Wraps ML Kit document scanner (`spec.md` §5 §16). Android と iOS 向けプラグイン。
///
/// Failures surface as [DocumentScanException] for §7 style handling.
class DocumentScanCoordinator {
  Future<DocumentScanningResult> scanOnce() async {
    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
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
      final result = outcome as DocumentScanningResult;
      if (result.images.isEmpty && result.pdf == null) {
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
    return success!;
  }
}

class DocumentScanException implements Exception {
  DocumentScanException(this.message);
  final String message;
  @override
  String toString() => message;
}
