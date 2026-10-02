import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/kinematic_dose.dart';
import '../../domain/repositories/kinematic_repository.dart';
import '../datasources/kinematic_local_data_source.dart';
import '../datasources/kinematic_remote_data_source.dart';

class KinematicRepositoryImpl implements KinematicRepository {
  final KinematicRemoteDataSource remoteDataSource;
  final KinematicLocalDataSource localDataSource;

  KinematicRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, KinematicDose>> calculateAndCacheIntake() async {
    try {
      final remoteIntake = await remoteDataSource.calculateIntakeViaAI();
      localDataSource.cacheIntake(remoteIntake);
      return Right(remoteIntake);
    } catch (e) {
      // Fallback to local cache if network/AI fails
      try {
        final cached = await localDataSource.getLastCachedIntakes();
        if (cached.isNotEmpty) {
          return Right(cached.last);
        }
        return const Left(CacheFailure('No cached data available'));
      } catch (cacheError) {
        return Left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, List<KinematicDose>>> getHistoricalIntakes() async {
    try {
      final localIntakes = await localDataSource.getLastCachedIntakes();
      return Right(localIntakes);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
