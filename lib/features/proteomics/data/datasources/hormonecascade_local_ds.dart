import '../models/hormonecascade_model.dart';

abstract class HormoneCascadeLocalDataSource {
  Future<void> cache(HormoneCascadeModel model);
  Future<HormoneCascadeModel> getCached(String id);
}
