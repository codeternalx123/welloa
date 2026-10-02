import 'package:equatable/equatable.dart';

class PhytochemicalAnalysis extends Equatable {
  final String id;
  final DateTime analyzedAt;
  final double totalAgeScore;
  final double polyphenolScore;
  final double biologicalAgeCostMinutes;
  final List<String> guidanceList;
  final String metric1Label;
  final String metric1Value;
  final String metric2Label;
  final String metric2Value;
  final String aiQuestion;
  final String dailyGoal;

  const PhytochemicalAnalysis({
    required this.id,
    required this.analyzedAt,
    required this.totalAgeScore,
    required this.polyphenolScore,
    required this.biologicalAgeCostMinutes,
    required this.guidanceList,
    required this.metric1Label,
    required this.metric1Value,
    required this.metric2Label,
    required this.metric2Value,
    required this.aiQuestion,
    required this.dailyGoal,
  });

  @override
  List<Object?> get props => [id, analyzedAt, totalAgeScore, polyphenolScore, biologicalAgeCostMinutes, metric1Label, metric1Value, metric2Label, metric2Value, aiQuestion, dailyGoal];
}
