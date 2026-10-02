import '../models/peerinfluence_model.dart';

abstract class PeerInfluenceLocalDataSource {
  Future<void> cache(PeerInfluenceModel model);
  Future<PeerInfluenceModel> getCached(String id);
}
