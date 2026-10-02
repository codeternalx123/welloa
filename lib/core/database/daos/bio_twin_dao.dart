import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../../features/bio_twin/data/models/bio_twin_model.dart';
import '../../../core/models/bio_twin.dart';

class BioTwinDao {
  final DatabaseHelper dbHelper;

  BioTwinDao({required this.dbHelper});

  Future<void> insertBioTwin(BioTwinModel twin) async {
    final db = await dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Insert Core Entity
      await txn.insert(
        DatabaseHelper.tableBioTwin,
        {
          'id': twin.id,
          'compiledAt': twin.compiledAt.toIso8601String(),
          'chronologicalAge': twin.chronologicalAge,
          'biologicalAge': twin.biologicalAge,
          'ageGap': twin.ageGap,
          'reversalRateMonthsPerYear': twin.reversalRateMonthsPerYear,
          'trajectory': twin.trajectory,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert Hallmark Scores
      await txn.delete(DatabaseHelper.tableHallmarkScores, where: 'bioTwinId = ?', whereArgs: [twin.id]);
      for (var score in twin.hallmarkScores) {
        await txn.insert(DatabaseHelper.tableHallmarkScores, {
          'bioTwinId': twin.id,
          'hallmarkName': score.hallmarkName,
          'score': score.score,
          'trend': score.trend,
        });
      }

      // 3. Insert BioMarkers
      await txn.delete(DatabaseHelper.tableBioMarkers, where: 'bioTwinId = ?', whereArgs: [twin.id]);
      for (var marker in twin.keyBioMarkers) {
        await txn.insert(DatabaseHelper.tableBioMarkers, {
          'bioTwinId': twin.id,
          'name': marker.name,
          'value': marker.value,
          'unit': marker.unit,
          'optimalRange': marker.optimalRange,
          'status': marker.status,
        });
      }

      // 4. Insert Simulations
      await txn.delete(DatabaseHelper.tableSimulations, where: 'bioTwinId = ?', whereArgs: [twin.id]);
      for (var sim in twin.sixMonthProjection) {
        await txn.insert(DatabaseHelper.tableSimulations, {
          'bioTwinId': twin.id,
          'monthOffset': sim.monthOffset,
          'projectedBioAge': sim.projectedBioAge,
        });
      }
    });
  }

  Future<BioTwinModel?> getLatestBioTwin() async {
    final db = await dbHelper.database;
    
    // Get latest entry
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableBioTwin,
      orderBy: 'compiledAt DESC',
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    final twinMap = maps.first;
    final twinId = twinMap['id'] as String;

    // Fetch relational data
    final hallmarkMaps = await db.query(DatabaseHelper.tableHallmarkScores, where: 'bioTwinId = ?', whereArgs: [twinId]);
    final biomarkerMaps = await db.query(DatabaseHelper.tableBioMarkers, where: 'bioTwinId = ?', whereArgs: [twinId]);
    final simulationMaps = await db.query(DatabaseHelper.tableSimulations, where: 'bioTwinId = ?', whereArgs: [twinId], orderBy: 'monthOffset ASC');

    final hallmarkScores = hallmarkMaps.map((m) => HallmarkScore(
      hallmarkName: m['hallmarkName'] as String,
      score: m['score'] as double,
      trend: m['trend'] as String,
    )).toList();

    final keyBioMarkers = biomarkerMaps.map((m) => BioMarker(
      name: m['name'] as String,
      value: m['value'] as double,
      unit: m['unit'] as String,
      optimalRange: m['optimalRange'] as String,
      status: m['status'] as String,
    )).toList();

    final sixMonthProjection = simulationMaps.map((m) => SimulationPoint(
      monthOffset: m['monthOffset'] as int,
      projectedBioAge: m['projectedBioAge'] as double,
    )).toList();

    return BioTwinModel(
      id: twinId,
      compiledAt: DateTime.parse(twinMap['compiledAt'] as String),
      chronologicalAge: twinMap['chronologicalAge'] as double,
      biologicalAge: twinMap['biologicalAge'] as double,
      ageGap: twinMap['ageGap'] as double,
      reversalRateMonthsPerYear: twinMap['reversalRateMonthsPerYear'] as double,
      trajectory: twinMap['trajectory'] as String,
      hallmarkScores: hallmarkScores,
      keyBioMarkers: keyBioMarkers,
      sixMonthProjection: sixMonthProjection,
    );
  }
}
