import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/dnasequence_entity.dart';

abstract class DnaSequenceRepository {
  Future<Either<Failure, DnaSequenceEntity>> getDnaSequence(String id);
  Future<Either<Failure, List<DnaSequenceEntity>>> getAll();
  Future<Either<Failure, void>> syncDnaSequence();
}
