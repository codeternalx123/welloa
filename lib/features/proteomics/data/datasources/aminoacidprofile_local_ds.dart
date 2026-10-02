import '../models/aminoacidprofile_model.dart';

abstract class AminoAcidProfileLocalDataSource {
  Future<void> cache(AminoAcidProfileModel model);
  Future<AminoAcidProfileModel> getCached(String id);
}
