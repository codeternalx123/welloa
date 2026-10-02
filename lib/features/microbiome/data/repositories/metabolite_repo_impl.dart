import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/metabolite_entity.dart';
import '../../domain/repositories/metabolite_repository.dart';

class MetaboliteRepositoryImpl implements MetaboliteRepository {
  @override
  Future<Either<Failure, MetaboliteEntity>> getMetabolite(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<MetaboliteEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncMetabolite() async { return Right(null); }
}
