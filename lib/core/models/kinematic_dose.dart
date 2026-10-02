import 'dart:convert';

/// AEG Longevity Platform — Kinematic Intake (Exercise Readiness) Models
/// Used by ClaudeService.evaluateKinematicReadiness() to model
/// AI-compiled daily exercise guidanceList.

// ─────────────────────────────────────────────────────────────────────────────
// PlannedWorkout
// ─────────────────────────────────────────────────────────────────────────────

/// The user's intended workout before AI interception/recompilation.
class PlannedWorkout {
  const PlannedWorkout({
    required this.type,
    required this.durationMinutes,
    required this.intensityPercent,
  });

  /// Type of exercise (e.g. "HIIT", "Zone 2 Cardio", "Strength", "Yoga")
  final String type;

  /// Planned duration in minutes
  final int durationMinutes;

  /// Planned intensity as a percentage of max effort (0–100)
  final int intensityPercent;

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) {
    return PlannedWorkout(
      type: json['type'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      intensityPercent: json['intensityPercent'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'durationMinutes': durationMinutes,
        'intensityPercent': intensityPercent,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// RecompiledWorkout
// ─────────────────────────────────────────────────────────────────────────────

/// The AI-optimised workout prescription after reading biometric inputs.
class RecompiledWorkout {
  const RecompiledWorkout({
    required this.type,
    required this.durationMinutes,
    required this.intensityPercent,
    required this.targetHeartRateZone,
    required this.rationale,
  });

  /// Recommended workout type (may differ from planned)
  final String type;

  /// Recommended duration in minutes
  final int durationMinutes;

  /// Recommended intensity percent (adjusted for readiness)
  final int intensityPercent;

  /// Target heart rate zone (1–5, Karvonen scale)
  final int targetHeartRateZone;

  /// Brief clinical rationale for the recompilation
  final String rationale;

  factory RecompiledWorkout.fromJson(Map<String, dynamic> json) {
    return RecompiledWorkout(
      type: json['type'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      intensityPercent: json['intensityPercent'] as int? ?? 0,
      targetHeartRateZone: json['targetHeartRateZone'] as int? ?? 2,
      rationale: json['rationale'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'durationMinutes': durationMinutes,
        'intensityPercent': intensityPercent,
        'targetHeartRateZone': targetHeartRateZone,
        'rationale': rationale,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// KinematicDoseResult
// ─────────────────────────────────────────────────────────────────────────────

/// Full AI kinematic intake evaluation result combining biometrics, readiness
/// scoring, and the recompiled exercise prescription.
class KinematicDoseResult {
  const KinematicDoseResult({
    required this.id,
    required this.generatedAt,
    required this.hrvScore,
    required this.sleepScore,
    required this.weightDeltaKg,
    required this.cnsReadinessScore,
    required this.hormeticZone,
    required this.originalPlan,
    required this.recompiledWorkout,
    required this.wasIntercepted,
    required this.readinessNarrative,
    required this.zone2Exercises,
  });

  /// UUID for this evaluation
  final String id;

  /// Timestamp of generation
  final DateTime generatedAt;

  /// Overnight HRV in ms (higher = better recovered)
  final double hrvScore;

  /// Sleep quality score (0–100)
  final double sleepScore;

  /// Body weight delta from yesterday in kg (negative = lost)
  final double weightDeltaKg;

  /// Central nervous system readiness score (0–100) computed by AI
  final double cnsReadinessScore;

  /// Hermetic training zone (1–5):
  /// 1 = rest, 2 = gentle, 3 = moderate stimulus, 4 = high stimulus, 5 = peak
  final int hormeticZone;

  /// What the user originally planned
  final PlannedWorkout originalPlan;

  /// AI-recompiled prescription (null if no interception needed)
  final RecompiledWorkout? recompiledWorkout;

  /// Whether the AI intercepted and changed the workout plan
  final bool wasIntercepted;

  /// Narrative explanation of the readiness assessment
  final String readinessNarrative;

  /// Suggested Zone 2 exercise options appropriate for today's readiness
  final List<String> zone2Exercises;

  factory KinematicDoseResult.fromJson(Map<String, dynamic> json) {
    return KinematicDoseResult(
      id: json['id'] as String? ?? '',
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
      hrvScore: (json['hrvScore'] as num?)?.toDouble() ?? 0.0,
      sleepScore: (json['sleepScore'] as num?)?.toDouble() ?? 0.0,
      weightDeltaKg: (json['weightDeltaKg'] as num?)?.toDouble() ?? 0.0,
      cnsReadinessScore:
          (json['cnsReadinessScore'] as num?)?.toDouble() ?? 0.0,
      hormeticZone: json['hormeticZone'] as int? ?? 2,
      originalPlan: PlannedWorkout.fromJson(
        json['originalPlan'] as Map<String, dynamic>? ?? {},
      ),
      recompiledWorkout: json['recompiledWorkout'] != null
          ? RecompiledWorkout.fromJson(
              json['recompiledWorkout'] as Map<String, dynamic>,
            )
          : null,
      wasIntercepted: json['wasIntercepted'] as bool? ?? false,
      readinessNarrative: json['readinessNarrative'] as String? ?? '',
      zone2Exercises:
          List<String>.from((json['zone2Exercises'] as List<dynamic>?) ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'generatedAt': generatedAt.toIso8601String(),
        'hrvScore': hrvScore,
        'sleepScore': sleepScore,
        'weightDeltaKg': weightDeltaKg,
        'cnsReadinessScore': cnsReadinessScore,
        'hormeticZone': hormeticZone,
        'originalPlan': originalPlan.toJson(),
        'recompiledWorkout': recompiledWorkout?.toJson(),
        'wasIntercepted': wasIntercepted,
        'readinessNarrative': readinessNarrative,
        'zone2Exercises': zone2Exercises,
      };

  /// Convenience: serialize to JSON string
  String toJsonString() => jsonEncode(toJson());
}
