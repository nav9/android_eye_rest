import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE irest (
            datetime TEXT PRIMARY KEY,
            log TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertLog(String date, String status) async {
    final db = await database;
    await db.insert(
      'irest',
      {'datetime': date, 'log': status}, // Change 'status' to 'log'
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  Future<List<Map<String, dynamic>>> getLastLogs() async {
    final db = await database;
    return await db.query(
      'irest',
      columns: ['datetime', 'log'], // Ensure you select both columns
      orderBy: 'datetime DESC',
      limit: 10,
    );
  }


  Future<List<Map<String, dynamic>>> exportLogs() async {
    final db = await database;
    return await db.query('irest');
  }
}
