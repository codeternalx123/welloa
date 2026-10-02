import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/aminoacidprofile_entity.dart';
import '../repositories/aminoacidprofile_repository.dart';

class AnalyzeAminoAcidProfileUseCase {
  final AminoAcidProfileRepository repository;
  AnalyzeAminoAcidProfileUseCase(this.repository);

  Future<Either<Failure, AminoAcidProfileEntity>> execute(String id) async {
    return await repository.getAminoAcidProfile(id);
  }
}
