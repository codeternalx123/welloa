import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/peerinfluence_entity.dart';
import '../../domain/repositories/peerinfluence_repository.dart';

class PeerInfluenceRepositoryImpl implements PeerInfluenceRepository {
  @override
  Future<Either<Failure, PeerInfluenceEntity>> getPeerInfluence(String id) async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, List<PeerInfluenceEntity>>> getAll() async { return Left(ServerFailure('Unimplemented')); }
  @override
  Future<Either<Failure, void>> syncPeerInfluence() async { return Right(null); }
}
