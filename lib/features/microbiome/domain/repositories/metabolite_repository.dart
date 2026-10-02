import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/metabolite_entity.dart';

abstract class MetaboliteRepository {
  Future<Either<Failure, MetaboliteEntity>> getMetabolite(String id);
  Future<Either<Failure, List<MetaboliteEntity>>> getAll();
  Future<Either<Failure, void>> syncMetabolite();
}
