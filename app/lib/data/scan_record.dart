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
