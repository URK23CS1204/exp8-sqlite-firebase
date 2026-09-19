import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasePath;

    if (kIsWeb) {
      databasePath = 'students_web.db';
    } else {
      databasePath = join(await getDatabasesPath(), 'students.db');
    }

    return await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            course TEXT NOT NULL,
            firebaseId TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE students ADD COLUMN firebaseId TEXT');
        }
      },
    );
  }

  // CREATE
  Future<int> insertStudent(
    String name,
    String course, {
    String? firebaseId,
  }) async {
    final db = await database;

    return await db.insert('students', {
      'name': name,
      'course': course,
      'firebaseId': firebaseId,
    });
  }

  // READ
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;

    return await db.query('students', orderBy: 'id DESC');
  }

  // UPDATE
  Future<int> updateStudent(int id, String name, String course) async {
    final db = await database;

    return await db.update(
      'students',
      {'name': name, 'course': course},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE
  Future<int> deleteStudent(int id) async {
    final db = await database;

    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }
}
