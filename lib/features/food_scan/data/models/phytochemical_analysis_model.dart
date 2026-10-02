import '../../domain/entities/phytochemical_analysis.dart';

class PhytochemicalAnalysisModel extends PhytochemicalAnalysis {
  const PhytochemicalAnalysisModel({
    required String id,
    required DateTime analyzedAt,
    required double totalAgeScore,
    required double polyphenolScore,
    required double biologicalAgeCostMinutes,
    required List<String> guidanceList,
    required String metric1Label,
    required String metric1Value,
    required String metric2Label,
    required String metric2Value,
    required String aiQuestion,
    required String dailyGoal,
  }) : super(
          id: id,
          analyzedAt: analyzedAt,
          totalAgeScore: totalAgeScore,
          polyphenolScore: polyphenolScore,
          biologicalAgeCostMinutes: biologicalAgeCostMinutes,
          guidanceList: guidanceList,
          metric1Label: metric1Label,
          metric1Value: metric1Value,
          metric2Label: metric2Label,
          metric2Value: metric2Value,
          aiQuestion: aiQuestion,
          dailyGoal: dailyGoal,
        );

  factory PhytochemicalAnalysisModel.fromJson(Map<String, dynamic> json) {
    return PhytochemicalAnalysisModel(
      id: json['id'],
      analyzedAt: DateTime.parse(json['analyzedAt']),
      totalAgeScore: (json['totalAgeScore'] as num).toDouble(),
      polyphenolScore: (json['polyphenolScore'] as num).toDouble(),
      biologicalAgeCostMinutes: (json['biologicalAgeCostMinutes'] as num).toDouble(),
      guidanceList: List<String>.from(json['guidanceList'] ?? []),
      metric1Label: json['metric1Label'] ?? 'Glucose Spike',
      metric1Value: json['metric1Value'] ?? '+12 mg/dL',
      metric2Label: json['metric2Label'] ?? 'Microbiome',
      metric2Value: json['metric2Value'] ?? 'Nourished',
      aiQuestion: json['aiQuestion'] ?? 'How do we optimize longevity today in Instant Meal Impact?',
      dailyGoal: json['dailyGoal'] ?? 'Keep polyphenol levels above 80 today.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'analyzedAt': analyzedAt.toIso8601String(),
      'totalAgeScore': totalAgeScore,
      'polyphenolScore': polyphenolScore,
      'biologicalAgeCostMinutes': biologicalAgeCostMinutes,
      'guidanceList': guidanceList,
      'metric1Label': metric1Label,
      'metric1Value': metric1Value,
      'metric2Label': metric2Label,
      'metric2Value': metric2Value,
      'aiQuestion': aiQuestion,
      'dailyGoal': dailyGoal,
    };
  }
}
