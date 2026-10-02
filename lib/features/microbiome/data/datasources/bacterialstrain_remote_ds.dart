import '../models/bacterialstrain_model.dart';

abstract class BacterialStrainRemoteDataSource {
  Future<BacterialStrainModel> fetchFromCloud(String id);
}
