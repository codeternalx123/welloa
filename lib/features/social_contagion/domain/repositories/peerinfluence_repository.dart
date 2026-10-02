import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/peerinfluence_entity.dart';

abstract class PeerInfluenceRepository {
  Future<Either<Failure, PeerInfluenceEntity>> getPeerInfluence(String id);
  Future<Either<Failure, List<PeerInfluenceEntity>>> getAll();
  Future<Either<Failure, void>> syncPeerInfluence();
}
