import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bio_twin_entity.dart';
import '../repositories/bio_twin_repository.dart';

class CompileBioTwinUseCase {
  final BioTwinRepository repository;

  CompileBioTwinUseCase(this.repository);

  Future<Either<Failure, BioTwinEntity>> execute({required double chronoAge, required Map<String, dynamic> biometrics}) async {
    if (chronoAge <= 0) {
      return const Left(CacheFailure('Chronological age must be strictly positive.'));
    }
    return await repository.compileAndCacheBioTwin(chronoAge, biometrics);
  }
}
