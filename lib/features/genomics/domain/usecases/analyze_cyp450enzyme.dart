import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/cyp450enzyme_entity.dart';
import '../repositories/cyp450enzyme_repository.dart';

class AnalyzeCyp450EnzymeUseCase {
  final Cyp450EnzymeRepository repository;
  AnalyzeCyp450EnzymeUseCase(this.repository);

  Future<Either<Failure, Cyp450EnzymeEntity>> execute(String id) async {
    return await repository.getCyp450Enzyme(id);
  }
}
