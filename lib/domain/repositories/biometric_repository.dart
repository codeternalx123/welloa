import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/models/kinematic_dose.dart';

abstract class BiometricRepository {
  Future<Either<Failure, Map<String, dynamic>>> getLatestBiometrics();
  Future<Either<Failure, void>> saveBiometricsLocally(Map<String, dynamic> data);
  Future<Either<Failure, void>> syncBiometricsToCloud();
}
