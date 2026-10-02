import '../../domain/entities/cytokinepanel_entity.dart';

class CytokinePanelModel extends CytokinePanelEntity {
  const CytokinePanelModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory CytokinePanelModel.fromJson(Map<String, dynamic> json) {
    return CytokinePanelModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
