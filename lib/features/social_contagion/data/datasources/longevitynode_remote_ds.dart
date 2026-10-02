import '../models/longevitynode_model.dart';

abstract class LongevityNodeRemoteDataSource {
  Future<LongevityNodeModel> fetchFromCloud(String id);
}
