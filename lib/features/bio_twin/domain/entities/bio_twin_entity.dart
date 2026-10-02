import 'package:equatable/equatable.dart';
import '../../../../core/models/bio_twin.dart' show HallmarkScore, BioMarker, SimulationPoint;

class BioTwinEntity extends Equatable {
  final String id;
  final DateTime compiledAt;
  final double chronologicalAge;
  final double biologicalAge;
  final double ageGap;
  final double reversalRateMonthsPerYear;
  final String trajectory;
  final List<HallmarkScore> hallmarkScores;
  final List<BioMarker> keyBioMarkers;
  final List<SimulationPoint> sixMonthProjection;

  const BioTwinEntity({
    required this.id,
    required this.compiledAt,
    required this.chronologicalAge,
    required this.biologicalAge,
    required this.ageGap,
    required this.reversalRateMonthsPerYear,
    required this.trajectory,
    required this.hallmarkScores,
    required this.keyBioMarkers,
    required this.sixMonthProjection,
  });

  @override
  List<Object?> get props => [id, compiledAt, chronologicalAge, biologicalAge, ageGap];
}
