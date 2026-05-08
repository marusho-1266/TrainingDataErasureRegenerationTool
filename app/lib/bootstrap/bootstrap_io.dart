import 'package:training_data_erasure/data/app_database.dart';

Future<void> bootstrapDataLayer() => AppDatabase.instance.ready();
