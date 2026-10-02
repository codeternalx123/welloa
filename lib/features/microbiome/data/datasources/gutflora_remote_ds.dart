import '../models/gutflora_model.dart';

abstract class GutFloraRemoteDataSource {
  Future<GutFloraModel> fetchFromCloud(String id);
}
