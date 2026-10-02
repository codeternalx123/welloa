import '../../domain/entities/metabolite_entity.dart';

class MetaboliteModel extends MetaboliteEntity {
  const MetaboliteModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory MetaboliteModel.fromJson(Map<String, dynamic> json) {
    return MetaboliteModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
