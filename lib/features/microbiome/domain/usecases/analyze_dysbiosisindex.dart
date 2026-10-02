import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/dysbiosisindex_entity.dart';
import '../repositories/dysbiosisindex_repository.dart';

class AnalyzeDysbiosisIndexUseCase {
  final DysbiosisIndexRepository repository;
  AnalyzeDysbiosisIndexUseCase(this.repository);

  Future<Either<Failure, DysbiosisIndexEntity>> execute(String id) async {
    return await repository.getDysbiosisIndex(id);
  }
}
