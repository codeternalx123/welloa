import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/hormonecascade_entity.dart';
import '../../domain/repositories/hormonecascade_repository.dart';

class HormoneCascadeRepositoryImpl implements HormoneCascadeRepository {
  @override
  Future<Either<Failure, HormoneCascadeEntity>> getHormoneCascade(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<HormoneCascadeEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncHormoneCascade() async { return Right(null); }
}
