import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/aminoacidprofile_entity.dart';
import '../../domain/repositories/aminoacidprofile_repository.dart';

class AminoAcidProfileRepositoryImpl implements AminoAcidProfileRepository {
  @override
  Future<Either<Failure, AminoAcidProfileEntity>> getAminoAcidProfile(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<AminoAcidProfileEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncAminoAcidProfile() async { return Right(null); }
}
