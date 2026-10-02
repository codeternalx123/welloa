import '../models/hormonecascade_model.dart';

abstract class HormoneCascadeRemoteDataSource {
  Future<HormoneCascadeModel> fetchFromCloud(String id);
}
