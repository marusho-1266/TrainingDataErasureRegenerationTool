import 'package:training_data_erasure/inpainting/inpainting_engine.dart';
import 'package:training_data_erasure/inpainting/onnx_inpainting_engine.dart';
import 'package:training_data_erasure/inpainting/stub_inpainting_engine.dart';

const bool _kUseOnnxEngine = bool.fromEnvironment(
  'USE_ONNX_ENGINE',
  defaultValue: false,
);

InpaintingEngine createInpaintingEngine() =>
    _kUseOnnxEngine ? OnnxInpaintingEngine() : StubInpaintingEngine();
