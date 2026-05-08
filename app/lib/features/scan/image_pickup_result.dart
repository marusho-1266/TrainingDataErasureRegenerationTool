/// スキャン／画像取得の結果（モバイル: ファイルパス、Web: `webtemp:` 一時参照）。
class ImagePickupResult {
  ImagePickupResult({this.images});
  final List<String>? images;
}
