import '../models/behavioralcontagion_model.dart';

abstract class BehavioralContagionLocalDataSource {
  Future<void> cache(BehavioralContagionModel model);
  Future<BehavioralContagionModel> getCached(String id);
}
