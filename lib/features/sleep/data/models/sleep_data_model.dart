class SleepDataModel {
  final double longevityImpactYears;
  final int clearancePercentage;
  final String metric1Label;
  final String metric1Value;
  final String metric2Label;
  final String metric2Value;
  final String nextActionTip;
  final String aiQuestion;
  final String dailyGoal;

  SleepDataModel({
    required this.longevityImpactYears,
    required this.clearancePercentage,
    required this.metric1Label,
    required this.metric1Value,
    required this.metric2Label,
    required this.metric2Value,
    required this.nextActionTip,
    required this.aiQuestion,
    required this.dailyGoal,
  });

  factory SleepDataModel.fromJson(Map<String, dynamic> json) {
    return SleepDataModel(
      longevityImpactYears: (json['longevityImpactYears'] as num?)?.toDouble() ?? 0.0,
      clearancePercentage: (json['clearancePercentage'] as num?)?.toInt() ?? 0,
      metric1Label: json['metric1Label'] ?? 'Metric 1',
      metric1Value: json['metric1Value'] ?? 'Value 1',
      metric2Label: json['metric2Label'] ?? 'Metric 2',
      metric2Value: json['metric2Value'] ?? 'Value 2',
      nextActionTip: json['nextActionTip'] ?? 'Keep improving your sleep habits.',
      aiQuestion: json['aiQuestion'] ?? 'How do we optimize longevity today in Deep Brain Cleaning?',
      dailyGoal: json['dailyGoal'] ?? 'Achieve 90% Amyloid clearance tonight.',
    );
  }
}
