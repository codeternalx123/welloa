import '../../domain/entities/behavioralcontagion_entity.dart';

class BehavioralContagionModel extends BehavioralContagionEntity {
  const BehavioralContagionModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory BehavioralContagionModel.fromJson(Map<String, dynamic> json) {
    return BehavioralContagionModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
