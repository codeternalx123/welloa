import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/aeg_synthesis_entity.dart';
import '../../domain/repositories/aeg_repository.dart';
import '../datasources/aeg_local_data_source.dart';
import '../datasources/aeg_remote_data_source.dart';

class AEGRepositoryImpl implements AEGRepository {
  final AEGRemoteDataSource remoteDataSource;
  final AEGLocalDataSource localDataSource;

  AEGRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, AEGSynthesisEntity>> synthesizeSystemicGraph() async {
    try {
      final remoteData = await remoteDataSource.generateSystemicGraphViaAI();
      await localDataSource.cacheSynthesis(remoteData);
      return Right(remoteData);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AEGSynthesisEntity>> getCachedSynthesis() async {
    try {
      final localData = await localDataSource.getLatestSynthesis();
      return Right(localData);
    } catch (e) {
      return Left(CacheFailure('Local cache empty.'));
    }
  }
}
