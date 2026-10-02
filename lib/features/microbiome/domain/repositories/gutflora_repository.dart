import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/gutflora_entity.dart';

abstract class GutFloraRepository {
  Future<Either<Failure, GutFloraEntity>> getGutFlora(String id);
  Future<Either<Failure, List<GutFloraEntity>>> getAll();
  Future<Either<Failure, void>> syncGutFlora();
}
