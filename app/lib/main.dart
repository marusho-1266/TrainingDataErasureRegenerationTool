import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import 'package:training_data_erasure/app.dart';
import 'package:training_data_erasure/bootstrap/bootstrap.dart';
import 'package:training_data_erasure/bootstrap/database_bootstrap_error.dart';
import 'package:training_data_erasure/data/scan_repository.dart';
import 'package:training_data_erasure/inpainting/inpainting_factory.dart';

ErasureApp _createErasureApp() => ErasureApp(
      scanRepository: createScanRepository(),
      inpaintingEngine: createInpaintingEngine(),
    );

void _logBootstrapFailure(Object error, StackTrace stackTrace) {
  log(
    'bootstrapDataLayer failed',
    name: 'bootstrap',
    error: error,
    stackTrace: stackTrace,
  );
}

String _userFacingBootstrapMessage(Object error) {
  if (error is StateError) {
    return 'アプリの保存領域にアクセスできませんでした。ストレージの空きや権限を確認してから再試行してください。\n\n（詳細: ${error.message}）';
  }
  if (isDatabaseBootstrapFailure(error)) {
    return 'ローカルデータベースを開けませんでした。端末の空き容量やアプリのデータを確認し、再試行してください。\n\n（詳細: $error）';
  }
  return '初期化に失敗しました。ページを再読み込みするか、アプリを終了してください。\n\n（詳細: $error）';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await bootstrapDataLayer();
  } catch (e, st) {
    _logBootstrapFailure(e, st);
    runApp(_BootstrapFailureApp(initialError: e));
    return;
  }
  runApp(_createErasureApp());
}

/// データ層の初期化に失敗したとき。
class _BootstrapFailureApp extends StatefulWidget {
  const _BootstrapFailureApp({required this.initialError});

  final Object initialError;

  @override
  State<_BootstrapFailureApp> createState() => _BootstrapFailureAppState();
}

class _BootstrapFailureAppState extends State<_BootstrapFailureApp> {
  late Object _error = widget.initialError;
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await bootstrapDataLayer();
      if (!mounted) return;
      runApp(_createErasureApp());
    } catch (e, st) {
      _logBootstrapFailure(e, st);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    }
  }

  void _quit() => SystemNavigator.pop();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '書き込み消去',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('初期化エラー')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _userFacingBootstrapMessage(_error),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
        persistentFooterButtons: [
          TextButton(onPressed: _busy ? null : _quit, child: const Text('終了')),
          FilledButton(
            onPressed: _busy ? null : _retry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}
