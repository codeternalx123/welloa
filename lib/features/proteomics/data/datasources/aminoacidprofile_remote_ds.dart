import '../models/aminoacidprofile_model.dart';

abstract class AminoAcidProfileRemoteDataSource {
  Future<AminoAcidProfileModel> fetchFromCloud(String id);
}
