import '../models/metabolite_model.dart';

abstract class MetaboliteRemoteDataSource {
  Future<MetaboliteModel> fetchFromCloud(String id);
}
