import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/gutflora_entity.dart';
import '../../domain/repositories/gutflora_repository.dart';

class GutFloraRepositoryImpl implements GutFloraRepository {
  @override
  Future<Either<Failure, GutFloraEntity>> getGutFlora(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<GutFloraEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncGutFlora() async { return Right(null); }
}
