import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/longevitynode_entity.dart';
import '../../domain/repositories/longevitynode_repository.dart';

class LongevityNodeRepositoryImpl implements LongevityNodeRepository {
  @override
  Future<Either<Failure, LongevityNodeEntity>> getLongevityNode(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<LongevityNodeEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncLongevityNode() async { return Right(null); }
}
