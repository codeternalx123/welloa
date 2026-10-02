import '../models/dnasequence_model.dart';

abstract class DnaSequenceRemoteDataSource {
  Future<DnaSequenceModel> fetchFromCloud(String id);
}
