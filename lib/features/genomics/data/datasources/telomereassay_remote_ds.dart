import '../models/telomereassay_model.dart';

abstract class TelomereAssayRemoteDataSource {
  Future<TelomereAssayModel> fetchFromCloud(String id);
}
