import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/call_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('phone_app.db');
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE call_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phoneNumber TEXT NOT NULL,
        contactName TEXT,
        duration INTEGER NOT NULL,
        recordingPath TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertCallRecord(CallRecord record) async {
    final db = await database;
    return await db.insert('call_records', record.toMap());
  }

  Future<List<CallRecord>> getAllCallRecords() async {
    final db = await database;
    final result = await db.query(
      'call_records',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => CallRecord.fromMap(map)).toList();
  }

  Future<int> deleteCallRecord(int id) async {
    final db = await database;
    return await db.delete(
      'call_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
