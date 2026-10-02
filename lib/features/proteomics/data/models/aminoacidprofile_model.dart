import '../../domain/entities/aminoacidprofile_entity.dart';

class AminoAcidProfileModel extends AminoAcidProfileEntity {
  const AminoAcidProfileModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory AminoAcidProfileModel.fromJson(Map<String, dynamic> json) {
    return AminoAcidProfileModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
