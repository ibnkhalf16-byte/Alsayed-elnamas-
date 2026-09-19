// FILE: lib/core/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('elsayed_accounts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE persons (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        phone TEXT,
        address TEXT,
        notes TEXT,
        opening_receivable REAL DEFAULT 0,
        opening_payable REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        date TEXT NOT NULL,
        vehicle TEXT,
        driver TEXT,
        item TEXT NOT NULL,
        weight REAL NOT NULL,
        price REAL NOT NULL,
        nolon REAL DEFAULT 0, -- الحقل الجديد
        total REAL NOT NULL,
        notes TEXT,
        source_trip_id TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (person_id) REFERENCES persons (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        payment_type TEXT NOT NULL,
        direction TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        vehicle TEXT,
        driver TEXT,
        item TEXT,
        weight REAL,
        price REAL,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (person_id) REFERENCES persons (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
