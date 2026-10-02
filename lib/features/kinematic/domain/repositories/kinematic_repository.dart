import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/kinematic_dose.dart';

abstract class KinematicRepository {
  Future<Either<Failure, KinematicDose>> calculateAndCacheIntake();
  Future<Either<Failure, List<KinematicDose>>> getHistoricalIntakes();
}
