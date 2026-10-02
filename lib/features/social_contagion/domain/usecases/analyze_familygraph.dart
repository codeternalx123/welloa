import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/familygraph_entity.dart';
import '../repositories/familygraph_repository.dart';

class AnalyzeFamilyGraphUseCase {
  final FamilyGraphRepository repository;
  AnalyzeFamilyGraphUseCase(this.repository);

  Future<Either<Failure, FamilyGraphEntity>> execute(String id) async {
    return await repository.getFamilyGraph(id);
  }
}
