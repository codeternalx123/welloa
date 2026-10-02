import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/longevitynode_model.dart';

abstract class LongevityNodeLocalDataSource {
  Future<void> initDB();
  Future<void> cache(LongevityNodeModel model);
  Future<LongevityNodeModel> getCached(String id);
}

class LongevityNodeLocalDataSourceImpl implements LongevityNodeLocalDataSource {
  Database? _database;

  @override
  Future<void> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'social_nodes_cache.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE social_nodes (
            id TEXT PRIMARY KEY, timestamp TEXT, peerReversalRate REAL, contagionFactor REAL
          )
        ''');
      },
    );
  }

  @override
  Future<void> cache(LongevityNodeModel model) async {
    if (_database == null) await initDB();
    await _database!.insert(
      'social_nodes',
      {
        'id': model.id,
        'timestamp': model.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<LongevityNodeModel> getCached(String id) async {
    if (_database == null) await initDB();
    final List<Map<String, dynamic>> maps = await _database!.query(
      'social_nodes',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return LongevityNodeModel.fromJson(maps.first);
    } else {
      throw Exception('Cache miss for ID: $id');
    }
  }
}
