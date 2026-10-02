import '../../domain/entities/peerinfluence_entity.dart';

class PeerInfluenceModel extends PeerInfluenceEntity {
  const PeerInfluenceModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory PeerInfluenceModel.fromJson(Map<String, dynamic> json) {
    return PeerInfluenceModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
