import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/telomereassay_entity.dart';

abstract class TelomereAssayRepository {
  Future<Either<Failure, TelomereAssayEntity>> getTelomereAssay(String id);
  Future<Either<Failure, List<TelomereAssayEntity>>> getAll();
  Future<Either<Failure, void>> syncTelomereAssay();
}
