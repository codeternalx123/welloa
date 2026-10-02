import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/telomereassay_entity.dart';
import '../../domain/repositories/telomereassay_repository.dart';

class TelomereAssayRepositoryImpl implements TelomereAssayRepository {
  @override
  Future<Either<Failure, TelomereAssayEntity>> getTelomereAssay(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<TelomereAssayEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncTelomereAssay() async { return Right(null); }
}
