import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/bacterialstrain_entity.dart';
import '../../domain/repositories/bacterialstrain_repository.dart';

class BacterialStrainRepositoryImpl implements BacterialStrainRepository {
  @override
  Future<Either<Failure, BacterialStrainEntity>> getBacterialStrain(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<BacterialStrainEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncBacterialStrain() async { return Right(null); }
}
