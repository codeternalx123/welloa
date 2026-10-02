import '../models/proteinmarker_model.dart';

abstract class ProteinMarkerRemoteDataSource {
  Future<ProteinMarkerModel> fetchFromCloud(String id);
}
