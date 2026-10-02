import '../models/aeg_synthesis_model.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/database/daos/aeg_graph_dao.dart';

abstract class AEGLocalDataSource {
  Future<void> cacheSynthesis(AEGSynthesisModel synthesis);
  Future<AEGSynthesisModel> getLatestSynthesis();
}

class AEGLocalDataSourceImpl implements AEGLocalDataSource {
  final AEGGraphDao dao;

  AEGLocalDataSourceImpl({required this.dao});

  @override
  Future<void> cacheSynthesis(AEGSynthesisModel synthesis) async {
    try {
      await dao.insertSynthesis(synthesis);
    } catch (e) {
      throw const CacheFailure('Failed to cache AEG Graph to local database.');
    }
  }

  @override
  Future<AEGSynthesisModel> getLatestSynthesis() async {
    try {
      final synthesis = await dao.getLatestSynthesis();
      if (synthesis != null) {
        return synthesis;
      }
      throw const CacheFailure('No locally cached AEG graph available.');
    } catch (e) {
      if (e is CacheFailure) rethrow;
      throw CacheFailure('Failed to fetch AEG Graph from local database: ${e.toString()}');
    }
  }
}
