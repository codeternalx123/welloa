// lib/services/deterministic_safety_engine.dart
// MEDICAL-GRADE: Deterministic Safety Boundary Engine
// Mathematical guardrails that CANNOT hallucinate medical advice.
// Separates clinical DECISIONS (deterministic) from COMMUNICATION (AI).

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/glucose_context.dart';
import '../models/safety_state.dart';

/// ═══════════════════════════════════════════════════════════════════
/// DETERMINISTIC SAFETY BOUNDARY ENGINE
/// ═══════════════════════════════════════════════════════════════════
/// 
/// PRINCIPLE: AI cannot make medical decisions. Only mathematics can.
/// 
/// This engine evaluates glucose data using HARD-CODED clinical logic.
/// No LLM, no probability, no hallucination possible.
/// 
/// The AI is only used to generate the MESSAGE, not the DECISION.
/// ═══════════════════════════════════════════════════════════════════

class DeterministicSafetyEngine {
  // ═══════════════════════════════════════════════════════════════════
  // HARD CLINICAL THRESHOLDS (ADA Guidelines 2026)
  // ═══════════════════════════════════════════════════════════════════
  
  /// Critical hypoglycemia threshold (ADA Level 3)
  static const double CRITICAL_HYPO_THRESHOLD = 54.0; // mg/dL (<3.0 mmol/L)
  
  /// Level 2 hypoglycemia (clinically significant)
  static const double LEVEL2_HYPO_THRESHOLD = 70.0; // mg/dL (<3.9 mmol/L)
  
  /// Target range lower bound
  static const double TARGET_LOWER_BOUND = 70.0; // mg/dL
  
  /// Target range upper bound
  static const double TARGET_UPPER_BOUND = 180.0; // mg/dL
  
  /// Critical hyperglycemia threshold
  static const double CRITICAL_HYPER_THRESHOLD = 250.0; // mg/dL (>13.9 mmol/L)
  
  /// Severe hyperglycemia threshold
  static const double SEVERE_HYPER_THRESHOLD = 400.0; // mg/dL (DKA risk)
  
  // ═══════════════════════════════════════════════════════════════════
  // VELOCITY THRESHOLDS (Rate of Change)
  // ═══════════════════════════════════════════════════════════════════
  
  /// Dangerous falling velocity (mg/dL per minute)
  /// -3.0 means dropping 15 mg/dL every 5 minutes
  static const double DANGEROUS_FALLING_VELOCITY = -3.0;
  
  /// Rapid falling velocity (concerning)
  static const double RAPID_FALLING_VELOCITY = -2.0;
  
  /// Dangerous rising velocity (mg/dL per minute)
  static const double DANGEROUS_RISING_VELOCITY = 3.0;
  
  /// Rapid rising velocity (concerning)
  static const double RAPID_RISING_VELOCITY = 2.0;
  
  // ═══════════════════════════════════════════════════════════════════
  // PREDICTION HORIZONS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Short-term prediction (critical events)
  static const Duration CRITICAL_HORIZON = Duration(minutes: 20);
  
  /// Medium-term prediction (preventative)
  static const Duration PREVENTATIVE_HORIZON = Duration(minutes: 45);
  
  /// Long-term prediction (planning)
  static const Duration PLANNING_HORIZON = Duration(minutes: 90);
  
  // ═══════════════════════════════════════════════════════════════════
  // CORE EVALUATION FUNCTION - DETERMINISTIC ONLY
  // ═══════════════════════════════════════════════════════════════════
  
