import '../models/behavioralcontagion_model.dart';

abstract class BehavioralContagionRemoteDataSource {
  Future<BehavioralContagionModel> fetchFromCloud(String id);
}
