import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/cyp450enzyme_entity.dart';

abstract class Cyp450EnzymeRepository {
  Future<Either<Failure, Cyp450EnzymeEntity>> getCyp450Enzyme(String id);
  Future<Either<Failure, List<Cyp450EnzymeEntity>>> getAll();
  Future<Either<Failure, void>> syncCyp450Enzyme();
}
