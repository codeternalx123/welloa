import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/bio_twin_entity.dart';
import '../../domain/repositories/bio_twin_repository.dart';
import '../datasources/bio_twin_local_data_source.dart';
import '../datasources/bio_twin_remote_data_source.dart';

class BioTwinRepositoryImpl implements BioTwinRepository {
  final BioTwinRemoteDataSource remoteDataSource;
  final BioTwinLocalDataSource localDataSource;

  BioTwinRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, BioTwinEntity>> compileAndCacheBioTwin(double chronoAge, Map<String, dynamic> biometrics) async {
    try {
      final remoteTwin = await remoteDataSource.compileTwinViaAI(chronoAge, biometrics);
      await localDataSource.cacheTwin(remoteTwin);
      return Right(remoteTwin);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BioTwinEntity>> getLatestCompiledTwin() async {
    try {
      final localTwin = await localDataSource.getLastCachedTwin();
      return Right(localTwin);
    } catch (e) {
      return Left(CacheFailure('Local cache empty.'));
    }
  }
}
