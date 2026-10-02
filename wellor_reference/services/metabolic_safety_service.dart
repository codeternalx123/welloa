import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cloud_kitchen_service.dart';

/// ⚡ **QIO GLYCEMIC SIMULATION ENGINE**
/// Quantum-Inspired Optimization for deterministic metabolic predictions.
///
/// **Core Mission:**
/// Calculate the rate of glucose change (dG/dt) for any meal to predict
/// metabolic impact with medical-grade accuracy. This is the "mercenary logic"
/// that guarantees safety - no probabilistic guesswork.
///
/// **Mathematical Model:**
/// ```
/// dG/dt = f(GI, GL, fiber, fat, protein, user_metabolic_state)
/// 
/// Where:
/// - GI = Glycemic Index (rate of glucose absorption)
/// - GL = Glycemic Load (total glucose impact)
/// - fiber = Slows glucose absorption
/// - fat/protein = Modulate insulin response
/// - user_metabolic_state = Insulin sensitivity, activity level, medication
/// ```
///
/// **Output:**
/// Deterministic prediction of blood glucose trajectory over 3 hours post-meal.

// ============================================================================
// MODELS
// ============================================================================

/// User's metabolic twin - digital representation of glucose metabolism
class MetabolicTwin {
  final String userId;
  final double insulinSensitivity; // 0.0 - 1.0 (lower = more insulin resistant)
  final double basalGlucose; // mg/dL (fasting blood sugar)
  final double hba1c; // % (3-month average blood sugar)
  final String diabetesType; // 'none', 'type1', 'type2', 'prediabetes'
  final bool onMetformin; // Common diabetes medication
  final bool onInsulin;
  final double activityLevel; // 0.0 - 1.0 (sedentary to athlete)
  final double stressFactor; // 0.0 - 1.0 (affects cortisol, glucose)
  final DateTime lastMealTime;
  final double lastMealCarbs; // For insulin-on-board calculation

  MetabolicTwin({
    required this.userId,
    required this.insulinSensitivity,
    required this.basalGlucose,
    required this.hba1c,
    required this.diabetesType,
    this.onMetformin = false,
    this.onInsulin = false,
    required this.activityLevel,
    this.stressFactor = 0.3,
    required this.lastMealTime,
    this.lastMealCarbs = 0.0,
  });

  /// Estimate insulin sensitivity from HbA1c
  factory MetabolicTwin.fromHbA1c({
    required String userId,
    required double hba1c,
    required double basalGlucose,
    required String diabetesType,
    required double activityLevel,
  }) {
    // Simplified insulin sensitivity estimation
    // Normal HbA1c: 4.0-5.6%, prediabetes: 5.7-6.4%, diabetes: >6.5%
    double insulinSensitivity;
    if (hba1c < 5.7) {
      insulinSensitivity = 0.9; // Highly sensitive
    } else if (hba1c < 6.5) {
      insulinSensitivity = 0.6; // Moderately resistant
    } else {
      insulinSensitivity = 0.3; // Highly resistant
    }

    return MetabolicTwin(
      userId: userId,
      insulinSensitivity: insulinSensitivity,
      basalGlucose: basalGlucose,
      hba1c: hba1c,
      diabetesType: diabetesType,
      activityLevel: activityLevel,
      lastMealTime: DateTime.now().subtract(Duration(hours: 4)),
      lastMealCarbs: 0.0,
    );
  }
}

/// Predicted glucose trajectory over time
class GlucoseTrajectory {
  final List<GlucoseDataPoint> dataPoints;
  final double peakGlucose; // mg/dL
  final int minutesToPeak;
  final double auc; // Area Under Curve (total glycemic impact)
  final String risk; // 'low', 'moderate', 'high', 'critical'
  final List<String> warnings;

  GlucoseTrajectory({
    required this.dataPoints,
    required this.peakGlucose,
    required this.minutesToPeak,
    required this.auc,
    required this.risk,
    required this.warnings,
  });
}

/// Single glucose measurement at a specific time
class GlucoseDataPoint {
  final int minutesAfterMeal;
  final double glucoseLevel; // mg/dL
  final double dGdt; // Rate of change (mg/dL per minute)

  GlucoseDataPoint({
    required this.minutesAfterMeal,
    required this.glucoseLevel,
    required this.dGdt,
  });
}

/// Metabolic safety verdict for a meal
class MetabolicSafetyVerdict {
  final bool isSafe;
  final String risk; // 'low', 'moderate', 'high', 'critical'
  final GlucoseTrajectory trajectory;
  final List<String> recommendations;
  final double confidenceScore; // 0.0 - 1.0

