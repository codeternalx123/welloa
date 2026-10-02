import '../../domain/entities/telomereassay_entity.dart';

class TelomereAssayModel extends TelomereAssayEntity {
  const TelomereAssayModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory TelomereAssayModel.fromJson(Map<String, dynamic> json) {
    return TelomereAssayModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
