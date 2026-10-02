import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_metrics_models.dart';

/// AI-powered health insights engine
class AIHealthInsightsEngine {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  // ============================================
  // PATTERN RECOGNITION
  // ============================================

  /// Analyze glucose patterns and generate insights
  Future<List<HealthInsight>> analyzeGlucosePatterns({
    required List<GlucoseReading> readings,
  }) async {
    if (readings.length < 7) return []; // Need at least a week of data

    List<HealthInsight> insights = [];

    // Pattern 1: Consistent spikes at specific times
    final timePatterns = _detectTimePatterns(readings);
    if (timePatterns.isNotEmpty) {
      final pattern = timePatterns;
      insights.add(
        HealthInsight(
          id: _firestore.collection('health_insights').doc().id,
          userId: _userId,
          title: 'Recurring Glucose Spike Detected',
          description:
              'Your glucose tends to spike at ${pattern['time']} (average ${pattern['spike']} mg/dL above normal). This happens on ${pattern['frequency']}% of days.',
          type: InsightType.glucose,
          priority: InsightPriority.high,
          recommendations: [
            'Review what you typically eat around this time',
            'Consider a 10-minute walk after this meal',
            'Try adding more protein and fiber to slow absorption',
            'Monitor closely and adjust meal timing if needed',
          ],
          data: pattern,
          generatedAt: DateTime.now(),
        ),
      );
    }

    // Pattern 2: Post-meal glucose responses
    final mealPatterns = await _analyzeMealPatterns();
    if (mealPatterns.isNotEmpty) {
      insights.addAll(mealPatterns);
    }

    // Pattern 3: Overnight glucose trends
    final overnightInsight = _analyzeOvernightGlucose(readings);
    if (overnightInsight != null) {
      insights.add(overnightInsight);
    }

    // Pattern 4: Glucose variability
    final variabilityInsight = _analyzeGlucoseVariability(readings);
    if (variabilityInsight != null) {
      insights.add(variabilityInsight);
    }

    // Save insights
    for (var insight in insights) {
      await _firestore
          .collection('health_insights')
          .doc(insight.id)
          .set(insight.toJson());
    }

    return insights;
  }

