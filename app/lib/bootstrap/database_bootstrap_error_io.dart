import 'package:sqflite/sqflite.dart';

bool isDatabaseBootstrapFailure(Object error) => error is DatabaseException;
