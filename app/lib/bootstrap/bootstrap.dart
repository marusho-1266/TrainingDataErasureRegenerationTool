import 'package:training_data_erasure/bootstrap/bootstrap_io.dart'
    if (dart.library.html) 'package:training_data_erasure/bootstrap/bootstrap_web.dart' as impl;

Future<void> bootstrapDataLayer() => impl.bootstrapDataLayer();
