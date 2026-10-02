import '../models/dysbiosisindex_model.dart';

abstract class DysbiosisIndexLocalDataSource {
  Future<void> cache(DysbiosisIndexModel model);
  Future<DysbiosisIndexModel> getCached(String id);
}
