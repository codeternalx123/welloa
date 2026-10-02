import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/dysbiosisindex_entity.dart';
import '../../domain/repositories/dysbiosisindex_repository.dart';

class DysbiosisIndexRepositoryImpl implements DysbiosisIndexRepository {
  @override
  Future<Either<Failure, DysbiosisIndexEntity>> getDysbiosisIndex(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<DysbiosisIndexEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncDysbiosisIndex() async { return Right(null); }
}