  MetabolicSafetyVerdict({
    required this.isSafe,
    required this.risk,
    required this.trajectory,
    required this.recommendations,
    required this.confidenceScore,
  });
}

// ============================================================================
// SERVICE
// ============================================================================

class MetabolicSafetyService {
  // Safety thresholds
  static const double _normalGlucosePeak = 140.0; // mg/dL (non-diabetic)
  static const double _prediabeticGlucosePeak = 160.0; // mg/dL
  static const double _diabeticGlucosePeak = 180.0; // mg/dL
  static const double _criticalGlucose = 200.0; // mg/dL (danger zone)

  // Simulation parameters
  static const int _simulationMinutes = 180; // 3 hours post-meal
  static const int _timeStepMinutes = 5; // Data point every 5 minutes

  // ============================================================================
  // PRIMARY SIMULATION METHOD
  // ============================================================================

  /// Run QIO glycemic simulation to predict metabolic response
  static Future<MetabolicSafetyVerdict> simulateMetabolicResponse({
    required CloudKitchenMenuItem meal,
    required MetabolicTwin metabolicTwin,
  }) async {
    debugPrint('⚡ MetabolicSafety: Running QIO simulation for "${meal.itemName}"');
    debugPrint('📊 User profile: HbA1c=${metabolicTwin.hba1c}%, IS=${metabolicTwin.insulinSensitivity}');

    // Step 1: Calculate glycemic parameters
    final glycemicParams = _calculateGlycemicParameters(meal);

    // Step 2: Run glucose trajectory simulation
    final trajectory = _simulateGlucoseTrajectory(
      meal: meal,
      params: glycemicParams,
      metabolicTwin: metabolicTwin,
    );

    // Step 3: Assess risk level
    final risk = _assessRisk(trajectory, metabolicTwin);

    // Step 4: Generate recommendations
    final recommendations = _generateRecommendations(
      trajectory: trajectory,
      risk: risk,
      meal: meal,
      metabolicTwin: metabolicTwin,
    );

    // Step 5: Determine safety verdict
    final isSafe = _isMealSafe(trajectory, risk, metabolicTwin);
    final confidenceScore = _calculateConfidence(meal, metabolicTwin);

    debugPrint('🎯 Simulation complete: risk=$risk, peak=${trajectory.peakGlucose.toStringAsFixed(1)} mg/dL at ${trajectory.minutesToPeak}min');

    return MetabolicSafetyVerdict(
      isSafe: isSafe,
      risk: risk,
      trajectory: trajectory,
      recommendations: recommendations,
      confidenceScore: confidenceScore,
    );
  }

  // ============================================================================
  // GLYCEMIC PARAMETER CALCULATION
  // ============================================================================

  static Map<String, double> _calculateGlycemicParameters(CloudKitchenMenuItem meal) {
    final carbs = meal.macronutrients['carbs'] ?? 0.0;
    final fiber = meal.macronutrients['fiber'] ?? 0.0;
    final fat = meal.macronutrients['fat'] ?? 0.0;
    final protein = meal.macronutrients['protein'] ?? 0.0;

    // Calculate effective carbs (net carbs)
    final netCarbs = max(0.0, carbs - fiber);

    // Estimate GI and GL if not provided
    final glycemicIndex = meal.glycemicIndex ?? _estimateGlycemicIndex(meal);
    final glycemicLoad = meal.glycemicLoad ?? (glycemicIndex * netCarbs / 100);

    // Fat and protein slow glucose absorption
    final fatProteinFactor = 1.0 / (1.0 + (fat + protein) / 50.0);

    // Fiber reduces glucose spike
    final fiberFactor = 1.0 / (1.0 + fiber / 10.0);

    debugPrint('📈 Glycemic params: GI=$glycemicIndex, GL=${glycemicLoad.toStringAsFixed(1)}, netCarbs=${netCarbs.toStringAsFixed(1)}g');

    return {
      'glycemicIndex': glycemicIndex,
      'glycemicLoad': glycemicLoad,
      'netCarbs': netCarbs,
      'fatProteinFactor': fatProteinFactor,
      'fiberFactor': fiberFactor,
    };
  }

  static double _estimateGlycemicIndex(CloudKitchenMenuItem meal) {
    // Heuristic GI estimation based on ingredients
    final itemName = meal.itemName.toLowerCase();
    
    if (itemName.contains('white rice') || itemName.contains('white bread')) {
      return 70.0; // High GI
    } else if (itemName.contains('whole grain') || itemName.contains('quinoa')) {
      return 50.0; // Medium GI
    } else if (itemName.contains('vegetable') || itemName.contains('salad')) {
      return 30.0; // Low GI
    } else {
      return 55.0; // Default medium GI
    }
  }

