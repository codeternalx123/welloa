import 'dart:convert';

/// AEG Longevity Platform — Causal Insight Models
/// Supports do-calculus-style causal inference results returned by the AI.
/// Based on Pearl's do-operator framework for counterfactual health reasoning.

// ─────────────────────────────────────────────────────────────────────────────
// CausalVariable
// ─────────────────────────────────────────────────────────────────────────────

/// An input variable fed into the causal inference analysis.
class CausalVariable {
  const CausalVariable({
    required this.name,
    required this.value,
    required this.unit,
    required this.category,
  });

  /// Variable name (e.g. "Sleep Duration", "HRV", "Alcohol Units")
  final String name;

  /// Current observed value as a string (supports categorical + numeric)
  final String value;

  /// Measurement unit (e.g. "hours", "ms", "servings")
  final String unit;

  /// Category grouping: 'sleep', 'nutrition', 'exercise', 'stress', 'environment'
  final String category;

  factory CausalVariable.fromJson(Map<String, dynamic> json) {
    return CausalVariable(
      name: json['name'] as String? ?? '',
      value: json['value']?.toString() ?? '',
      unit: json['unit'] as String? ?? '',
      category: json['category'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'unit': unit,
        'category': category,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// CausalOutcome
// ─────────────────────────────────────────────────────────────────────────────

/// The downstream health outcome being causally explained.
class CausalOutcome {
  const CausalOutcome({
    required this.metric,
    required this.value,
    required this.unit,
    required this.temporalExtentHours,
    required this.description,
  });

  /// Outcome metric name (e.g. "Biological Age Cost", "Recovery Score")
  final String metric;

  /// Observed or predicted outcome value
  final double value;

  /// Unit of the outcome (e.g. "years", "score 0–100", "minutes")
  final String unit;

  /// Time window over which the causal effect is measured (in hours)
  final double temporalExtentHours;

  /// Human-readable description of what this outcome means
  final String description;

  factory CausalOutcome.fromJson(Map<String, dynamic> json) {
    return CausalOutcome(
      metric: json['metric'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      temporalExtentHours:
          (json['temporalExtentHours'] as num?)?.toDouble() ?? 24.0,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'value': value,
        'unit': unit,
        'temporalExtentHours': temporalExtentHours,
        'description': description,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// CounterfactualScenario
// ─────────────────────────────────────────────────────────────────────────────

/// A do-calculus counterfactual: "What if X had been Y instead?"
class CounterfactualScenario {
  const CounterfactualScenario({
    required this.description,
    required this.changedVariable,
    required this.changedValue,
    required this.alternativeOutcome,
    required this.deltaVsActual,
  });

  /// Plain-English description of the counterfactual hypothesis
  final String description;

  /// Which variable was intervened on (do-operator target)
  final String changedVariable;

  /// The hypothetical value that was set via adjustment
  final String changedValue;

  /// What the outcome would have been under this counterfactual
  final double alternativeOutcome;

  /// Difference between counterfactual and actual outcome
  /// Positive = counterfactual is worse; negative = counterfactual is better
  final double deltaVsActual;

  factory CounterfactualScenario.fromJson(Map<String, dynamic> json) {
    return CounterfactualScenario(
      description: json['description'] as String? ?? '',
      changedVariable: json['changedVariable'] as String? ?? '',
      changedValue: json['changedValue']?.toString() ?? '',
      alternativeOutcome:
          (json['alternativeOutcome'] as num?)?.toDouble() ?? 0.0,
      deltaVsActual: (json['deltaVsActual'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'changedVariable': changedVariable,
        'changedValue': changedValue,
        'alternativeOutcome': alternativeOutcome,
        'deltaVsActual': deltaVsActual,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// CausalInsightResult
// ─────────────────────────────────────────────────────────────────────────────

/// Complete causal inference analysis result from the AI engine.
class CausalInsightResult {
  const CausalInsightResult({
    required this.id,
    required this.analyzedAt,
    required this.inputVariables,
    required this.outcome,
    required this.causalConfidence,
    required this.doOperatorQuery,
    required this.counterfactuals,
    required this.narrative,
  });

  /// UUID for this analysis
  final String id;

  /// Timestamp of the analysis
  final DateTime analyzedAt;

  /// All input variables passed to the causal model
  final List<CausalVariable> inputVariables;

  /// The observed outcome being explained
  final CausalOutcome outcome;

  /// AI confidence in the causal attribution (0.0–1.0)
  final double causalConfidence;

  /// The formal do-operator query that was evaluated
  /// e.g. "P(Y | do(SleepDuration = 8h), HRV = 65ms)"
  final String doOperatorQuery;

  /// List of counterfactual scenarios exploring alternative outcomes
  final List<CounterfactualScenario> counterfactuals;

  /// Natural-language causal narrative for the user
  final String narrative;

  factory CausalInsightResult.fromJson(Map<String, dynamic> json) {
    return CausalInsightResult(
      id: json['id'] as String? ?? '',
      analyzedAt: json['analyzedAt'] != null
          ? DateTime.parse(json['analyzedAt'] as String)
          : DateTime.now(),
      inputVariables: (json['inputVariables'] as List<dynamic>?)
              ?.map(
                  (e) => CausalVariable.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      outcome: CausalOutcome.fromJson(
        json['outcome'] as Map<String, dynamic>? ?? {},
      ),
      causalConfidence:
          (json['causalConfidence'] as num?)?.toDouble() ?? 0.0,
      doOperatorQuery: json['doOperatorQuery'] as String? ?? '',
      counterfactuals: (json['counterfactuals'] as List<dynamic>?)
              ?.map((e) =>
                  CounterfactualScenario.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      narrative: json['narrative'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'analyzedAt': analyzedAt.toIso8601String(),
        'inputVariables': inputVariables.map((e) => e.toJson()).toList(),
        'outcome': outcome.toJson(),
        'causalConfidence': causalConfidence,
        'doOperatorQuery': doOperatorQuery,
        'counterfactuals': counterfactuals.map((e) => e.toJson()).toList(),
        'narrative': narrative,
      };

  /// Convenience: serialize to JSON string
  String toJsonString() => jsonEncode(toJson());
}
