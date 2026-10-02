import '../models/kinematic_dose_model.dart';

abstract class KinematicLocalDataSource {
  Future<void> cacheIntake(KinematicDoseModel intake);
  Future<List<KinematicDoseModel>> getLastCachedIntakes();
}

class KinematicLocalDataSourceImpl implements KinematicLocalDataSource {
  // In a real app, this uses Hive, Drift (SQLite), or SharedPreferences
  final List<KinematicDoseModel> _memoryCache = [];

  @override
  Future<void> cacheIntake(KinematicDoseModel intake) async {
    _memoryCache.add(intake);
    // Simulate DB write
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<List<KinematicDoseModel>> getLastCachedIntakes() async {
    return _memoryCache;
  }
}
