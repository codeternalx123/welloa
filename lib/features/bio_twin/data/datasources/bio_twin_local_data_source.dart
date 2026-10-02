import '../models/bio_twin_model.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/database/daos/bio_twin_dao.dart';

abstract class BioTwinLocalDataSource {
  Future<void> cacheTwin(BioTwinModel twin);
  Future<BioTwinModel> getLastCachedTwin();
}

class BioTwinLocalDataSourceImpl implements BioTwinLocalDataSource {
  final BioTwinDao dao;

  BioTwinLocalDataSourceImpl({required this.dao});

  @override
  Future<void> cacheTwin(BioTwinModel twin) async {
    try {
      await dao.insertBioTwin(twin);
    } catch (e) {
      throw const CacheFailure('Failed to cache BioTwin to local database.');
    }
  }

  @override
  Future<BioTwinModel> getLastCachedTwin() async {
    try {
      final twin = await dao.getLatestBioTwin();
      if (twin != null) {
        return twin;
      }
      throw const CacheFailure('No cached BioTwin available.');
    } catch (e) {
      if (e is CacheFailure) rethrow;
      throw CacheFailure('Failed to fetch BioTwin from local database: ${e.toString()}');
    }
  }
}
