import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:training_data_erasure/data/scan_repository.dart';
import 'package:training_data_erasure/features/scan/document_scan_coordinator.dart';
import 'package:training_data_erasure/features/scan/scan_preview_screen.dart';
import 'package:training_data_erasure/inpainting/inpainting_engine.dart';

/// ホーム: スキャン導線と直近のライブラリ一覧 (`spec.md` §6)。
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.inpaintingEngine,
  });

  final ScanRepository repository;
  final InpaintingEngine inpaintingEngine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DocumentScanCoordinator _scanner = DocumentScanCoordinator();
  List<ScanRecord> _recent = [];
  final Map<String, bool> _canOpenByPath = {};

  Future<void> _reload() async {
    final rows = await widget.repository.listRecent();
    final openChecks = await Future.wait(
      rows.map(
        (r) async => MapEntry(
          r.sourcePath,
          await widget.repository.canOpen(r.sourcePath),
        ),
      ),
    );
    final canOpenByPath = Map<String, bool>.fromEntries(openChecks);
    if (!mounted) return;
    setState(() {
      _recent = rows;
      _canOpenByPath
        ..clear()
        ..addAll(canOpenByPath);
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _startScan() async {
    try {
      final result = await _scanner.scanOnce();
      final images = result.images;
      final path =
          (images != null && images.isNotEmpty) ? images.first : null;
      if (path == null || !mounted) return;
      if (!await widget.repository.canOpen(path)) {
        throw DocumentScanException(
          '画像を開けません: ${p.basename(path)}',
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (ctx) => ScanPreviewScreen(
            imagePath: path,
            repository: widget.repository,
            inpaintingEngine: widget.inpaintingEngine,
            onPersisted: _reload,
          ),
        ),
      );
    } on DocumentScanException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学習用書き込み消去')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _startScan,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('新しいページを撮影'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '過去のスキャン（保存済み）',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recent.isEmpty
                  ? const Center(child: Text('まだありません'))
                  : ListView.separated(
                      itemCount: _recent.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = _recent[i];
                        final label =
                            widget.repository.listLabelForPath(r.sourcePath);
                        return ListTile(
                          leading: const Icon(Icons.image_outlined),
                          title: Text(
                            '${r.createdAt.toLocal()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: (_canOpenByPath[r.sourcePath] == true)
                              ? () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ScanPreviewScreen(
                                        imagePath: r.sourcePath,
                                        repository: widget.repository,
                                        inpaintingEngine:
                                            widget.inpaintingEngine,
                                        onPersisted: _reload,
                                        alreadyStored: true,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
