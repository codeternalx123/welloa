import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/behavioralcontagion_entity.dart';
import '../repositories/behavioralcontagion_repository.dart';

class AnalyzeBehavioralContagionUseCase {
  final BehavioralContagionRepository repository;
  AnalyzeBehavioralContagionUseCase(this.repository);

  Future<Either<Failure, BehavioralContagionEntity>> execute(String id) async {
    return await repository.getBehavioralContagion(id);
  }
}
