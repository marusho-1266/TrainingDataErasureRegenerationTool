import 'package:training_data_erasure/data/scan_repository_web.dart';

Future<void> bootstrapDataLayer() => WebScanRepository.init();
