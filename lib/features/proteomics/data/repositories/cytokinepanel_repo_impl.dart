import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/cytokinepanel_entity.dart';
import '../../domain/repositories/cytokinepanel_repository.dart';

class CytokinePanelRepositoryImpl implements CytokinePanelRepository {
  @override
  Future<Either<Failure, CytokinePanelEntity>> getCytokinePanel(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<CytokinePanelEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncCytokinePanel() async { return Right(null); }
}
