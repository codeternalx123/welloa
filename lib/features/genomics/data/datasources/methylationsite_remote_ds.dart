import '../models/methylationsite_model.dart';

abstract class MethylationSiteRemoteDataSource {
  Future<MethylationSiteModel> fetchFromCloud(String id);
}
