import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/aminoacidprofile_entity.dart';

abstract class AminoAcidProfileRepository {
  Future<Either<Failure, AminoAcidProfileEntity>> getAminoAcidProfile(String id);
  Future<Either<Failure, List<AminoAcidProfileEntity>>> getAll();
  Future<Either<Failure, void>> syncAminoAcidProfile();
}
