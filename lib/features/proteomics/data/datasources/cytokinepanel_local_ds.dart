import '../models/cytokinepanel_model.dart';

abstract class CytokinePanelLocalDataSource {
  Future<void> cache(CytokinePanelModel model);
  Future<CytokinePanelModel> getCached(String id);
}
