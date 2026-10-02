import '../models/cyp450enzyme_model.dart';

abstract class Cyp450EnzymeRemoteDataSource {
  Future<Cyp450EnzymeModel> fetchFromCloud(String id);
}