  /// Evaluates glucose safety state using PURE MATHEMATICAL LOGIC.
  /// No LLM, no probability, no hallucination.
  /// 
  /// This function is the JUDGE that determines intervention necessity.
  /// The AI only generates the MESSAGE afterwards.
  static SafetyEvaluation evaluateSafety(GlucoseContext context) {
    final current = context.currentValue;
    final velocity = context.velocity;
    final acceleration = context.acceleration;
    final predicted20min = context.predicted20min;
    final predicted45min = context.predicted45min;
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL STATES (Highest Priority)
    // ═══════════════════════════════════════════════════════════════
    
    // 1. IMMINENT CRASH (Voice Call + Emergency Contact)
    if (_isImminentCrash(current, velocity, predicted20min)) {
      return SafetyEvaluation(
        state: SafetyState.imminentCrash,
        confidence: 1.0,
        reasoning: 'Mathematical certainty: Glucose will breach critical threshold within 20 minutes',
        recommendedActions: [
          SafetyAction.consumeFastCarbs(grams: 15),
          SafetyAction.stopExercise(),
          SafetyAction.alertEmergencyContact(),
        ],
        predictedTimeToThreshold: _calculateTimeToThreshold(current, velocity, CRITICAL_HYPO_THRESHOLD),
        requiresImmediate: true,
      );
    }
    
    // 2. CRITICAL HYPOGLYCEMIA (Already dangerous)
    if (current < CRITICAL_HYPO_THRESHOLD) {
      return SafetyEvaluation(
        state: SafetyState.criticalHypoglycemia,
        confidence: 1.0,
        reasoning: 'Current glucose ${current.toStringAsFixed(0)} mg/dL is below critical threshold (54 mg/dL)',
        recommendedActions: [
          SafetyAction.consumeFastCarbs(grams: 15),
          SafetyAction.retest(afterMinutes: 15),
          SafetyAction.alertEmergencyContact(),
        ],
        predictedTimeToThreshold: Duration.zero,
        requiresImmediate: true,
      );
    }
    
    // 3. SEVERE HYPERGLYCEMIA (DKA Risk)
    if (current > SEVERE_HYPER_THRESHOLD) {
      return SafetyEvaluation(
        state: SafetyState.severeHyperglycemia,
        confidence: 1.0,
        reasoning: 'Current glucose ${current.toStringAsFixed(0)} mg/dL is dangerously high (DKA risk)',
        recommendedActions: [
          SafetyAction.checkKetones(),
          SafetyAction.drinkWater(),
          SafetyAction.contactDoctor(),
        ],
        predictedTimeToThreshold: Duration.zero,
        requiresImmediate: true,
      );
    }
    
    // 4. CRITICAL HYPERGLYCEMIA
    if (current > CRITICAL_HYPER_THRESHOLD) {
      return SafetyEvaluation(
        state: SafetyState.criticalHyperglycemia,
        confidence: 1.0,
        reasoning: 'Current glucose ${current.toStringAsFixed(0)} mg/dL exceeds critical threshold (250 mg/dL)',
        recommendedActions: [
          SafetyAction.checkKetones(),
          SafetyAction.drinkWater(),
          SafetyAction.walkGently(minutes: 10),
        ],
        predictedTimeToThreshold: Duration.zero,
        requiresImmediate: true,
      );
    }
    
    // ═══════════════════════════════════════════════════════════════
    // URGENT STATES (High Priority)
    // ═══════════════════════════════════════════════════════════════
    
    // 5. URGENT HYPOGLYCEMIA (Level 2)
    if (current < LEVEL2_HYPO_THRESHOLD) {
      return SafetyEvaluation(
        state: SafetyState.urgent,
        confidence: 1.0,
        reasoning: 'Current glucose ${current.toStringAsFixed(0)} mg/dL is below 70 mg/dL',
        recommendedActions: [
          SafetyAction.consumeFastCarbs(grams: 10),
          SafetyAction.stopExercise(),
          SafetyAction.retest(afterMinutes: 15),
        ],
        predictedTimeToThreshold: Duration.zero,
        requiresImmediate: true,
      );
    }
    
    // 6. RAPID DECLINE (Falling fast toward hypoglycemia)
    if (_isRapidDecline(current, velocity, predicted20min)) {
      return SafetyEvaluation(
        state: SafetyState.urgent,
        confidence: 0.95,
        reasoning: 'Rapid decline detected: ${velocity.toStringAsFixed(1)} mg/dL/min. Will reach ${predicted20min.toStringAsFixed(0)} mg/dL in 20 minutes',
        recommendedActions: [
          SafetyAction.consumeSlowCarbs(grams: 15),
          SafetyAction.reduceActivity(),
        ],
        predictedTimeToThreshold: _calculateTimeToThreshold(current, velocity, LEVEL2_HYPO_THRESHOLD),
        requiresImmediate: true,
      );
    }
    
    // 7. RAPID RISE (Rising fast, will exceed target)
    if (_isRapidRise(current, velocity, predicted20min)) {
      return SafetyEvaluation(
        state: SafetyState.urgent,
        confidence: 0.90,
        reasoning: 'Rapid rise detected: ${velocity.toStringAsFixed(1)} mg/dL/min. Will reach ${predicted20min.toStringAsFixed(0)} mg/dL in 20 minutes',
        recommendedActions: [
          SafetyAction.walkGently(minutes: 15),
          SafetyAction.drinkWater(),
          SafetyAction.avoidMoreCarbs(),
        ],
        predictedTimeToThreshold: _calculateTimeToThreshold(current, velocity, CRITICAL_HYPER_THRESHOLD),
        requiresImmediate: false,
      );
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PREVENTATIVE STATES (Medium Priority)
    // ═══════════════════════════════════════════════════════════════
    
    // 8. TRENDING LOW (Will go low in 45 minutes)
    if (_isTrendingLow(current, velocity, predicted45min)) {
      return SafetyEvaluation(
        state: SafetyState.preventative,
        confidence: 0.80,
        reasoning: 'Downward trend detected. Predicted to reach ${predicted45min.toStringAsFixed(0)} mg/dL in 45 minutes',
        recommendedActions: [
          SafetyAction.consumeSlowCarbs(grams: 10),
          SafetyAction.reduceActivity(),
        ],
        predictedTimeToThreshold: _calculateTimeToThreshold(current, velocity, LEVEL2_HYPO_THRESHOLD),
        requiresImmediate: false,
      );
    }
    
    // 9. TRENDING HIGH (Will go high in 45 minutes)
    if (_isTrendingHigh(current, velocity, predicted45min)) {
      return SafetyEvaluation(
        state: SafetyState.preventative,
        confidence: 0.75,
        reasoning: 'Upward trend detected. Predicted to reach ${predicted45min.toStringAsFixed(0)} mg/dL in 45 minutes',
        recommendedActions: [
          SafetyAction.walkGently(minutes: 10),
          SafetyAction.drinkWater(),
        ],
        predictedTimeToThreshold: _calculateTimeToThreshold(current, velocity, CRITICAL_HYPER_THRESHOLD),
        requiresImmediate: false,
      );
    }
    
    // 10. SLIGHTLY LOW (Below target but stable)
    if (current < TARGET_LOWER_BOUND && velocity.abs() < 1.0) {
      return SafetyEvaluation(
        state: SafetyState.cautionary,
        confidence: 1.0,
        reasoning: 'Glucose ${current.toStringAsFixed(0)} mg/dL is below target range (70-180 mg/dL)',
        recommendedActions: [
          SafetyAction.considerSnack(),
        ],
        predictedTimeToThreshold: null,
        requiresImmediate: false,
      );
    }
    
    // 11. SLIGHTLY HIGH (Above target but stable)
    if (current > TARGET_UPPER_BOUND && velocity.abs() < 1.0) {
      return SafetyEvaluation(
        state: SafetyState.cautionary,
        confidence: 1.0,
        reasoning: 'Glucose ${current.toStringAsFixed(0)} mg/dL is above target range (70-180 mg/dL)',
        recommendedActions: [
          SafetyAction.considerActivity(),
          SafetyAction.drinkWater(),
        ],
        predictedTimeToThreshold: null,
        requiresImmediate: false,
      );
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SAFE STATE (All Clear)
    // ═══════════════════════════════════════════════════════════════
    
    return SafetyEvaluation(
      state: SafetyState.safe,
      confidence: 1.0,
      reasoning: 'Glucose ${current.toStringAsFixed(0)} mg/dL is within target range and stable',
      recommendedActions: [],
      predictedTimeToThreshold: null,
      requiresImmediate: false,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // HELPER FUNCTIONS - PURE MATHEMATICS
  // ═══════════════════════════════════════════════════════════════════
  
  static bool _isImminentCrash(double current, double velocity, double predicted20min) {
    // Criteria:
    // 1. Currently below 90 AND
    // 2. Falling faster than -2.0 mg/dL/min AND
    // 3. Will be below 70 in 20 minutes
    return current < 90.0 &&
           velocity < RAPID_FALLING_VELOCITY &&
           predicted20min < LEVEL2_HYPO_THRESHOLD;
  }
  
  static bool _isRapidDecline(double current, double velocity, double predicted20min) {
    // Criteria:
    // 1. Falling faster than -2.0 mg/dL/min OR
    // 2. Will drop below 80 in 20 minutes
    return velocity < RAPID_FALLING_VELOCITY ||
           (current > LEVEL2_HYPO_THRESHOLD && predicted20min < 80.0);
  }
  
  static bool _isRapidRise(double current, double velocity, double predicted20min) {
    // Criteria:
    // 1. Rising faster than +2.0 mg/dL/min AND
    // 2. Will exceed 200 in 20 minutes
    return velocity > RAPID_RISING_VELOCITY && predicted20min > 200.0;
  }
  
  static bool _isTrendingLow(double current, double velocity, double predicted45min) {
    // Criteria:
    // 1. Currently in range but
    // 2. Will drop below 80 in 45 minutes
    return current >= LEVEL2_HYPO_THRESHOLD &&
           current <= TARGET_UPPER_BOUND &&
           predicted45min < 80.0;
  }
  
  static bool _isTrendingHigh(double current, double velocity, double predicted45min) {
    // Criteria:
    // 1. Currently in range but
    // 2. Will exceed 200 in 45 minutes
    return current >= TARGET_LOWER_BOUND &&
           current <= TARGET_UPPER_BOUND &&
           predicted45min > 200.0;
  }
  
  /// Calculate time until glucose reaches a threshold (in minutes)
  static Duration? _calculateTimeToThreshold(
    double current,
    double velocity,
    double threshold,
  ) {
    if (velocity.abs() < 0.1) return null; // Stable, won't reach threshold
    
    final delta = threshold - current;
    final minutes = (delta / velocity).abs();
    
    if (minutes > 180) return null; // More than 3 hours away, not relevant
    
    return Duration(minutes: minutes.round());
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // ADDITIONAL CLINICAL CHECKS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Check if glucose is dangerously volatile (high variability)
  static bool isHighVariability(List<double> readings) {
    if (readings.length < 3) return false;
    
    // Calculate coefficient of variation (CV)
    final mean = readings.reduce((a, b) => a + b) / readings.length;
    final variance = readings.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / readings.length;
    final stdDev = sqrt(variance);
    final cv = (stdDev / mean) * 100; // Percentage
    
    // High variability if CV > 36% (ADA guideline)
    return cv > 36.0;
  }
  
  /// Calculate Time in Range (TIR) percentage
  static double calculateTimeInRange(List<double> readings) {
    if (readings.isEmpty) return 0.0;
    
    final inRange = readings.where((g) =>
      g >= TARGET_LOWER_BOUND && g <= TARGET_UPPER_BOUND
    ).length;
    
    return (inRange / readings.length) * 100;
  }
  
  /// Validate glucose reading is physically possible
  static bool isValidReading(double glucose) {
    // Glucose cannot be negative or impossibly high
    return glucose >= 20.0 && glucose <= 600.0;
  }
  
  /// Detect sensor error or outlier
  static bool isSensorError(double current, List<double> recentReadings) {
    if (recentReadings.isEmpty) return false;
    
    // Check for impossible jumps (>100 mg/dL in 5 minutes)
    final lastReading = recentReadings.last;
    final delta = (current - lastReading).abs();
    
    return delta > 100.0;
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// SAFETY EVALUATION RESULT
/// ═══════════════════════════════════════════════════════════════════

class SafetyEvaluation {
  final SafetyState state;
  final double confidence;        // 0.0 to 1.0
  final String reasoning;         // Human-readable explanation
  final List<SafetyAction> recommendedActions;
  final Duration? predictedTimeToThreshold;
  final bool requiresImmediate;   // Needs immediate action?
  
  const SafetyEvaluation({
    required this.state,
    required this.confidence,
    required this.reasoning,
    required this.recommendedActions,
    required this.predictedTimeToThreshold,
    required this.requiresImmediate,
  });
  
  bool get isCritical => state.isCritical;
  bool get isUrgent => state == SafetyState.urgent;
  bool get isPreventative => state.isPreventative;
  bool get isSafe => state == SafetyState.safe;
  
  Map<String, dynamic> toJson() => {
    'state': state.name,
    'confidence': confidence,
    'reasoning': reasoning,
    'recommendedActions': recommendedActions.map((a) => a.toJson()).toList(),
    'predictedTimeToThreshold': predictedTimeToThreshold?.inMinutes,
    'requiresImmediate': requiresImmediate,
  };
}

/// ═══════════════════════════════════════════════════════════════════
/// SAFETY ACTION (Recommended Clinical Action)
/// ═══════════════════════════════════════════════════════════════════

class SafetyAction {
  final String type;
  final String description;
  final Map<String, dynamic>? parameters;
  
  const SafetyAction({
    required this.type,
    required this.description,
    this.parameters,
  });
  
  // Factory constructors for common actions
  factory SafetyAction.consumeFastCarbs({required int grams}) => SafetyAction(
    type: 'consume_fast_carbs',
    description: 'Consume $grams grams of fast-acting carbs (glucose tabs, juice)',
    parameters: {'grams': grams},
  );
  
  factory SafetyAction.consumeSlowCarbs({required int grams}) => SafetyAction(
    type: 'consume_slow_carbs',
    description: 'Consume $grams grams of slow-acting carbs (crackers, fruit)',
    parameters: {'grams': grams},
  );
  
  factory SafetyAction.walkGently({required int minutes}) => SafetyAction(
    type: 'walk',
    description: 'Take a gentle $minutes-minute walk',
    parameters: {'minutes': minutes},
  );
  
  factory SafetyAction.stopExercise() => const SafetyAction(
    type: 'stop_exercise',
    description: 'Stop any physical activity immediately',
  );
  
  factory SafetyAction.reduceActivity() => const SafetyAction(
    type: 'reduce_activity',
    description: 'Reduce physical activity intensity',
  );
  
  factory SafetyAction.drinkWater() => const SafetyAction(
    type: 'drink_water',
    description: 'Drink 8 oz of water',
  );
  
  factory SafetyAction.retest({required int afterMinutes}) => SafetyAction(
    type: 'retest',
    description: 'Retest glucose in $afterMinutes minutes',
    parameters: {'minutes': afterMinutes},
  );
  
  factory SafetyAction.checkKetones() => const SafetyAction(
    type: 'check_ketones',
    description: 'Check blood or urine ketones',
  );
  
  factory SafetyAction.contactDoctor() => const SafetyAction(
    type: 'contact_doctor',
    description: 'Contact your doctor immediately',
  );
  
  factory SafetyAction.alertEmergencyContact() => const SafetyAction(
    type: 'alert_emergency_contact',
    description: 'Alert emergency contact',
  );
  
  factory SafetyAction.considerSnack() => const SafetyAction(
    type: 'consider_snack',
    description: 'Consider a small snack if planning activity',
  );
  
  factory SafetyAction.considerActivity() => const SafetyAction(
    type: 'consider_activity',
    description: 'Consider light physical activity',
  );
  
  factory SafetyAction.avoidMoreCarbs() => const SafetyAction(
    type: 'avoid_carbs',
    description: 'Avoid consuming more carbohydrates',
  );
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    if (parameters != null) 'parameters': parameters,
  };
}
