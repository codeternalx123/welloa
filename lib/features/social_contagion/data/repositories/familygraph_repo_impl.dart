import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/familygraph_entity.dart';
import '../../domain/repositories/familygraph_repository.dart';

class FamilyGraphRepositoryImpl implements FamilyGraphRepository {
  @override
  Future<Either<Failure, FamilyGraphEntity>> getFamilyGraph(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<FamilyGraphEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncFamilyGraph() async { return Right(null); }
}