  /// Detect time-based glucose patterns
  Map<String, dynamic> _detectTimePatterns(List<GlucoseReading> readings) {
    // Group readings by hour
    Map<int, List<double>> hourlyReadings = {};

    for (var reading in readings) {
      final hour = reading.timestamp.hour;
      hourlyReadings.putIfAbsent(hour, () => []);
      hourlyReadings[hour]!.add(reading.glucoseLevel);
    }

    // Find hours with consistently high readings
    Map<String, dynamic> pattern = {};
    double maxAverage = 0;
    int spikeHour = 0;

    hourlyReadings.forEach((hour, values) {
      if (values.length < 3) return; // Need multiple data points
      final average = values.reduce((a, b) => a + b) / values.length;
      if (average > 180 && average > maxAverage) {
        maxAverage = average;
        spikeHour = hour;
      }
    });

    if (maxAverage > 0) {
      pattern = {
        'time': _formatHour(spikeHour),
        'spike': maxAverage.toInt(),
        'frequency': (hourlyReadings[spikeHour]!.length / readings.length * 100)
            .toInt(),
      };
    }

    return pattern;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  /// Analyze meal-glucose patterns
  Future<List<HealthInsight>> _analyzeMealPatterns() async {
    if (_userId.isEmpty) return [];

    final snapshot = await _firestore
        .collection('meal_glucose_correlations')
        .where('meal_data.user_id', isEqualTo: _userId)
        .orderBy('meal_time', descending: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) return [];

    List<HealthInsight> insights = [];

    // Find meals that consistently cause high spikes
    Map<String, List<double>> mealImpacts = {};

    for (var doc in snapshot.docs) {
      final mealName = doc.data()['meal_name'] as String? ?? '';
      final spike = (doc.data()['spike'] as num?)?.toDouble() ?? 0;

      mealImpacts.putIfAbsent(mealName, () => []);
      mealImpacts[mealName]!.add(spike);
    }

    // Generate insights for problematic meals
    mealImpacts.forEach((mealName, spikes) {
      if (spikes.length < 2) return;
      final avgSpike = spikes.reduce((a, b) => a + b) / spikes.length;

      if (avgSpike > 50) {
        insights.add(
          HealthInsight(
            id: _firestore.collection('health_insights').doc().id,
            userId: _userId,
            title: 'High-Impact Meal Identified',
            description:
                '$mealName causes an average glucose spike of ${avgSpike.toInt()} mg/dL. Consider modifying this meal.',
            type: InsightType.glucose,
            priority: InsightPriority.high,
            recommendations: [
              'Reduce portion size by 25-30%',
              'Add more vegetables for fiber',
              'Pair with lean protein to slow absorption',
              'Try whole grain alternatives',
            ],
            data: {
              'meal_name': mealName,
              'avg_spike': avgSpike,
              'occurrences': spikes.length,
            },
            generatedAt: DateTime.now(),
          ),
        );
      }
    });

    return insights;
  }

  /// Analyze overnight glucose trends
  HealthInsight? _analyzeOvernightGlucose(List<GlucoseReading> readings) {
    // Get readings between 11 PM and 6 AM
    final overnightReadings = readings.where((r) {
      final hour = r.timestamp.hour;
      return hour >= 23 || hour <= 6;
    }).toList();

    if (overnightReadings.length < 5) return null;

    // Check for dawn phenomenon (early morning rise)
    final morningReadings = overnightReadings
        .where((r) => r.timestamp.hour >= 4 && r.timestamp.hour <= 6)
        .toList();

    final nightReadings = overnightReadings
        .where((r) => r.timestamp.hour >= 23 || r.timestamp.hour <= 2)
        .toList();

    if (morningReadings.isEmpty || nightReadings.isEmpty) return null;

    final avgMorning =
        morningReadings.map((r) => r.glucoseLevel).reduce((a, b) => a + b) /
        morningReadings.length;

    final avgNight =
        nightReadings.map((r) => r.glucoseLevel).reduce((a, b) => a + b) /
        nightReadings.length;

    final rise = avgMorning - avgNight;

    if (rise > 20) {
      return HealthInsight(
        id: _firestore.collection('health_insights').doc().id,
        userId: _userId,
        title: 'Dawn Phenomenon Detected',
        description:
            'Your glucose rises by an average of ${rise.toInt()} mg/dL in early morning (4-6 AM). This is called the dawn phenomenon.',
        type: InsightType.glucose,
        priority: InsightPriority.medium,
        recommendations: [
          'Avoid late-night snacks after 9 PM',
          'Try a small protein snack before bed',
          'Exercise in the evening to improve insulin sensitivity',
          'Discuss with your doctor about medication timing',
        ],
        data: {'morning_avg': avgMorning, 'night_avg': avgNight, 'rise': rise},
        generatedAt: DateTime.now(),
      );
    }

    return null;
  }

  /// Analyze glucose variability
  HealthInsight? _analyzeGlucoseVariability(List<GlucoseReading> readings) {
    if (readings.length < 20) return null;

    final values = readings.map((r) => r.glucoseLevel).toList();
    final average = values.reduce((a, b) => a + b) / values.length;

    // Calculate standard deviation
    final variance =
        values
            .map((v) => (v - average) * (v - average))
            .reduce((a, b) => a + b) /
        values.length;
    final stdDev = math.sqrt(variance);

    // Calculate coefficient of variation (CV)
    final cv = (stdDev / average) * 100;

    if (cv > 36) {
      // High variability
      return HealthInsight(
        id: _firestore.collection('health_insights').doc().id,
        userId: _userId,
        title: 'High Glucose Variability Detected',
        description:
            'Your glucose levels are fluctuating more than ideal (CV: ${cv.toInt()}%). More stable glucose is healthier.',
        type: InsightType.glucose,
        priority: InsightPriority.high,
        recommendations: [
          'Eat at consistent times each day',
          'Balance meals with protein, fat, and fiber',
          'Avoid skipping meals',
          'Manage stress through meditation or exercise',
        ],
        data: {'cv': cv, 'std_dev': stdDev, 'average': average},
        generatedAt: DateTime.now(),
      );
    }

    return null;
  }

  // ============================================
  // LIFESTYLE RECOMMENDATIONS
  // ============================================

  /// Generate personalized lifestyle recommendations
  Future<List<String>> generateLifestyleRecommendations({
    required List<GlucoseReading> glucoseReadings,
    required List<WeightEntry> weightEntries,
    required List<SleepEntry> sleepEntries,
    required List<ActivityData> activityData,
  }) async {
    List<String> recommendations = [];

    // Analyze glucose control
    if (glucoseReadings.isNotEmpty) {
      final avgGlucose =
          glucoseReadings.map((r) => r.glucoseLevel).reduce((a, b) => a + b) /
          glucoseReadings.length;

      if (avgGlucose > 140) {
        recommendations.add(
          '🩸 Your average glucose is ${avgGlucose.toInt()} mg/dL. Aim for 100-140 mg/dL through balanced meals.',
        );
      }
    }

    // Analyze weight trend
    if (weightEntries.length >= 2) {
      final latest = weightEntries.first.weight;
      final oldest = weightEntries.last.weight;
      final change = latest - oldest;

      if (change > 2) {
        recommendations.add(
          '⚖️ You\'ve gained ${change.toStringAsFixed(1)} kg. Focus on portion control and increase activity.',
        );
      } else if (change < -2) {
        recommendations.add(
          '🎉 Great job! You\'ve lost ${(-change).toStringAsFixed(1)} kg. Keep up the healthy habits!',
        );
      }
    }

    // Analyze sleep quality
    if (sleepEntries.isNotEmpty) {
      final avgSleepScore =
          sleepEntries.map((s) => s.sleepScore).reduce((a, b) => a + b) /
          sleepEntries.length;

      if (avgSleepScore < 70) {
        recommendations.add(
          '😴 Your sleep quality is below optimal (${avgSleepScore.toInt()}/100). Better sleep improves glucose control.',
        );
      }
    }

    // Analyze activity levels
    if (activityData.isNotEmpty) {
      final avgSteps =
          activityData.map((a) => a.steps).reduce((a, b) => a + b) /
          activityData.length;

      if (avgSteps < 5000) {
        recommendations.add(
          '🚶 Your average daily steps are ${avgSteps.toInt()}. Aim for 10,000 steps to improve health.',
        );
      } else if (avgSteps >= 10000) {
        recommendations.add(
          '🏃 Amazing! You\'re averaging ${avgSteps.toInt()} steps per day. Keep moving!',
        );
      }
    }

    return recommendations;
  }

  // ============================================
  // HEALTH RISK SCORING
  // ============================================

  /// Calculate comprehensive health risk score
  Future<HealthRiskScore> calculateHealthRiskScore({
    required List<GlucoseReading> glucoseReadings,
    required List<WeightEntry> weightEntries,
    required List<BloodPressureReading> bpReadings,
    required List<HbA1cReading> hba1cReadings,
    required List<CholesterolReading> cholesterolReadings,
    required List<ActivityData> activityData,
    required List<SleepEntry> sleepEntries,
  }) async {
    double diabetesRisk = 0;
    double cardiovascularRisk = 0;
    double obesityRisk = 0;

    Map<String, String> riskFactors = {};
    List<String> protectiveFactors = [];

    // Diabetes risk assessment
    if (glucoseReadings.isNotEmpty) {
      final avgGlucose =
          glucoseReadings.map((r) => r.glucoseLevel).reduce((a, b) => a + b) /
          glucoseReadings.length;

      if (avgGlucose > 180) {
        diabetesRisk += 30;
        riskFactors['high_glucose'] =
            'Average glucose: ${avgGlucose.toInt()} mg/dL';
      } else if (avgGlucose > 140) {
        diabetesRisk += 15;
        riskFactors['elevated_glucose'] =
            'Average glucose: ${avgGlucose.toInt()} mg/dL';
      } else {
        protectiveFactors.add('Well-controlled glucose levels');
      }
    }

    // HbA1c risk
    if (hba1cReadings.isNotEmpty) {
      final latestHbA1c = hba1cReadings.first.value;
      if (latestHbA1c >= 6.5) {
        diabetesRisk += 40;
        riskFactors['diabetes'] = 'HbA1c: $latestHbA1c%';
      } else if (latestHbA1c >= 5.7) {
        diabetesRisk += 20;
        riskFactors['prediabetes'] = 'HbA1c: $latestHbA1c%';
      } else {
        protectiveFactors.add('Normal HbA1c levels');
      }
    }

    // Cardiovascular risk - Blood pressure
    if (bpReadings.isNotEmpty) {
      final latestBP = bpReadings.first;
      if (latestBP.systolic >= 140 || latestBP.diastolic >= 90) {
        cardiovascularRisk += 25;
        riskFactors['hypertension'] =
            'BP: ${latestBP.systolic}/${latestBP.diastolic}';
      } else {
        protectiveFactors.add('Healthy blood pressure');
      }
    }

    // Cardiovascular risk - Cholesterol
    if (cholesterolReadings.isNotEmpty) {
      final latest = cholesterolReadings.first;
      if (latest.ldl > 160) {
        cardiovascularRisk += 20;
        riskFactors['high_ldl'] = 'LDL: ${latest.ldl} mg/dL';
      }
      if (latest.hdl < 40) {
        cardiovascularRisk += 15;
        riskFactors['low_hdl'] = 'HDL: ${latest.hdl} mg/dL';
      }
      if (latest.hdl >= 60) {
        protectiveFactors.add('Healthy HDL cholesterol');
      }
    }

    // Obesity risk - BMI
    if (weightEntries.isNotEmpty) {
      final latest = weightEntries.first;
      if (latest.bmi != null) {
        if (latest.bmi! >= 30) {
          obesityRisk += 40;
          riskFactors['obesity'] = 'BMI: ${latest.bmi!.toStringAsFixed(1)}';
        } else if (latest.bmi! >= 25) {
          obesityRisk += 20;
          riskFactors['overweight'] = 'BMI: ${latest.bmi!.toStringAsFixed(1)}';
        } else if (latest.bmi! >= 18.5) {
          protectiveFactors.add('Healthy weight');
        }
      }
    }

    // Activity level
    if (activityData.isNotEmpty) {
      final avgSteps =
          activityData.map((a) => a.steps).reduce((a, b) => a + b) /
          activityData.length;

      if (avgSteps < 3000) {
        diabetesRisk += 10;
        cardiovascularRisk += 10;
        obesityRisk += 10;
        riskFactors['sedentary'] =
            'Low activity: ${avgSteps.toInt()} steps/day';
      } else if (avgSteps >= 10000) {
        protectiveFactors.add('Active lifestyle');
      }
    }

    // Sleep quality
    if (sleepEntries.isNotEmpty) {
      final avgSleepScore =
          sleepEntries.map((s) => s.sleepScore).reduce((a, b) => a + b) /
          sleepEntries.length;

      if (avgSleepScore < 60) {
        diabetesRisk += 5;
        cardiovascularRisk += 5;
        riskFactors['poor_sleep'] = 'Sleep score: ${avgSleepScore.toInt()}/100';
      } else if (avgSleepScore >= 80) {
        protectiveFactors.add('Good sleep quality');
      }
    }

    // Calculate overall score (0-100, higher is better)
    final overallRisk = (diabetesRisk + cardiovascularRisk + obesityRisk) / 3;
    final overallScore = 100 - overallRisk;

    final riskScore = HealthRiskScore(
      userId: _userId,
      overallScore: overallScore.clamp(0, 100),
      diabetesRisk: diabetesRisk.clamp(0, 100),
      cardiovascularRisk: cardiovascularRisk.clamp(0, 100),
      obesityRisk: obesityRisk.clamp(0, 100),
      riskFactors: riskFactors,
      protectiveFactors: protectiveFactors,
      calculatedAt: DateTime.now(),
    );

    // Save risk score
    await _firestore
        .collection('health_risk_scores')
        .doc(_userId)
        .set(riskScore.toJson());

    return riskScore;
  }

  // ============================================
  // WEEKLY/MONTHLY REPORTS
  // ============================================

  /// Generate weekly health report
  Future<HealthReport> generateWeeklyReport() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 7));

    return await _generateReport(
      startDate: startDate,
      endDate: endDate,
      period: ReportPeriod.weekly,
    );
  }

  /// Generate monthly health report
  Future<HealthReport> generateMonthlyReport() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    return await _generateReport(
      startDate: startDate,
      endDate: endDate,
      period: ReportPeriod.monthly,
    );
  }

  /// Generate health report
  Future<HealthReport> _generateReport({
    required DateTime startDate,
    required DateTime endDate,
    required ReportPeriod period,
  }) async {
    // TODO: Fetch all health data for the period
    // TODO: Use AI to analyze trends and generate summary

    Map<String, dynamic> summary = {
      'period': period.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      // Add more summary data
    };

    List<String> achievements = [
      // TODO: Identify achievements
    ];

    List<String> improvements = [
      // TODO: Identify areas for improvement
    ];

    final report = HealthReport(
      id: _firestore.collection('health_reports').doc().id,
      userId: _userId,
      startDate: startDate,
      endDate: endDate,
      period: period,
      summary: summary,
      insights: [], // TODO: Load relevant insights
      trends: {}, // TODO: Calculate trends
      achievements: achievements,
      improvements: improvements,
      generatedAt: DateTime.now(),
    );

    // Save report
    await _firestore
        .collection('health_reports')
        .doc(report.id)
        .set(report.toJson());

    return report;
  }
}
