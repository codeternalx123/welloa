import '../../domain/entities/familygraph_entity.dart';

class FamilyGraphModel extends FamilyGraphEntity {
  const FamilyGraphModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory FamilyGraphModel.fromJson(Map<String, dynamic> json) {
    return FamilyGraphModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
