import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';

// DECISIÓN: se usa sqflite (+ sqflite_common_ffi en escritorio) en lugar de
// Drift para evitar el paso de codegen (build_runner) y priorizar que la app
// compile y corra. El esquema cumple el mismo modelo de datos y CASCADE.
// sqflite está permitido por el enunciado ("Drift o sqflite + DAOs").

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    final db = _db;
    if (db != null) return db;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = await _dbPath();
    return openDatabase(
      path,
      version: AppConstants.dbVersion, // schemaVersion = 1
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  profile_image_path TEXT,
  current_trimester_id INTEGER REFERENCES trimesters(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE trimesters(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE subjects(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  trimester_id INTEGER NOT NULL REFERENCES trimesters(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color_hex TEXT NOT NULL DEFAULT '#3F51B5',
  created_at TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE tasks(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  is_completed INTEGER NOT NULL DEFAULT 0,
  completed_at TEXT,
  created_at TEXT NOT NULL
)''');
        await db.execute(
            'CREATE INDEX idx_tasks_user_due ON tasks(user_id, due_date)');
        await db.execute(
            'CREATE INDEX idx_subjects_trim ON subjects(trimester_id)');
        await db.execute(
            'CREATE INDEX idx_trim_user ON trimesters(user_id)');
      },
    );
  }

  /// Ruta del archivo de BD con respaldos.
  ///
  /// Si `path_provider` no está registrado (MissingPluginException: app
  /// compilada sin plugins, p. ej. hot-restart tras agregar dependencias
  /// o Windows sin Developer Mode), se prueba `getDatabasesPath()` de
  /// sqflite y, en escritorio, una carpeta por variables de entorno
  /// (sin usar `Directory.current`, que no existe en móvil).
  /// `sqflite_common_ffi` en escritorio es Dart puro + sqlite nativo y no
  /// necesita canales de plataforma, así que la BD abre igual.
  Future<String> _dbPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, AppConstants.dbName);
    } catch (_) {}
    try {
      final dbDir = await getDatabasesPath();
      return p.join(dbDir, AppConstants.dbName);
    } catch (_) {}
    final base = _envDataDir();
    if (base != null) {
      final dir = Directory(p.join(base, 'tareas_uni'));
      await dir.create(recursive: true);
      return p.join(dir.path, AppConstants.dbName);
    }
    throw StateError(
      'No se pudo abrir la BD: los plugins no están registrados. '
      'Detén la app por completo y recompila con "flutter clean" + '
      '"flutter run" (en Windows activa antes el Modo Desarrollador).',
    );
  }

  /// Directorio de datos por variables de entorno, sin plugins ni CWD.
  /// Solo escritorio; en móvil devuelve null.
  String? _envDataDir() {
    if (kIsWeb) return null;
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['APPDATA'] ?? env['USERPROFILE'];
    }
    if (Platform.isLinux) {
      final home = env['HOME'];
      return env['XDG_DATA_HOME'] ??
          (home != null ? p.join(home, '.local', 'share') : null);
    }
    if (Platform.isMacOS) {
      final home = env['HOME'];
      return home != null
          ? p.join(home, 'Library', 'Application Support')
          : null;
    }
    return null; // Android/iOS: sin plugins no hay ruta fiable
  }

  /// Solo para tests: abre una BD en memoria con el mismo esquema.
  @visibleForTesting
  static Future<Database> openInMemory() async {
    sqfliteFfiInit();
    return openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  profile_image_path TEXT,
  current_trimester_id INTEGER REFERENCES trimesters(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE trimesters(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE subjects(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  trimester_id INTEGER NOT NULL REFERENCES trimesters(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color_hex TEXT NOT NULL DEFAULT '#3F51B5',
  created_at TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE tasks(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  is_completed INTEGER NOT NULL DEFAULT 0,
  completed_at TEXT,
  created_at TEXT NOT NULL
)''');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