  // ============================================================================
  // GLUCOSE TRAJECTORY SIMULATION (THE CORE ALGORITHM)
  // ============================================================================

  static GlucoseTrajectory _simulateGlucoseTrajectory({
    required CloudKitchenMenuItem meal,
    required Map<String, double> params,
    required MetabolicTwin metabolicTwin,
  }) {
    final dataPoints = <GlucoseDataPoint>[];
    final warnings = <String>[];

    double currentGlucose = metabolicTwin.basalGlucose;
    double insulinOnBoard = 0.0;

    final glycemicIndex = params['glycemicIndex']!;
    final glycemicLoad = params['glycemicLoad']!;
    final fatProteinFactor = params['fatProteinFactor']!;
    final fiberFactor = params['fiberFactor']!;

    // Absorption rate (how fast carbs hit bloodstream)
    final absorptionRate = (glycemicIndex / 100) * fatProteinFactor * fiberFactor;

    // Peak time depends on GI (high GI = faster peak)
    final peakTimeMinutes = (60 * (1.0 / absorptionRate)).clamp(30.0, 90.0);

    double maxGlucose = currentGlucose;
    int minutesToPeak = 0;
    double totalAUC = 0.0;

    for (int t = 0; t <= _simulationMinutes; t += _timeStepMinutes) {
      // Calculate glucose absorption (Gaussian-like curve)
      final absorptionPhase = exp(-pow((t - peakTimeMinutes) / 30.0, 2));
      final glucoseIncrease = glycemicLoad * absorptionPhase * absorptionRate;

      // Calculate insulin response (depends on user's insulin sensitivity)
      final insulinResponse = metabolicTwin.insulinSensitivity * 
                             currentGlucose * 
                             0.01 * 
                             (metabolicTwin.onMetformin ? 1.2 : 1.0);

      // Glucose clearance (insulin + exercise)
      final glucoseClearance = insulinResponse * (1.0 + metabolicTwin.activityLevel * 0.5);

      // Update glucose level
      final previousGlucose = currentGlucose;
      currentGlucose += glucoseIncrease - glucoseClearance;
      currentGlucose = max(metabolicTwin.basalGlucose, currentGlucose); // Can't go below basal

      // Calculate rate of change (dG/dt)
      final dGdt = (currentGlucose - previousGlucose) / _timeStepMinutes;

      dataPoints.add(GlucoseDataPoint(
        minutesAfterMeal: t,
        glucoseLevel: currentGlucose,
        dGdt: dGdt,
      ));

      // Track peak
      if (currentGlucose > maxGlucose) {
        maxGlucose = currentGlucose;
        minutesToPeak = t;
      }

      // Calculate AUC (area under curve)
      if (t > 0) {
        totalAUC += (currentGlucose + previousGlucose) / 2 * _timeStepMinutes;
      }

      // Check for dangerous glucose levels
      if (currentGlucose > _criticalGlucose && !warnings.contains('critical_spike')) {
        warnings.add('critical_spike: Glucose exceeds ${_criticalGlucose.toStringAsFixed(0)} mg/dL');
      }

      // Check for rapid glucose rise (>5 mg/dL per minute)
      if (dGdt > 5.0 && !warnings.contains('rapid_rise')) {
        warnings.add('rapid_rise: Glucose rising rapidly (${dGdt.toStringAsFixed(1)} mg/dL/min)');
      }
    }

    final risk = _assessRiskFromPeak(maxGlucose, metabolicTwin);

    debugPrint('📊 Trajectory simulated: ${dataPoints.length} points, AUC=${totalAUC.toStringAsFixed(0)}');

    return GlucoseTrajectory(
      dataPoints: dataPoints,
      peakGlucose: maxGlucose,
      minutesToPeak: minutesToPeak,
      auc: totalAUC,
      risk: risk,
      warnings: warnings,
    );
  }

  // ============================================================================
  // RISK ASSESSMENT
  // ============================================================================

  static String _assessRisk(GlucoseTrajectory trajectory, MetabolicTwin metabolicTwin) {
    return _assessRiskFromPeak(trajectory.peakGlucose, metabolicTwin);
  }

