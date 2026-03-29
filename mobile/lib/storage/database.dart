import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models/job_result.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/optimizer.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE job_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id TEXT NOT NULL,
            method TEXT NOT NULL,
            objective_name TEXT NOT NULL,
            objective_kind TEXT NOT NULL,
            dims INTEGER NOT NULL,
            best_f REAL NOT NULL,
            status TEXT NOT NULL,
            result_json TEXT,
            metrics_json TEXT,
            config_json TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<int> insertResult(SavedJobResult result) async {
    final db = await database;
    return db.insert('job_results', result.toDbMap());
  }

  static Future<List<SavedJobResult>> getAllResults() async {
    final db = await database;
    final maps =
        await db.query('job_results', orderBy: 'created_at DESC');
    return maps.map(SavedJobResult.fromDbMap).toList();
  }

  static Future<List<SavedJobResult>> getResultsByFilter({
    String? method,
    String? objectiveName,
    String? status,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (method != null) {
      where.add('method = ?');
      args.add(method);
    }
    if (objectiveName != null) {
      where.add('objective_name = ?');
      args.add(objectiveName);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    final maps = await db.query(
      'job_results',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return maps.map(SavedJobResult.fromDbMap).toList();
  }

  static Future<SavedJobResult?> getResultById(int id) async {
    final db = await database;
    final maps =
        await db.query('job_results', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return SavedJobResult.fromDbMap(maps.first);
  }

  static Future<void> deleteResult(int id) async {
    final db = await database;
    await db.delete('job_results', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAll() async {
    final db = await database;
    await db.delete('job_results');
  }
}
