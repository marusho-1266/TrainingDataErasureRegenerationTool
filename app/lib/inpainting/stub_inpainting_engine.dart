import 'dart:typed_data';

import 'package:training_data_erasure/inpainting/inpainting_engine.dart';

/// Returns input unchanged until a real ONNX model is wired (`implementation_plan.md` Phase A).
class StubInpaintingEngine implements InpaintingEngine {
  @override
  String get label => 'stub-pass-through';

  @override
  Future<void> dispose() async {}

  @override
  Future<void> warmup() async {}

  @override
  Future<Uint8List> run({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required Uint8List maskGray,
  }) async {
    if (rgbaBytes.length != width * height * 4) {
      throw ArgumentError(
        'rgba length ${rgbaBytes.length} vs ${width}x$height×4',
      );
    }
    if (maskGray.length != width * height) {
      throw ArgumentError('mask ${maskGray.length} vs ${width * height}');
    }
    return Uint8List.fromList(rgbaBytes);
  }
}
