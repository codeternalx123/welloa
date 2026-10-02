import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/longevitynode_entity.dart';

abstract class LongevityNodeRepository {
  Future<Either<Failure, LongevityNodeEntity>> getLongevityNode(String id);
  Future<Either<Failure, List<LongevityNodeEntity>>> getAll();
  Future<Either<Failure, void>> syncLongevityNode();
}
