import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bacterialstrain_entity.dart';

abstract class BacterialStrainRepository {
  Future<Either<Failure, BacterialStrainEntity>> getBacterialStrain(String id);
  Future<Either<Failure, List<BacterialStrainEntity>>> getAll();
  Future<Either<Failure, void>> syncBacterialStrain();
}
