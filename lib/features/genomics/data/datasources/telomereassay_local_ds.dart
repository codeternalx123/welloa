import '../models/telomereassay_model.dart';

abstract class TelomereAssayLocalDataSource {
  Future<void> cache(TelomereAssayModel model);
  Future<TelomereAssayModel> getCached(String id);
}
