import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/cytokinepanel_entity.dart';
import '../repositories/cytokinepanel_repository.dart';

class AnalyzeCytokinePanelUseCase {
  final CytokinePanelRepository repository;
  AnalyzeCytokinePanelUseCase(this.repository);

  Future<Either<Failure, CytokinePanelEntity>> execute(String id) async {
    return await repository.getCytokinePanel(id);
  }
}
