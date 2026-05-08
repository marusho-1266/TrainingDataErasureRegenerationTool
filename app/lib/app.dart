import 'package:flutter/material.dart';

import 'package:training_data_erasure/data/scan_repository.dart';
import 'package:training_data_erasure/features/home/home_screen.dart';
import 'package:training_data_erasure/inpainting/inpainting_engine.dart';

/// Root widget: injects repositories used by feature screens.
class ErasureApp extends StatelessWidget {
  const ErasureApp({
    super.key,
    required this.scanRepository,
    required this.inpaintingEngine,
  });

  final ScanRepository scanRepository;
  final InpaintingEngine inpaintingEngine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '書き込み消去',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: HomeScreen(
        repository: scanRepository,
        inpaintingEngine: inpaintingEngine,
      ),
    );
  }
}
