import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nutrition_calculation.dart';
import '../providers/user_profile_provider.dart';

/// UNICORN GRADE: Biometric Intelligence Nexus.
/// Features: HRV Recovery Indexing, Dynamic TDEE scaling, and Bidirectional Ecosystem Sync.
class HealthNexusService extends ChangeNotifier {
  static final HealthNexusService _instance = HealthNexusService._internal();
  factory HealthNexusService() => _instance;
  HealthNexusService._internal();

  final Health _health = Health();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // High-fidelity types for 2026 metabolic tracking
  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED, // For accurate TDEE
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // Clinical recovery metric
    HealthDataType.SLEEP_SESSION,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.WEIGHT,
    HealthDataType.NUTRITION,
  ];

  // ============================================
  // CORE ORCHESTRATION: THE SYNC ENGINE
  // ============================================

  /// Performs a Deep-Tissue Sync of all biometrics.
  /// Fuses OS-level data with Wellor Clinical Logic.
  Future<MetabolicReport> performDeepSync({required String userId, required UserProfile profile}) async {
    final hasPermission = await _health.requestAuthorization(_types);
    if (!hasPermission) throw Exception('HEALTH_AUTH_REQUIRED');

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // 1. Concurrent Data Retrieval
    final dataPoints = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: startOfToday,
      endTime: now,
    );
    
    // 2. Data Fusion & Normalization
    final snapshot = _fuseBiometricData(dataPoints);

    // 3. Clinical Calculation (The "Lead Dev" Moat)
    final report = _calculateMetabolicAdjustment(snapshot, profile);

    // 4. Persistence & Global State Sync
    await _persistSync(userId, snapshot, report);
    
    notifyListeners();
    return report;
  }

  // ============================================
  // BUSINESS LOGIC: METABOLIC FUSION
  // ============================================

  BiometricSnapshot _fuseBiometricData(List<HealthDataPoint> points) {
    double activeBurn = 0;
    double basalBurn = 0;
    double latestHRV = 50.0;
    int steps = 0;

    for (var p in points) {
      final val = (p.value as NumericHealthValue).numericValue.toDouble();
      switch (p.type) {
        case HealthDataType.STEPS: steps += val.toInt(); break;
        case HealthDataType.ACTIVE_ENERGY_BURNED: activeBurn += val; break;
        case HealthDataType.BASAL_ENERGY_BURNED: basalBurn += val; break;
        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD: latestHRV = val; break;
        default: break;
      }
    }

    return BiometricSnapshot(
      steps: steps,
      activeCalories: activeBurn,
      basalCalories: basalBurn,
      hrvRecovery: latestHRV,
      timestamp: DateTime.now(),
    );
  }

  MetabolicReport _calculateMetabolicAdjustment(BiometricSnapshot bio, UserProfile profile) {
    // Lead Dev Formula: Adjusts targets based on Recovery (HRV) + Total Expenditure
    // Unicorn Feature: If HRV is low, we decrease Carb tolerance to avoid spikes during inflammation.
    
    final tdee = bio.activeCalories + bio.basalCalories;
    final isRecovered = bio.hrvRecovery > 45; // Context-dependent threshold

    return MetabolicReport(
      adjustedCalorieTarget: (tdee * 1.1).round(), // 10% surplus buffer
      carbCeilingG: isRecovered ? (profile.targetCarbs * 1.2) : (profile.targetCarbs * 0.8),
      recoveryStatus: isRecovered ? "High (Fuel Up)" : "Low (Protect Glucose)",
      insight: isRecovered 
        ? "Metabolic readiness is high. You can handle a higher glycemic load today."
        : "Recovery is low. Prioritize protein and keep carbs low to stabilize glucose.",
    );
  }

  // ============================================
  // ECOSYSTEM WRITER: "SOURCE OF TRUTH"
  // ============================================

  /// Pushes Wellor's verified meal data back to the OS Health App.
  /// Ensures Apple/Google Health dashboards are as accurate as Wellor.
  Future<void> exportVerifiedMeal(VerifiedNutritionData meal) async {
    final success = await _health.writeHealthData(
      value: meal.calories,
      type: HealthDataType.NUTRITION,
      startTime: DateTime.now().subtract(const Duration(minutes: 10)),
      endTime: DateTime.now(),
    );
    
    if (success && Platform.isIOS) {
      debugPrint('🍏 HealthKit: Nutrition packet synced.');
    }
  }

  Future<void> _persistSync(String uid, BiometricSnapshot bio, MetabolicReport report) async {
    final docId = DateTime.now().toIso8601String().split('T')[0];
    await _db.collection('users').doc(uid).collection('metabolic_sync').doc(docId).set({
      'biometrics': bio.toJson(),
      'report': report.toJson(),
      'server_timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// ============================================
// MODELS: UNICORN BIOMETRIC DATA
// ============================================

class BiometricSnapshot {
  final int steps;
  final double activeCalories;
  final double basalCalories;
  final double hrvRecovery;
  final DateTime timestamp;

  BiometricSnapshot({required this.steps, required this.activeCalories, 
                    required this.basalCalories, required this.hrvRecovery, required this.timestamp});

  Map<String, dynamic> toJson() => {'steps': steps, 'active_cals': activeCalories, 'hrv': hrvRecovery};
}

class MetabolicReport {
  final int adjustedCalorieTarget;
  final double carbCeilingG;
  final String recoveryStatus;
  final String insight;

  MetabolicReport({required this.adjustedCalorieTarget, required this.carbCeilingG, 
                  required this.recoveryStatus, required this.insight});

  Map<String, dynamic> toJson() => {'cal_target': adjustedCalorieTarget, 'insight': insight};
}