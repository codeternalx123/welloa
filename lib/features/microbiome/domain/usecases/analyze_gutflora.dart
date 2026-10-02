import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/gutflora_entity.dart';
import '../repositories/gutflora_repository.dart';

class AnalyzeGutFloraUseCase {
  final GutFloraRepository repository;
  AnalyzeGutFloraUseCase(this.repository);

  Future<Either<Failure, GutFloraEntity>> execute(String id) async {
    return await repository.getGutFlora(id);
  }
}
