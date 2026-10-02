import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/peerinfluence_entity.dart';
import '../repositories/peerinfluence_repository.dart';

class AnalyzePeerInfluenceUseCase {
  final PeerInfluenceRepository repository;
  AnalyzePeerInfluenceUseCase(this.repository);

  Future<Either<Failure, PeerInfluenceEntity>> execute(String id) async {
    return await repository.getPeerInfluence(id);
  }
}
