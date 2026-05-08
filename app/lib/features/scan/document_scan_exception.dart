class DocumentScanException implements Exception {
  DocumentScanException(this.message);
  final String message;
  @override
  String toString() => message;
}
