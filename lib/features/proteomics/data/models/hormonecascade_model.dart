import '../../domain/entities/hormonecascade_entity.dart';

class HormoneCascadeModel extends HormoneCascadeEntity {
  const HormoneCascadeModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory HormoneCascadeModel.fromJson(Map<String, dynamic> json) {
    return HormoneCascadeModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
