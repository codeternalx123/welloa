import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/phytochemical_analysis.dart';
import '../../domain/repositories/food_scan_repository.dart';
import '../datasources/food_scan_local_data_source.dart';
import '../datasources/food_scan_remote_data_source.dart';

class FoodScanRepositoryImpl implements FoodScanRepository {
  final FoodScanRemoteDataSource remoteDataSource;
  final FoodScanLocalDataSource localDataSource;

  FoodScanRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, PhytochemicalAnalysis>> analyzeMealImage(String base64Image) async {
    try {
      final remoteResult = await remoteDataSource.analyzeImage(base64Image);
      await localDataSource.cacheScanResult(remoteResult);
      return Right(remoteResult);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PhytochemicalAnalysis>>> getScanHistory() async {
    try {
      final localHistory = await localDataSource.getCachedScans();
      return Right(localHistory);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
