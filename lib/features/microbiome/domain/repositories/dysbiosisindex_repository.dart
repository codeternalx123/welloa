import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/dysbiosisindex_entity.dart';

abstract class DysbiosisIndexRepository {
  Future<Either<Failure, DysbiosisIndexEntity>> getDysbiosisIndex(String id);
  Future<Either<Failure, List<DysbiosisIndexEntity>>> getAll();
  Future<Either<Failure, void>> syncDysbiosisIndex();
}
