import '../../domain/entities/kinematic_dose.dart';

class KinematicDoseModel extends KinematicDose {
  const KinematicDoseModel({
    required String id,
    required DateTime timestamp,
    required double hrv,
    required double sleepScore,
    required double cnsReadiness,
    required int recommendedZone,
    required bool requiresAdjustment,
    required double longevityImpactYears,
    required String metric1Label,
    required String metric1Value,
    required String metric2Label,
    required String metric2Value,
    required String nextActionTip,
    required String aiQuestion,
    required String dailyGoal,
  }) : super(
          id: id,
          timestamp: timestamp,
          hrv: hrv,
          sleepScore: sleepScore,
          cnsReadiness: cnsReadiness,
          recommendedZone: recommendedZone,
          requiresAdjustment: requiresAdjustment,
          longevityImpactYears: longevityImpactYears,
          metric1Label: metric1Label,
          metric1Value: metric1Value,
          metric2Label: metric2Label,
          metric2Value: metric2Value,
          nextActionTip: nextActionTip,
          aiQuestion: aiQuestion,
          dailyGoal: dailyGoal,
        );

  factory KinematicDoseModel.fromJson(Map<String, dynamic> json) {
    return KinematicDoseModel(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      hrv: (json['hrv'] as num).toDouble(),
      sleepScore: (json['sleepScore'] as num).toDouble(),
      cnsReadiness: (json['cnsReadiness'] as num).toDouble(),
      recommendedZone: json['recommendedZone'],
      requiresAdjustment: json['requiresAdjustment'],
      longevityImpactYears: (json['longevityImpactYears'] as num?)?.toDouble() ?? 1.8,
      metric1Label: json['metric1Label'] ?? 'Target Zone',
      metric1Value: json['metric1Value'] ?? 'Zone 2',
      metric2Label: json['metric2Label'] ?? 'Adjustment',
      metric2Value: json['metric2Value'] ?? 'None',
      nextActionTip: json['nextActionTip'] ?? 'Keep optimizing your workout.',
      aiQuestion: json['aiQuestion'] ?? 'How do we optimize longevity today in Exercise Sweet Spot?',
      dailyGoal: json['dailyGoal'] ?? 'Keep your heart rate in Zone 2 for 45 minutes.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'hrv': hrv,
      'sleepScore': sleepScore,
      'cnsReadiness': cnsReadiness,
      'recommendedZone': recommendedZone,
      'requiresAdjustment': requiresAdjustment,
      'longevityImpactYears': longevityImpactYears,
      'metric1Label': metric1Label,
      'metric1Value': metric1Value,
      'metric2Label': metric2Label,
      'metric2Value': metric2Value,
      'nextActionTip': nextActionTip,
      'aiQuestion': aiQuestion,
      'dailyGoal': dailyGoal,
    };
  }
}
