import '../models/bacterialstrain_model.dart';

abstract class BacterialStrainLocalDataSource {
  Future<void> cache(BacterialStrainModel model);
  Future<BacterialStrainModel> getCached(String id);
}
