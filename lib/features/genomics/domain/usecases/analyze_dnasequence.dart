import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/dnasequence_entity.dart';
import '../repositories/dnasequence_repository.dart';

class AnalyzeDnaSequenceUseCase {
  final DnaSequenceRepository repository;
  AnalyzeDnaSequenceUseCase(this.repository);

  Future<Either<Failure, DnaSequenceEntity>> execute(String id) async {
    return await repository.getDnaSequence(id);
  }
}
