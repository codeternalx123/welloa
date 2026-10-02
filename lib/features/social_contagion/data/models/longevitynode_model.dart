import '../../domain/entities/longevitynode_entity.dart';

class LongevityNodeModel extends LongevityNodeEntity {
  const LongevityNodeModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory LongevityNodeModel.fromJson(Map<String, dynamic> json) {
    return LongevityNodeModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
