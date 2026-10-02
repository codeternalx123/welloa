import '../models/cytokinepanel_model.dart';

abstract class CytokinePanelRemoteDataSource {
  Future<CytokinePanelModel> fetchFromCloud(String id);
}
