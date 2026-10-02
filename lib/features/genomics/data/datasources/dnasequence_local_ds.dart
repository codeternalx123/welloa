import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/dnasequence_model.dart';

abstract class DnaSequenceLocalDataSource {
  Future<void> initDB();
  Future<void> cache(DnaSequenceModel model);
  Future<DnaSequenceModel> getCached(String id);
}

class DnaSequenceLocalDataSourceImpl implements DnaSequenceLocalDataSource {
  Database? _database;

  @override
  Future<void> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'genomics_dna_cache.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE genomics_dna (
            id TEXT PRIMARY KEY, timestamp TEXT, sequenceHash TEXT, coverage REAL, alignmentStatus TEXT
          )
        ''');
      },
    );
  }

  @override
  Future<void> cache(DnaSequenceModel model) async {
    if (_database == null) await initDB();
    await _database!.insert(
      'genomics_dna',
      {
        'id': model.id,
        'timestamp': model.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DnaSequenceModel> getCached(String id) async {
    if (_database == null) await initDB();
    final List<Map<String, dynamic>> maps = await _database!.query(
      'genomics_dna',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return DnaSequenceModel.fromJson(maps.first);
    } else {
      throw Exception('Cache miss for ID: $id');
    }
  }
}
