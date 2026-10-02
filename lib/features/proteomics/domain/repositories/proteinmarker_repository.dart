import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/proteinmarker_entity.dart';

abstract class ProteinMarkerRepository {
  Future<Either<Failure, ProteinMarkerEntity>> getProteinMarker(String id);
  Future<Either<Failure, List<ProteinMarkerEntity>>> getAll();
  Future<Either<Failure, void>> syncProteinMarker();
}
