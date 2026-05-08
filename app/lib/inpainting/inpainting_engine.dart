import 'dart:typed_data';

/// Abstracts inpainting (LaMa-compatible ONNX planned). Implemented by stubs and ONNX runtime (`spec.md` §4).
abstract class InpaintingEngine {
  /// Human-readable backend label for debug UI / PoC reports.
  String get label;

  Future<void> warmup();

  /// Runs inpainting once. [rgbaBytes] decoded image RGBA8888 linear buffer; dimensions must match preprocess output.
  /// [maskGray] luminance-style mask aligned with image pixels.
  Future<Uint8List> run({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required Uint8List maskGray,
  });

  Future<void> dispose();
}
