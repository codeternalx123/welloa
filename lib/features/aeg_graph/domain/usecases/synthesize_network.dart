import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/aeg_synthesis_entity.dart';
import '../repositories/aeg_repository.dart';

class SynthesizeNetworkUseCase {
  final AEGRepository repository;

  SynthesizeNetworkUseCase(this.repository);

  Future<Either<Failure, AEGSynthesisEntity>> execute() async {
    return await repository.synthesizeSystemicGraph();
  }
}
