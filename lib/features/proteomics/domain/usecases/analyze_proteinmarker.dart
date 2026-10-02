import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/proteinmarker_entity.dart';
import '../repositories/proteinmarker_repository.dart';

class AnalyzeProteinMarkerUseCase {
  final ProteinMarkerRepository repository;
  AnalyzeProteinMarkerUseCase(this.repository);

  Future<Either<Failure, ProteinMarkerEntity>> execute(String id) async {
    return await repository.getProteinMarker(id);
  }
}
