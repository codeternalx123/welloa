import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/proteinmarker_entity.dart';
import '../../domain/repositories/proteinmarker_repository.dart';

class ProteinMarkerRepositoryImpl implements ProteinMarkerRepository {
  @override
  Future<Either<Failure, ProteinMarkerEntity>> getProteinMarker(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<ProteinMarkerEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncProteinMarker() async { return Right(null); }
}
