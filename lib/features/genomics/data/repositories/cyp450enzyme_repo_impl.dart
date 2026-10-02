import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/cyp450enzyme_entity.dart';
import '../../domain/repositories/cyp450enzyme_repository.dart';

class Cyp450EnzymeRepositoryImpl implements Cyp450EnzymeRepository {
  @override
  Future<Either<Failure, Cyp450EnzymeEntity>> getCyp450Enzyme(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<Cyp450EnzymeEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncCyp450Enzyme() async { return Right(null); }
}
