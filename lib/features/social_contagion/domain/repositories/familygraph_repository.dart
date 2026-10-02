import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/familygraph_entity.dart';

abstract class FamilyGraphRepository {
  Future<Either<Failure, FamilyGraphEntity>> getFamilyGraph(String id);
  Future<Either<Failure, List<FamilyGraphEntity>>> getAll();
  Future<Either<Failure, void>> syncFamilyGraph();
}
