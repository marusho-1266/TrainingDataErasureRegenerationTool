import 'package:training_data_erasure/inpainting/inpainting_engine.dart';
import 'package:training_data_erasure/inpainting/stub_inpainting_engine.dart';

/// PWA では ONNX ランタイム未対応のため常にスタブ。
InpaintingEngine createInpaintingEngine() => StubInpaintingEngine();
