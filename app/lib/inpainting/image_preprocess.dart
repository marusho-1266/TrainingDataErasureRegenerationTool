import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Resizes so the longer side is [longEdgePx] (`spec.md` §3 は 1024 仮).
img.Image resizeLongEdge(img.Image source, int longEdgePx) {
  final w = source.width;
  final h = source.height;
  final long = w > h ? w : h;
  if (long <= longEdgePx) {
    return img.copyResize(
      source,
      width: w,
      height: h,
    );
  }
  final scale = longEdgePx / long;
  final nw = (w * scale).round().clamp(1, 8192);
  final nh = (h * scale).round().clamp(1, 8192);
  return img.copyResize(
    source,
    width: nw,
    height: nh,
    interpolation: img.Interpolation.linear,
  );
}

/// Grayscale luma aligned with mask channels for inpainting pipelines.
Uint8List toGrayLuminance(img.Image im) {
  final out = Uint8List(im.width * im.height);
  var i = 0;
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final px = im.getPixel(x, y);
      final r = px.r.toInt().clamp(0, 255);
      final g = px.g.toInt().clamp(0, 255);
      final b = px.b.toInt().clamp(0, 255);
      final l = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 255);
      out[i++] = l;
    }
  }
  return out;
}

/// RGBA8888 row-major suitable for ONNX-style stacks (NHWC planar per pixel).
Uint8List imageToRgba8888(img.Image im) {
  final out = Uint8List(im.width * im.height * 4);
  var o = 0;
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final px = im.getPixel(x, y);
      out[o++] = px.r.toInt().clamp(0, 255);
      out[o++] = px.g.toInt().clamp(0, 255);
      out[o++] = px.b.toInt().clamp(0, 255);
      out[o++] = px.a.toInt().clamp(0, 255);
    }
  }
  return out;
}

/// Decodes JPEG/PNG bytes and applies [resizeLongEdge].
img.Image preprocessRaster(Uint8List bytes, int longEdgePx) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError('decodeImage returned null');
  }
  return resizeLongEdge(decoded, longEdgePx);
}
