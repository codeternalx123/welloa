import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/aeg_synthesis_entity.dart';

abstract class AEGRepository {
  Future<Either<Failure, AEGSynthesisEntity>> synthesizeSystemicGraph();
  Future<Either<Failure, AEGSynthesisEntity>> getCachedSynthesis();
}
