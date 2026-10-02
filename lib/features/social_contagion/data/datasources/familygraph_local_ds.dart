import '../models/familygraph_model.dart';

abstract class FamilyGraphLocalDataSource {
  Future<void> cache(FamilyGraphModel model);
  Future<FamilyGraphModel> getCached(String id);
}
