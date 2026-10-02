import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/methylationsite_entity.dart';
import '../repositories/methylationsite_repository.dart';

class AnalyzeMethylationSiteUseCase {
  final MethylationSiteRepository repository;
  AnalyzeMethylationSiteUseCase(this.repository);

  Future<Either<Failure, MethylationSiteEntity>> execute(String id) async {
    return await repository.getMethylationSite(id);
  }
}
