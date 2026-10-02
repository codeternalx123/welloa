import '../models/dysbiosisindex_model.dart';

abstract class DysbiosisIndexRemoteDataSource {
  Future<DysbiosisIndexModel> fetchFromCloud(String id);
}
