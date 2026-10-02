import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/kinematic_dose.dart';
import '../repositories/kinematic_repository.dart';

class CalculateOptimalIntakeUseCase {
  final KinematicRepository repository;

  CalculateOptimalIntakeUseCase(this.repository);

  Future<Either<Failure, KinematicDose>> execute() async {
    // Domain logic: Fetch latest biometrics and calculate intake
    return await repository.calculateAndCacheIntake();
  }
}
