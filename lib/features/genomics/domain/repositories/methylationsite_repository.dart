import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/methylationsite_entity.dart';

abstract class MethylationSiteRepository {
  Future<Either<Failure, MethylationSiteEntity>> getMethylationSite(String id);
  Future<Either<Failure, List<MethylationSiteEntity>>> getAll();
  Future<Either<Failure, void>> syncMethylationSite();
}
