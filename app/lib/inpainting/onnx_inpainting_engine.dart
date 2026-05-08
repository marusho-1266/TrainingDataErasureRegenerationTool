import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

import 'package:training_data_erasure/inpainting/inpainting_engine.dart';

const _assetOnnx = 'assets/models/inpainting.onnx';


/// Loads bundled `inpainting.onnx` when present. Tensor wiring is deferred until §4.1 freezes I/O shapes.
///
/// Pub package **`onnxruntime`** (upstream repo name is onnxruntime_flutter).
class OnnxInpaintingEngine implements InpaintingEngine {
  OrtSession? _session;
  bool _warmedUp = false;

  /// Async mutex chaining tail: all mutations to [_session] and [_warmedUp] must run inside
  /// [_withMutationLock]; also used by [warmup] across awaits so dispose cannot interleave.
  Future<void> _mutationMutexTail = Future<void>.value();

  Future<T> _withMutationLock<T>(Future<T> Function() body) async {
    final prior = _mutationMutexTail;
    final done = Completer<void>();
    _mutationMutexTail = done.future;
    await prior;
    try {
      return await body();
    } finally {
      done.complete();
    }
  }

  @override
  String get label => 'onnx ($_assetOnnx)';

  @override
  Future<void> warmup() async {
    if (_warmedUp) {
      return;
    }
    await _withMutationLock(() async {
      if (_warmedUp) {
        return;
      }
      late final ByteData bundle;
      try {
        bundle = await rootBundle.load(_assetOnnx);
      } catch (e, st) {
        Error.throwWithStackTrace(
          StateError(
            'ONNX アセットがありません (PoC 時は inpainting.onnx を配置)。 $e',
          ),
          st,
        );
      }
      OrtSessionOptions? opts;
      try {
        opts = OrtSessionOptions();
        _session = OrtSession.fromBuffer(
          bundle.buffer.asUint8List(),
          opts,
        );
        _warmedUp = true;
      } catch (e, st) {
        _session?.release();
        _session = null;
        _warmedUp = false;
        Error.throwWithStackTrace(e, st);
      } finally {
        opts?.release();
      }
    });
  }

  @override
  Future<Uint8List> run({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required Uint8List maskGray,
  }) async {
    await warmup();
    if (_session == null) {
      throw StateError('Session null after warmup');
    }
    // TODO: OrtValueTensor と入出力マップは採用モデル確定後 (Phase C)
    throw UnimplementedError(
      'inpainting の tensor I/F は §4.1 確定後に実装',
    );
  }

  @override
  Future<void> dispose() async {
    await _withMutationLock(() async {
      try {
        _session?.release();
      } finally {
        _session = null;
        _warmedUp = false;
      }
    });
  }
}
