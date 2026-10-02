import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/hormonecascade_entity.dart';
import '../repositories/hormonecascade_repository.dart';

class AnalyzeHormoneCascadeUseCase {
  final HormoneCascadeRepository repository;
  AnalyzeHormoneCascadeUseCase(this.repository);

  Future<Either<Failure, HormoneCascadeEntity>> execute(String id) async {
    return await repository.getHormoneCascade(id);
  }
}
