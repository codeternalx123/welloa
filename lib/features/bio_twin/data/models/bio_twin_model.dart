import '../../domain/entities/bio_twin_entity.dart';
import '../../../../core/models/bio_twin.dart' show HallmarkScore, BioMarker, SimulationPoint;

class BioTwinModel extends BioTwinEntity {
  const BioTwinModel({
    required String id,
    required DateTime compiledAt,
    required double chronologicalAge,
    required double biologicalAge,
    required double ageGap,
    required double reversalRateMonthsPerYear,
    required String trajectory,
    required List<HallmarkScore> hallmarkScores,
    required List<BioMarker> keyBioMarkers,
    required List<SimulationPoint> sixMonthProjection,
  }) : super(
          id: id,
          compiledAt: compiledAt,
          chronologicalAge: chronologicalAge,
          biologicalAge: biologicalAge,
          ageGap: ageGap,
          reversalRateMonthsPerYear: reversalRateMonthsPerYear,
          trajectory: trajectory,
          hallmarkScores: hallmarkScores,
          keyBioMarkers: keyBioMarkers,
          sixMonthProjection: sixMonthProjection,
        );

  factory BioTwinModel.fromJson(Map<String, dynamic> json) {
    return BioTwinModel(
      id: json['id'],
      compiledAt: DateTime.parse(json['compiledAt']),
      chronologicalAge: (json['chronologicalAge'] as num).toDouble(),
      biologicalAge: (json['biologicalAge'] as num).toDouble(),
      ageGap: (json['ageGap'] as num).toDouble(),
      reversalRateMonthsPerYear: (json['reversalRateMonthsPerYear'] as num).toDouble(),
      trajectory: json['trajectory'],
      hallmarkScores: (json['hallmarkScores'] as List).map((e) => HallmarkScore.fromJson(e)).toList(),
      keyBioMarkers: (json['keyBioMarkers'] as List).map((e) => BioMarker.fromJson(e)).toList(),
      sixMonthProjection: (json['sixMonthProjection'] as List).map((e) => SimulationPoint.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'compiledAt': compiledAt.toIso8601String(),
      'chronologicalAge': chronologicalAge,
      'biologicalAge': biologicalAge,
      'ageGap': ageGap,
      'reversalRateMonthsPerYear': reversalRateMonthsPerYear,
      'trajectory': trajectory,
      'hallmarkScores': hallmarkScores.map((e) => e.toJson()).toList(),
      'keyBioMarkers': keyBioMarkers.map((e) => e.toJson()).toList(),
      'sixMonthProjection': sixMonthProjection.map((e) => e.toJson()).toList(),
    };
  }
}
