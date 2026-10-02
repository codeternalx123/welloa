import '../../domain/entities/cyp450enzyme_entity.dart';

class Cyp450EnzymeModel extends Cyp450EnzymeEntity {
  const Cyp450EnzymeModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory Cyp450EnzymeModel.fromJson(Map<String, dynamic> json) {
    return Cyp450EnzymeModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
