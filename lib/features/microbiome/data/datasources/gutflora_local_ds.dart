import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/gutflora_model.dart';

abstract class GutFloraLocalDataSource {
  Future<void> initDB();
  Future<void> cache(GutFloraModel model);
  Future<GutFloraModel> getCached(String id);
}

class GutFloraLocalDataSourceImpl implements GutFloraLocalDataSource {
  Database? _database;

  @override
  Future<void> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'microbiome_flora_cache.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE microbiome_flora (
            id TEXT PRIMARY KEY, timestamp TEXT, diversityScore REAL, firmicutesBacteroidetesRatio REAL
          )
        ''');
      },
    );
  }

  @override
  Future<void> cache(GutFloraModel model) async {
    if (_database == null) await initDB();
    await _database!.insert(
      'microbiome_flora',
      {
        'id': model.id,
        'timestamp': model.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<GutFloraModel> getCached(String id) async {
    if (_database == null) await initDB();
    final List<Map<String, dynamic>> maps = await _database!.query(
      'microbiome_flora',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return GutFloraModel.fromJson(maps.first);
    } else {
      throw Exception('Cache miss for ID: $id');
    }
  }
}
