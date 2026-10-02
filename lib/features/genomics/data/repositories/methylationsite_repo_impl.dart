import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/methylationsite_entity.dart';
import '../../domain/repositories/methylationsite_repository.dart';

class MethylationSiteRepositoryImpl implements MethylationSiteRepository {
  @override
  Future<Either<Failure, MethylationSiteEntity>> getMethylationSite(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<MethylationSiteEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncMethylationSite() async { return Right(null); }
}
