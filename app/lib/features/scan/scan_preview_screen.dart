import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:training_data_erasure/data/scan_repository.dart';
import 'package:training_data_erasure/inpainting/image_preprocess.dart';
import 'package:training_data_erasure/inpainting/inpainting_engine.dart';

/// §2.2 : ユーザーがライブラリ保存前に結果を確認する画面。
class ScanPreviewScreen extends StatefulWidget {
  const ScanPreviewScreen({
    super.key,
    required this.imagePath,
    required this.repository,
    required this.inpaintingEngine,
    required this.onPersisted,
    this.alreadyStored = false,
  });

  final String imagePath;
  final ScanRepository repository;
  final InpaintingEngine inpaintingEngine;
  final VoidCallback onPersisted;
  final bool alreadyStored;

  @override
  State<ScanPreviewScreen> createState() => _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends State<ScanPreviewScreen> {
  static const longEdgePx = 512;

  bool _busy = false;
  ScanRecord? _stored;
  Uint8List? _preprocessedJpeg;
  String _inferNote = '';
  late Future<Uint8List> _sourceBytesFuture;

  @override
  void initState() {
    super.initState();
    _sourceBytesFuture = widget.repository.readImageBytes(widget.imagePath);
    if (widget.alreadyStored) {
      _inferNote = 'ライブラリの既存イメージ';
    } else {
      _inferNote = '推論エンジン: ${widget.inpaintingEngine.label}';
    }
  }

  Future<void> _persistScan() async {
    if (widget.alreadyStored) return;
    try {
      setState(() => _busy = true);
      final saved = await widget.repository.persistFromTempFile(
        widget.imagePath,
      );
      if (!mounted) return;
      setState(() {
        _stored = saved;
        _busy = false;
        _sourceBytesFuture =
            widget.repository.readImageBytes(saved.sourcePath);
      });
      widget.onPersisted();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ライブラリに保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  /// PoC: 長辺リサイズのみ（`image_preprocess`）。本番の inpainting は Phase C。
  Future<void> _runPreprocessPreview() async {
    setState(() {
      _busy = true;
      _preprocessedJpeg = null;
    });
    try {
      final raw = await widget.repository.readImageBytes(widget.imagePath);
      final resized = preprocessRaster(raw, longEdgePx);
      final jpg = Uint8List.fromList(img.encodeJpg(resized, quality: 90));
      if (!mounted) return;
      setState(() {
        _preprocessedJpeg = jpg;
        _busy = false;
        _inferNote = '前処理プレビュー（長辺 $longEdgePx px）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('前処理エラー: $e')),
      );
    }
  }

  Future<void> _runEngineStub() async {
    setState(() => _busy = true);
    try {
      await widget.inpaintingEngine.warmup();
      if (!mounted) return;
      final raw = await widget.repository.readImageBytes(widget.imagePath);
      if (!mounted) return;
      final resized = preprocessRaster(raw, longEdgePx);
      final w = resized.width;
      final h = resized.height;
      final rgba = imageToRgba8888(resized);
      if (!mounted) return;
      final mask = Uint8List(w * h);
      for (var i = 0; i < mask.length; i++) {
        mask[i] = 180;
      }
      final _ = await widget.inpaintingEngine.run(
        rgbaBytes: rgba,
        width: w,
        height: h,
        maskGray: mask,
      );
      if (!mounted) return;
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      debugPrint('$e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('推論またはウォームアップエラー（想定）: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _inferNote = 'stub エンジンで run 済み（入出力確認）';
    });
  }

  @override
  Widget build(BuildContext context) {
    final extra = (_preprocessedJpeg != null)
        ? Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Image.memory(
              _preprocessedJpeg!,
              fit: BoxFit.contain,
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('プレビュー')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_inferNote, style: Theme.of(context).textTheme.bodyMedium),
            if (_stored != null)
              Text(
                '保存済み ID: ${_stored!.id}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            const SizedBox(height: 12),
            FutureBuilder<Uint8List>(
              future: _sourceBytesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('読み込みエラー: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  if (_busy) {
                    return const SizedBox(height: 200);
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
            extra,
            const SizedBox(height: 16),
            if (!widget.alreadyStored) ...[
              FilledButton(
                onPressed: _busy ? null : _persistScan,
                child: const Text('ライブラリに保存'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _runPreprocessPreview,
                child: const Text('前処理プレビュー（PoC）'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _runEngineStub,
                child: const Text('エンジンに通す（スタブ）'),
              ),
            ],
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(widget.alreadyStored ? '戻る' : '破棄して戻る'),
            ),
            if (_busy)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
          ],
        ),
      ),
    );
  }
}
