import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/dnasequence_entity.dart';
import '../../domain/repositories/dnasequence_repository.dart';

class DnaSequenceRepositoryImpl implements DnaSequenceRepository {
  @override
  Future<Either<Failure, DnaSequenceEntity>> getDnaSequence(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<DnaSequenceEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncDnaSequence() async { return Right(null); }
}
