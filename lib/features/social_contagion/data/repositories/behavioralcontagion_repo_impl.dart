import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/behavioralcontagion_entity.dart';
import '../../domain/repositories/behavioralcontagion_repository.dart';

class BehavioralContagionRepositoryImpl implements BehavioralContagionRepository {
  @override
  Future<Either<Failure, BehavioralContagionEntity>> getBehavioralContagion(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<BehavioralContagionEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncBehavioralContagion() async { return Right(null); }
}
