import '../models/cyp450enzyme_model.dart';

abstract class Cyp450EnzymeLocalDataSource {
  Future<void> cache(Cyp450EnzymeModel model);
  Future<Cyp450EnzymeModel> getCached(String id);
}
