import '../../domain/entities/bacterialstrain_entity.dart';

class BacterialStrainModel extends BacterialStrainEntity {
  const BacterialStrainModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory BacterialStrainModel.fromJson(Map<String, dynamic> json) {
    return BacterialStrainModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
