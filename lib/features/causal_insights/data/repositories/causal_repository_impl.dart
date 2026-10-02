import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/causal_insight_entity.dart';
import '../../domain/repositories/causal_repository.dart';
import '../datasources/causal_local_data_source.dart';
import '../datasources/causal_remote_data_source.dart';
import '../../../../core/providers/health_provider.dart';

class CausalRepositoryImpl implements CausalRepository {
  final CausalRemoteDataSource remoteDataSource;
  final CausalLocalDataSource localDataSource;

  CausalRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, CausalInsightEntity>> runDoCalculusQuery(int presetIndex, HealthData? healthData) async {
    try {
      final remoteInsight = await remoteDataSource.runQueryViaAI(presetIndex, healthData);
      await localDataSource.cacheInsight(remoteInsight);
      return Right(remoteInsight);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CausalInsightEntity>>> getHistoricalQueries() async {
    try {
      final localInsights = await localDataSource.getCachedInsights();
      return Right(localInsights);
    } catch (e) {
      return Left(CacheFailure('Local cache empty.'));
    }
  }
}
