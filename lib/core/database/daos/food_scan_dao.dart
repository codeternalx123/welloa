import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../../features/food_scan/data/models/phytochemical_analysis_model.dart';

class FoodScanDao {
  final DatabaseHelper dbHelper;

  FoodScanDao({required this.dbHelper});

  Future<void> insertFoodScan(PhytochemicalAnalysisModel model) async {
    final db = await dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Insert Core Entity
      await txn.insert(
        DatabaseHelper.tableFoodScans,
        {
          'id': model.id,
          'analyzedAt': model.analyzedAt.toIso8601String(),
          'totalAgeScore': model.totalAgeScore,
          'polyphenolScore': model.polyphenolScore,
          'biologicalAgeCostMinutes': model.biologicalAgeCostMinutes,
          'metric1Label': model.metric1Label,
          'metric1Value': model.metric1Value,
          'metric2Label': model.metric2Label,
          'metric2Value': model.metric2Value,
          'aiQuestion': model.aiQuestion,
          'dailyGoal': model.dailyGoal,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert Guidance List
      await txn.delete(DatabaseHelper.tableFoodScanGuidance, where: 'scanId = ?', whereArgs: [model.id]);
      for (var guidance in model.guidanceList) {
        await txn.insert(DatabaseHelper.tableFoodScanGuidance, {
          'scanId': model.id,
          'guidance': guidance,
        });
      }
    });
  }

  Future<List<PhytochemicalAnalysisModel>> getAllScans() async {
    final db = await dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableFoodScans,
      orderBy: 'analyzedAt DESC',
    );

    if (maps.isEmpty) {
      return [];
    }

    List<PhytochemicalAnalysisModel> results = [];

    for (var map in maps) {
      final scanId = map['id'] as String;
      
      final guidanceMaps = await db.query(
        DatabaseHelper.tableFoodScanGuidance, 
        where: 'scanId = ?', 
        whereArgs: [scanId]
      );

      final guidanceList = guidanceMaps.map((m) => m['guidance'] as String).toList();

      results.add(PhytochemicalAnalysisModel(
        id: scanId,
        analyzedAt: DateTime.parse(map['analyzedAt'] as String),
        totalAgeScore: map['totalAgeScore'] as double,
        polyphenolScore: map['polyphenolScore'] as double,
        biologicalAgeCostMinutes: map['biologicalAgeCostMinutes'] as double,
        metric1Label: map['metric1Label'] as String,
        metric1Value: map['metric1Value'] as String,
        metric2Label: map['metric2Label'] as String,
        metric2Value: map['metric2Value'] as String,
        aiQuestion: map['aiQuestion'] as String,
        dailyGoal: map['dailyGoal'] as String,
        guidanceList: guidanceList,
      ));
    }

    return results;
  }
}
