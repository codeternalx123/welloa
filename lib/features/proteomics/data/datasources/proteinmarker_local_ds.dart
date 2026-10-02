import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/proteinmarker_model.dart';

abstract class ProteinMarkerLocalDataSource {
  Future<void> initDB();
  Future<void> cache(ProteinMarkerModel model);
  Future<ProteinMarkerModel> getCached(String id);
}

class ProteinMarkerLocalDataSourceImpl implements ProteinMarkerLocalDataSource {
  Database? _database;

  @override
  Future<void> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'proteomics_markers_cache.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE proteomics_markers (
            id TEXT PRIMARY KEY, timestamp TEXT, cytokineLevel REAL, mTorActivityScore REAL
          )
        ''');
      },
    );
  }

  @override
  Future<void> cache(ProteinMarkerModel model) async {
    if (_database == null) await initDB();
    await _database!.insert(
      'proteomics_markers',
      {
        'id': model.id,
        'timestamp': model.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<ProteinMarkerModel> getCached(String id) async {
    if (_database == null) await initDB();
    final List<Map<String, dynamic>> maps = await _database!.query(
      'proteomics_markers',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return ProteinMarkerModel.fromJson(maps.first);
    } else {
      throw Exception('Cache miss for ID: $id');
    }
  }
}
