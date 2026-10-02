import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/cytokinepanel_entity.dart';

abstract class CytokinePanelRepository {
  Future<Either<Failure, CytokinePanelEntity>> getCytokinePanel(String id);
  Future<Either<Failure, List<CytokinePanelEntity>>> getAll();
  Future<Either<Failure, void>> syncCytokinePanel();
}
