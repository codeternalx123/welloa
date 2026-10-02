import '../models/familygraph_model.dart';

abstract class FamilyGraphRemoteDataSource {
  Future<FamilyGraphModel> fetchFromCloud(String id);
}
