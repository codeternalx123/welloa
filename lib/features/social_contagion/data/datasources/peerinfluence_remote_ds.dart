import '../models/peerinfluence_model.dart';

abstract class PeerInfluenceRemoteDataSource {
  Future<PeerInfluenceModel> fetchFromCloud(String id);
}
