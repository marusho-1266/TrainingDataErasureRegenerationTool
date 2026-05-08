import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:training_data_erasure/app.dart';
import 'package:training_data_erasure/data/app_database.dart';
import 'package:training_data_erasure/data/scan_repository.dart';
import 'package:training_data_erasure/inpainting/inpainting_engine.dart';
import 'package:training_data_erasure/inpainting/onnx_inpainting_engine.dart';
import 'package:training_data_erasure/inpainting/stub_inpainting_engine.dart';

/// `false`: [StubInpaintingEngine]（標準開発・モデル無し）。
/// `true`: [OnnxInpaintingEngine]（`inpainting.onnx` を bundle 済みなど PoC／本番向け）。
const bool _kUseOnnxEngine = bool.fromEnvironment(
  'USE_ONNX_ENGINE',
  defaultValue: false,
);

InpaintingEngine _createInpaintingEngine() =>
    _kUseOnnxEngine ? OnnxInpaintingEngine() : StubInpaintingEngine();

ErasureApp _createErasureApp() => ErasureApp(
      scanRepository: ScanRepository(AppDatabase.instance),
      inpaintingEngine: _createInpaintingEngine(),
    );

void _logDbBootstrapFailure(String kind, Object error, StackTrace stackTrace) {
  log(
    'AppDatabase.ready() failed ($kind)',
    name: 'AppDatabase',
    error: error,
    stackTrace: stackTrace,
  );
}

String _userFacingDbMessage(Object error) {
  if (error is StateError) {
    return 'アプリの保存領域にアクセスできませんでした。ストレージの空きや権限を確認してから再試行してください。\n\n（詳細: ${error.message}）';
  }
  if (error is DatabaseException) {
    return 'ローカルデータベースを開けませんでした。端末の空き容量やアプリのデータを確認し、再試行してください。\n\n（詳細: $error）';
  }
  return 'データベースの初期化に失敗しました。しばらくしてから再試行するか、アプリを終了してください。\n\n（詳細: $error）';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppDatabase.instance.ready();
  } on StateError catch (e, st) {
    _logDbBootstrapFailure('StateError', e, st);
    runApp(_DbRecoveryApp(initialError: e));
    return;
  } on DatabaseException catch (e, st) {
    _logDbBootstrapFailure('DatabaseException', e, st);
    runApp(_DbRecoveryApp(initialError: e));
    return;
  } catch (e, st) {
    _logDbBootstrapFailure('other', e, st);
    runApp(_DbRecoveryApp(initialError: e));
    return;
  }
  runApp(_createErasureApp());
}

/// [AppDatabase.instance.ready] が失敗したときの再試行／終了用ルート。
class _DbRecoveryApp extends StatefulWidget {
  const _DbRecoveryApp({required this.initialError});

  final Object initialError;

  @override
  State<_DbRecoveryApp> createState() => _DbRecoveryAppState();
}

class _DbRecoveryAppState extends State<_DbRecoveryApp> {
  late Object _error = widget.initialError;
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await AppDatabase.instance.ready();
      if (!mounted) return;
      runApp(_createErasureApp());
    } on StateError catch (e, st) {
      _logDbBootstrapFailure('StateError (retry)', e, st);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    } on DatabaseException catch (e, st) {
      _logDbBootstrapFailure('DatabaseException (retry)', e, st);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    } catch (e, st) {
      _logDbBootstrapFailure('other (retry)', e, st);
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
        appBar: AppBar(title: const Text('データベースの初期化')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _userFacingDbMessage(_error),
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
