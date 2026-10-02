import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bio_twin_entity.dart';

abstract class BioTwinRepository {
  Future<Either<Failure, BioTwinEntity>> compileAndCacheBioTwin(double chronoAge, Map<String, dynamic> biometrics);
  Future<Either<Failure, BioTwinEntity>> getLatestCompiledTwin();
}
