import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/behavioralcontagion_entity.dart';

abstract class BehavioralContagionRepository {
  Future<Either<Failure, BehavioralContagionEntity>> getBehavioralContagion(String id);
  Future<Either<Failure, List<BehavioralContagionEntity>>> getAll();
  Future<Either<Failure, void>> syncBehavioralContagion();
}
