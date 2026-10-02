import 'dart:convert';

/// AEG Longevity Platform — Food Analysis Models
/// Used by ClaudeService.analyzeFoodImage() to represent the AI response.

// ─────────────────────────────────────────────────────────────────────────────
// FoodItem
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single recognised food item within an analysed meal image.
class FoodItem {
  const FoodItem({
    required this.name,
    required this.estimatedGrams,
    required this.ageScore,
    required this.phytochemicals,
    required this.preparationMethod,
  });

  /// Common food name (e.g. "Wild blueberries")
  final String name;

  /// AI-estimated portion size in grams
  final double estimatedGrams;

  /// AEG age-impact score: positive = pro-longevity, negative = pro-aging
  /// Range: -100 to +100
  final double ageScore;

  /// List of identified phytochemical compound names in this food
  final List<String> phytochemicals;

  /// Detected or inferred preparation method (e.g. "raw", "steamed", "fried")
  final String preparationMethod;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String? ?? '',
      estimatedGrams: (json['estimatedGrams'] as num?)?.toDouble() ?? 0.0,
      ageScore: (json['ageScore'] as num?)?.toDouble() ?? 0.0,
      phytochemicals: List<String>.from(
        (json['phytochemicals'] as List<dynamic>?) ?? [],
      ),
      preparationMethod: json['preparationMethod'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimatedGrams': estimatedGrams,
        'ageScore': ageScore,
        'phytochemicals': phytochemicals,
        'preparationMethod': preparationMethod,
      };

  @override
  String toString() => 'FoodItem(name: $name, grams: $estimatedGrams)';
}

// ─────────────────────────────────────────────────────────────────────────────
// HallmarkImpact
// ─────────────────────────────────────────────────────────────────────────────

/// Represents how a meal impacts one of the 12 Hallmarks of Aging.
class HallmarkImpact {
  const HallmarkImpact({
    required this.hallmarkName,
    required this.impactScore,
    required this.impactType,
  });

  /// Full hallmark name matching kHallmarks
  final String hallmarkName;

  /// Numeric impact: positive = protective, negative = damaging
  /// Range: -10.0 to +10.0
  final double impactScore;

  /// Qualitative type: 'protective', 'neutral', 'damaging'
  final String impactType;

  factory HallmarkImpact.fromJson(Map<String, dynamic> json) {
    return HallmarkImpact(
      hallmarkName: json['hallmarkName'] as String? ?? '',
      impactScore: (json['impactScore'] as num?)?.toDouble() ?? 0.0,
      impactType: json['impactType'] as String? ?? 'neutral',
    );
  }

  Map<String, dynamic> toJson() => {
        'hallmarkName': hallmarkName,
        'impactScore': impactScore,
        'impactType': impactType,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// FoodAnalysisResult
// ─────────────────────────────────────────────────────────────────────────────

/// Complete AI-generated analysis of a meal photograph.
class FoodAnalysisResult {
  const FoodAnalysisResult({
    required this.id,
    required this.analyzedAt,
    required this.items,
    required this.totalAgeScore,
    required this.polyphenolScore,
    required this.hallmarkImpacts,
    required this.guidanceList,
    this.portionLimits = const [],
    this.biologicalAgeCostMinutes = 0.0,
    this.metric1Label = '',
    this.metric1Value = '',
    this.metric2Label = '',
    this.metric2Value = '',
    this.aiQuestion = '',
    this.dailyGoal = '',
  });

  /// UUID for this analysis session
  final String id;

  /// Timestamp of the analysis
  final DateTime analyzedAt;

  /// Detected food items in the image
  final List<FoodItem> items;

  /// Aggregate anti-aging score for the entire meal (0–100)
  final double totalAgeScore;

  /// Estimated total polyphenol density score (0–100)
  final double polyphenolScore;

  /// Per-hallmark impact breakdown
  final List<HallmarkImpact> hallmarkImpacts;

  /// Actionable guidanceList to optimise the meal (e.g. "Add broccoli sprouts")
  final List<String> guidanceList;

  /// Portion warnings (e.g. "Limit red meat to 80 g")
  final List<String> portionLimits;

  /// Estimated biological age impact of this meal in minutes
  /// Positive = meal ages you; negative = meal reverses age
  final double biologicalAgeCostMinutes;

  final String metric1Label;
  final String metric1Value;
  final String metric2Label;
  final String metric2Value;

  final String aiQuestion;
  final String dailyGoal;

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    return FoodAnalysisResult(
      id: json['id'] as String? ?? '',
      analyzedAt: json['analyzedAt'] != null
          ? DateTime.parse(json['analyzedAt'] as String)
          : DateTime.now(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAgeScore: (json['totalAgeScore'] as num?)?.toDouble() ?? 0.0,
      polyphenolScore: (json['polyphenolScore'] as num?)?.toDouble() ?? 0.0,
      hallmarkImpacts: (json['hallmarkImpacts'] as List<dynamic>?)
              ?.map((e) => HallmarkImpact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      guidanceList:
          List<String>.from((json['guidanceList'] as List<dynamic>?) ?? []),
      portionLimits:
          List<String>.from((json['portionLimits'] as List<dynamic>?) ?? []),
      biologicalAgeCostMinutes:
          (json['biologicalAgeCostMinutes'] as num?)?.toDouble() ?? 0.0,
      metric1Label: json['metric1Label'] as String? ?? 'Glucose Spike',
      metric1Value: json['metric1Value'] as String? ?? '+12 mg/dL',
      metric2Label: json['metric2Label'] as String? ?? 'Microbiome',
      metric2Value: json['metric2Value'] as String? ?? 'Nourished',
      aiQuestion: json['aiQuestion'] as String? ?? 'How do we optimize longevity today in Instant Meal Impact?',
      dailyGoal: json['dailyGoal'] as String? ?? 'Keep polyphenol levels above 80 today.',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'analyzedAt': analyzedAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'totalAgeScore': totalAgeScore,
        'polyphenolScore': polyphenolScore,
        'hallmarkImpacts': hallmarkImpacts.map((e) => e.toJson()).toList(),
        'guidanceList': guidanceList,
        'portionLimits': portionLimits,
        'biologicalAgeCostMinutes': biologicalAgeCostMinutes,
        'metric1Label': metric1Label,
        'metric1Value': metric1Value,
        'metric2Label': metric2Label,
        'metric2Value': metric2Value,
        'aiQuestion': aiQuestion,
        'dailyGoal': dailyGoal,
      };

  /// Convenience: serialize to JSON string
  String toJsonString() => jsonEncode(toJson());
}
