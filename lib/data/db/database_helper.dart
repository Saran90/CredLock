import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  static const _dbName = 'credlock.db';
  static const _dbVersion = 3;
  static const tablePasswords = 'passwords';

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tablePasswords (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        category        TEXT    NOT NULL,
        name            TEXT    NOT NULL,
        url             TEXT    NOT NULL DEFAULT '',
        username        TEXT    NOT NULL DEFAULT '',
        password        TEXT    NOT NULL DEFAULT '',
        pin             TEXT,
        package_name    TEXT,
        app_icon_base64 TEXT,
        created_at      TEXT    NOT NULL,
        last_updated_at TEXT    NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tablePasswords ADD COLUMN package_name TEXT',
      );
      await db.execute(
        'ALTER TABLE $tablePasswords ADD COLUMN app_icon_base64 TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tablePasswords ADD COLUMN last_updated_at TEXT',
      );
      await db.execute(
        'UPDATE $tablePasswords SET last_updated_at = created_at WHERE last_updated_at IS NULL',
      );
    }
  }

  /// Returns the full filesystem path to the database file.
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  /// Closes the database connection. Must be called before file-level
  /// operations (backup copy, restore replace).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Deletes all data from the passwords table.
  /// Used when signing out to prevent data leakage across accounts.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(tablePasswords);
  }

  /// Deletes the entire database file from disk.
  /// Used for complete cleanup on account switch.
  Future<void> deleteDatabase() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await databaseFactory.deleteDatabase(path);
  }
}
