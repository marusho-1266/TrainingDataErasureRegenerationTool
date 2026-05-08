import 'database_bootstrap_error_io.dart'
    if (dart.library.html) 'database_bootstrap_error_stub.dart' as impl;

/// True when [error] is a native SQLite open / query failure from sqflite.
bool isDatabaseBootstrapFailure(Object error) =>
    impl.isDatabaseBootstrapFailure(error);
