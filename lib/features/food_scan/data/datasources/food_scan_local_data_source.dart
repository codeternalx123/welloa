import '../models/phytochemical_analysis_model.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/database/daos/food_scan_dao.dart';

abstract class FoodScanLocalDataSource {
  Future<void> cacheScanResult(PhytochemicalAnalysisModel result);
  Future<List<PhytochemicalAnalysisModel>> getCachedScans();
}

class FoodScanLocalDataSourceImpl implements FoodScanLocalDataSource {
  final FoodScanDao dao;

  FoodScanLocalDataSourceImpl({required this.dao});

  @override
  Future<void> cacheScanResult(PhytochemicalAnalysisModel result) async {
    try {
      await dao.insertFoodScan(result);
    } catch (e) {
      throw const CacheFailure('Failed to cache food scan result.');
    }
  }

  @override
  Future<List<PhytochemicalAnalysisModel>> getCachedScans() async {
    try {
      return await dao.getAllScans();
    } catch (e) {
      throw CacheFailure('Failed to fetch food scans from local database: ${e.toString()}');
    }
  }
}
