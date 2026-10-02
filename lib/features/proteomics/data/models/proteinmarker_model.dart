import '../../domain/entities/proteinmarker_entity.dart';

class ProteinMarkerModel extends ProteinMarkerEntity {
  const ProteinMarkerModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory ProteinMarkerModel.fromJson(Map<String, dynamic> json) {
    return ProteinMarkerModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
