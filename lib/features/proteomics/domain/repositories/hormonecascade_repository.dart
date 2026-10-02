import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/hormonecascade_entity.dart';

abstract class HormoneCascadeRepository {
  Future<Either<Failure, HormoneCascadeEntity>> getHormoneCascade(String id);
  Future<Either<Failure, List<HormoneCascadeEntity>>> getAll();
  Future<Either<Failure, void>> syncHormoneCascade();
}
