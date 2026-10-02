import '../../domain/entities/dnasequence_entity.dart';

class DnaSequenceModel extends DnaSequenceEntity {
  const DnaSequenceModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory DnaSequenceModel.fromJson(Map<String, dynamic> json) {
    return DnaSequenceModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
