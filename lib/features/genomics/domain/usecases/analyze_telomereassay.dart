import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/telomereassay_entity.dart';
import '../repositories/telomereassay_repository.dart';

class AnalyzeTelomereAssayUseCase {
  final TelomereAssayRepository repository;
  AnalyzeTelomereAssayUseCase(this.repository);

  Future<Either<Failure, TelomereAssayEntity>> execute(String id) async {
    return await repository.getTelomereAssay(id);
  }
}
