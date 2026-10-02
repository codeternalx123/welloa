import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/longevitynode_entity.dart';
import '../repositories/longevitynode_repository.dart';

class AnalyzeLongevityNodeUseCase {
  final LongevityNodeRepository repository;
  AnalyzeLongevityNodeUseCase(this.repository);

  Future<Either<Failure, LongevityNodeEntity>> execute(String id) async {
    return await repository.getLongevityNode(id);
  }
}
