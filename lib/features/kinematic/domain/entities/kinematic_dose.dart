import 'package:equatable/equatable.dart';

class KinematicDose extends Equatable {
  final String id;
  final DateTime timestamp;
  final double hrv;
  final double sleepScore;
  final double cnsReadiness;
  final int recommendedZone;
  final bool requiresAdjustment;
  final double longevityImpactYears;
  final String metric1Label;
  final String metric1Value;
  final String metric2Label;
  final String metric2Value;
  final String nextActionTip;
  final String aiQuestion;
  final String dailyGoal;

  const KinematicDose({
    required this.id,
    required this.timestamp,
    required this.hrv,
    required this.sleepScore,
    required this.cnsReadiness,
    required this.recommendedZone,
    required this.requiresAdjustment,
    required this.longevityImpactYears,
    required this.metric1Label,
    required this.metric1Value,
    required this.metric2Label,
    required this.metric2Value,
    required this.nextActionTip,
    required this.aiQuestion,
    required this.dailyGoal,
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        hrv,
        sleepScore,
        cnsReadiness,
        recommendedZone,
        requiresAdjustment,
        longevityImpactYears,
        metric1Label,
        metric1Value,
        metric2Label,
        metric2Value,
        nextActionTip,
        aiQuestion,
        dailyGoal,
      ];
}
