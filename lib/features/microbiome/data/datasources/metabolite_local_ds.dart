import '../models/metabolite_model.dart';

abstract class MetaboliteLocalDataSource {
  Future<void> cache(MetaboliteModel model);
  Future<MetaboliteModel> getCached(String id);
}
