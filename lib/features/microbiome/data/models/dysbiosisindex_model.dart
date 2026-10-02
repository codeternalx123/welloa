import '../../domain/entities/dysbiosisindex_entity.dart';

class DysbiosisIndexModel extends DysbiosisIndexEntity {
  const DysbiosisIndexModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory DysbiosisIndexModel.fromJson(Map<String, dynamic> json) {
    return DysbiosisIndexModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
