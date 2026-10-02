import 'dart:convert';

/// AEG Longevity Platform — Bio Twin Models
/// Represents the AI-compiled digital biological twin of the user,
/// including hallmark scores, biomarkers, and age trajectory projections.

// ─────────────────────────────────────────────────────────────────────────────
// HallmarkScore
// ─────────────────────────────────────────────────────────────────────────────

/// The user's current score for a single Hallmark of Aging.
class HallmarkScore {
  const HallmarkScore({
    required this.hallmarkName,
    required this.score,
    required this.trend,
  });

  /// Full name matching kHallmarks (e.g. "Genomic Instability")
  final String hallmarkName;

  /// Current score 0–100: 100 = optimal / youthful, 0 = severely impaired
  final double score;

  /// Trend direction: 'improving', 'stable', 'declining'
  final String trend;

  factory HallmarkScore.fromJson(Map<String, dynamic> json) {
    return HallmarkScore(
      hallmarkName: json['hallmarkName'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 50.0,
      trend: json['trend'] as String? ?? 'stable',
    );
  }

  Map<String, dynamic> toJson() => {
        'hallmarkName': hallmarkName,
        'score': score,
        'trend': trend,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// BioMarker
// ─────────────────────────────────────────────────────────────────────────────

/// A single clinical or wearable biomarker measurement.
class BioMarker {
  const BioMarker({
    required this.name,
    required this.value,
    required this.unit,
    required this.optimalRange,
    required this.status,
  });

  /// Biomarker name (e.g. "HRV", "Fasting Glucose", "VO₂max")
  final String name;

  /// Current measured value
  final double value;

  /// SI or conventional unit (e.g. "ms", "mg/dL", "mL/kg/min")
  final String unit;

  /// Optimal range string for display (e.g. "55–100 ms")
  final String optimalRange;

  /// Classification: 'optimal', 'suboptimal', 'critical'
  final String status;

  factory BioMarker.fromJson(Map<String, dynamic> json) {
    return BioMarker(
      name: json['name'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      optimalRange: json['optimalRange'] as String? ?? '',
      status: json['status'] as String? ?? 'suboptimal',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'unit': unit,
        'optimalRange': optimalRange,
        'status': status,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// SimulationPoint
// ─────────────────────────────────────────────────────────────────────────────

/// A single data point in the 6-month biological age projection.
class SimulationPoint {
  const SimulationPoint({
    required this.monthOffset,
    required this.projectedBioAge,
  });

  /// Month offset from now (0 = current, 6 = six months from now)
  final int monthOffset;

  /// Projected biological age at this time point (years)
  final double projectedBioAge;

  factory SimulationPoint.fromJson(Map<String, dynamic> json) {
    return SimulationPoint(
      monthOffset: json['monthOffset'] as int? ?? 0,
      projectedBioAge: (json['projectedBioAge'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'monthOffset': monthOffset,
        'projectedBioAge': projectedBioAge,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// BioTwinResult
// ─────────────────────────────────────────────────────────────────────────────

/// Complete AI-compiled biological twin result for the user.
class BioTwinResult {
  const BioTwinResult({
    required this.id,
    required this.compiledAt,
    required this.chronologicalAge,
    required this.biologicalAge,
    required this.ageGap,
    required this.reversalRateMonthsPerYear,
    required this.hallmarkScores,
    required this.keyBioMarkers,
    required this.trajectory,
    required this.sixMonthProjection,
  });

  /// UUID for this bio twin compilation
  final String id;

  /// Timestamp of compilation
  final DateTime compiledAt;

  /// User's actual calendar age in years
  final double chronologicalAge;

  /// AI-estimated biological age in years (can be lower = good)
  final double biologicalAge;

  /// Gap: chronologicalAge - biologicalAge
  /// Positive = younger than calendar age (e.g. +3.5 = 3.5 years younger)
  final double ageGap;

  /// Rate of biological age reversal in months per year of effort
  final double reversalRateMonthsPerYear;

  /// Scores for each of the 12 Hallmarks of Aging
  final List<HallmarkScore> hallmarkScores;

  /// Key wearable and clinical biomarkers
  final List<BioMarker> keyBioMarkers;

  /// Overall trajectory label: 'accelerating', 'stable', 'reversing'
  final String trajectory;

  /// Month-by-month projection of biological age over 6 months
  final List<SimulationPoint> sixMonthProjection;

  factory BioTwinResult.fromJson(Map<String, dynamic> json) {
    return BioTwinResult(
      id: json['id'] as String? ?? '',
      compiledAt: json['compiledAt'] != null
          ? DateTime.parse(json['compiledAt'] as String)
          : DateTime.now(),
      chronologicalAge:
          (json['chronologicalAge'] as num?)?.toDouble() ?? 0.0,
      biologicalAge: (json['biologicalAge'] as num?)?.toDouble() ?? 0.0,
      ageGap: (json['ageGap'] as num?)?.toDouble() ?? 0.0,
      reversalRateMonthsPerYear:
          (json['reversalRateMonthsPerYear'] as num?)?.toDouble() ?? 0.0,
      hallmarkScores: (json['hallmarkScores'] as List<dynamic>?)
              ?.map((e) => HallmarkScore.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      keyBioMarkers: (json['keyBioMarkers'] as List<dynamic>?)
              ?.map((e) => BioMarker.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trajectory: json['trajectory'] as String? ?? 'stable',
      sixMonthProjection: (json['sixMonthProjection'] as List<dynamic>?)
              ?.map(
                  (e) => SimulationPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'compiledAt': compiledAt.toIso8601String(),
        'chronologicalAge': chronologicalAge,
        'biologicalAge': biologicalAge,
        'ageGap': ageGap,
        'reversalRateMonthsPerYear': reversalRateMonthsPerYear,
        'hallmarkScores': hallmarkScores.map((e) => e.toJson()).toList(),
        'keyBioMarkers': keyBioMarkers.map((e) => e.toJson()).toList(),
        'trajectory': trajectory,
        'sixMonthProjection':
            sixMonthProjection.map((e) => e.toJson()).toList(),
      };

  /// Convenience: serialize to JSON string
  String toJsonString() => jsonEncode(toJson());
}