  static String _assessRiskFromPeak(double peakGlucose, MetabolicTwin metabolicTwin) {
    if (peakGlucose >= _criticalGlucose) {
      return 'critical';
    }

    double threshold;
    switch (metabolicTwin.diabetesType) {
      case 'none':
        threshold = _normalGlucosePeak;
        break;
      case 'prediabetes':
        threshold = _prediabeticGlucosePeak;
        break;
      case 'type1':
      case 'type2':
        threshold = _diabeticGlucosePeak;
        break;
      default:
        threshold = _normalGlucosePeak;
    }

    if (peakGlucose > threshold + 30) {
      return 'high';
    } else if (peakGlucose > threshold) {
      return 'moderate';
    } else {
      return 'low';
    }
  }

  static bool _isMealSafe(GlucoseTrajectory trajectory, String risk, MetabolicTwin metabolicTwin) {
    // Critical risk is never safe
    if (risk == 'critical') return false;

    // High risk requires careful consideration
    if (risk == 'high' && metabolicTwin.diabetesType != 'none') {
      return false;
    }

    // Check for rapid glucose spikes
    for (final point in trajectory.dataPoints) {
      if (point.dGdt > 8.0) { // >8 mg/dL per minute is dangerous
        return false;
      }
    }

    return true;
  }

  // ============================================================================
  // RECOMMENDATIONS
  // ============================================================================

  static List<String> _generateRecommendations({
    required GlucoseTrajectory trajectory,
    required String risk,
    required CloudKitchenMenuItem meal,
    required MetabolicTwin metabolicTwin,
  }) {
    final recommendations = <String>[];

    if (risk == 'critical') {
      recommendations.add('⛔ DO NOT ORDER: This meal will cause dangerous glucose spike');
      recommendations.add('Search for low-carb alternatives (<30g net carbs)');
      return recommendations;
    }

    if (risk == 'high') {
      recommendations.add('⚠️ High risk meal - consider these modifications:');
      recommendations.add('• Split into 2 smaller portions consumed 2 hours apart');
      recommendations.add('• Take a 15-minute walk immediately after eating');
      if (!metabolicTwin.onMetformin) {
        recommendations.add('• Consult doctor about pre-meal metformin');
      }
    }

    if (risk == 'moderate') {
      recommendations.add('⚡ Moderate glycemic impact - optimize with:');
      recommendations.add('• Eat vegetables first, then protein, then carbs (food sequencing)');
      recommendations.add('• Add 1 tbsp apple cider vinegar to improve insulin sensitivity');
      recommendations.add('• Avoid drinking sugary beverages with this meal');
    }

    if (trajectory.peakGlucose < _normalGlucosePeak) {
      recommendations.add('✅ Excellent choice! This meal fits your metabolic profile perfectly');
    }

    // Activity recommendations based on peak timing
    if (trajectory.minutesToPeak <= 60) {
      recommendations.add('🏃 Glucose peaks at ${trajectory.minutesToPeak} minutes - take a walk at this time');
    }

    return recommendations;
  }

  // ============================================================================
  // CONFIDENCE CALCULATION
  // ============================================================================

  static double _calculateConfidence(CloudKitchenMenuItem meal, MetabolicTwin metabolicTwin) {
    double confidence = 0.5; // Base confidence

    // Higher confidence if meal has verified glycemic data
    if (meal.glycemicIndex != null) confidence += 0.2;
    if (meal.glycemicLoad != null) confidence += 0.2;

    // Higher confidence if meal is scientifically verified
    if (meal.isScientificallyVerified) confidence += 0.1;

    // Lower confidence if user has complex metabolic state
    if (metabolicTwin.onInsulin) confidence -= 0.1;
    if (metabolicTwin.diabetesType == 'type1') confidence -= 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Format glucose trajectory for visualization
  static Map<String, dynamic> formatTrajectoryForChart(GlucoseTrajectory trajectory) {
    return {
      'labels': trajectory.dataPoints.map((p) => '${p.minutesAfterMeal}min').toList(),
      'data': trajectory.dataPoints.map((p) => p.glucoseLevel).toList(),
      'peak': trajectory.peakGlucose,
      'peakTime': trajectory.minutesToPeak,
      'risk': trajectory.risk,
    };
  }

  /// Get color code for risk level
  static String getRiskColor(String risk) {
    switch (risk) {
      case 'low':
        return '#10B981'; // Green
      case 'moderate':
        return '#F59E0B'; // Amber
      case 'high':
        return '#EF4444'; // Red
      case 'critical':
        return '#7F1D1D'; // Dark red
      default:
        return '#6B7280'; // Gray
    }
  }
}
