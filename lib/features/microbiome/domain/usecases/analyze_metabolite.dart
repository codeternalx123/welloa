import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/metabolite_entity.dart';
import '../repositories/metabolite_repository.dart';

class AnalyzeMetaboliteUseCase {
  final MetaboliteRepository repository;
  AnalyzeMetaboliteUseCase(this.repository);

  Future<Either<Failure, MetaboliteEntity>> execute(String id) async {
    return await repository.getMetabolite(id);
  }
}
