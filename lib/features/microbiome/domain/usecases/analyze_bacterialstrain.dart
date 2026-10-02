import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bacterialstrain_entity.dart';
import '../repositories/bacterialstrain_repository.dart';

class AnalyzeBacterialStrainUseCase {
  final BacterialStrainRepository repository;
  AnalyzeBacterialStrainUseCase(this.repository);

  Future<Either<Failure, BacterialStrainEntity>> execute(String id) async {
    return await repository.getBacterialStrain(id);
  }
}
