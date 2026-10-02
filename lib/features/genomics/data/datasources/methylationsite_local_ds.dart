import '../models/methylationsite_model.dart';

abstract class MethylationSiteLocalDataSource {
  Future<void> cache(MethylationSiteModel model);
  Future<MethylationSiteModel> getCached(String id);
}
