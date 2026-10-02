import 'package:dartz/dartz.dart';
import '../../domain/repositories/biometric_repository.dart';
import '../../core/error/failures.dart';
import '../../core/services/health_service.dart';

class BiometricRepositoryImpl implements BiometricRepository {
  final HealthService healthService;

  BiometricRepositoryImpl({required this.healthService});

  @override
  Future<Either<Failure, Map<String, dynamic>>> getLatestBiometrics() async {
    try {
      final data = await healthService.getFullBiometrics();
      return Right(data);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch biometrics: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveBiometricsLocally(Map<String, dynamic> data) async {
    // Implementation for Drift/Hive local caching goes here
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> syncBiometricsToCloud() async {
    // Implementation for background cloud syncing
    return const Right(null);
  }
}
