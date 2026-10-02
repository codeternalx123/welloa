import '../../domain/entities/gutflora_entity.dart';

class GutFloraModel extends GutFloraEntity {
  const GutFloraModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory GutFloraModel.fromJson(Map<String, dynamic> json) {
    return GutFloraModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
