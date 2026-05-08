import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:training_data_erasure/inpainting/image_preprocess.dart';

void main() {
  group('image_preprocess', () {
    test('resizeLongEdge narrows oversized landscape', () {
      final canvas = img.Image(width: 2000, height: 1000, numChannels: 4);
      final resized = resizeLongEdge(canvas, 1024);
      expect(resized.width, 1024);
      expect(resized.height, 512);
    });

    test('preprocessRaster resizes jpeg bytes', () {
      final raster = img.Image(width: 1024, height: 600, numChannels: 4);
      final bytes = Uint8List.fromList(img.encodeJpg(raster, quality: 90));
      final out = preprocessRaster(bytes, 512);
      final long = out.width > out.height ? out.width : out.height;
      expect(long, lessThanOrEqualTo(512));
    });
  });
}
