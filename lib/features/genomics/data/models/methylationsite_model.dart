import '../../domain/entities/methylationsite_entity.dart';

class MethylationSiteModel extends MethylationSiteEntity {
  const MethylationSiteModel({required String id, required DateTime timestamp}) : super(id: id, timestamp: timestamp);
  
  factory MethylationSiteModel.fromJson(Map<String, dynamic> json) {
    return MethylationSiteModel(id: json['id'], timestamp: DateTime.parse(json['timestamp']));
  }
}
