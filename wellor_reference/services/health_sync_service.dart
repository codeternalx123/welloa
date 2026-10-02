import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nutrition_calculation.dart';
import '../providers/user_profile_provider.dart';

/// UNICORN GRADE: Biometric Intelligence & Ecosystem Nexus.
/// Orchestrates Google/Apple Health sync and adjusts metabolic targets in real-time.
class HealthSyncService extends ChangeNotifier {
  static final HealthSyncService _instance = HealthSyncService._internal();
  factory HealthSyncService() => _instance;
  HealthSyncService._internal();

  final Health _health = Health();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // High-fidelity types for 2026 clinical-grade tracking
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED, // Key for Dynamic TDEE
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // Unicorn: Recovery Indexing
    HealthDataType.SLEEP_SESSION,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.WEIGHT,
    HealthDataType.NUTRITION,
    HealthDataType.WATER,
  ];

  // ============================================
  // PERMISSIONS & AUTH
  // ============================================

  Future<bool> requestPermissions() async {
    try {
      final permissions = _dataTypes.map((type) {
        if (type == HealthDataType.NUTRITION || type == HealthDataType.WATER) {
          return HealthDataAccess.READ_WRITE;
        }
        return HealthDataAccess.READ;
      }).toList();

      final granted = await _health.requestAuthorization(
        _dataTypes,
        permissions: permissions,
      );

      debugPrint('✅ Health Ecosystem: Permissions ${granted ? "Authorized" : "Denied"}');
      return granted;
    } catch (e) {
      debugPrint('❌ Health Auth Error: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    return await _health.hasPermissions(_dataTypes) ?? false;
  }

  // ============================================
  // CORE ORCHESTRATION: THE DEEP SYNC
  // ============================================

  /// Syncs OS-level biometrics and calculates Metabolic Adjustment.
  /// Call on app launch or after logging a high-intensity activity.
  Future<Map<String, dynamic>> syncHealthData({
    required String userId,
    required UserProfile profile,
  }) async {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day);

    try {
      // 1. Fetch concurrent biometric streams
      final healthData = await _health.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: startTime,
        endTime: now,
      );

      if (healthData.isEmpty) return {'success': false, 'message': 'No recent biometrics'};

      // 2. Data Fusion: Convert raw points into a metabolic snapshot
      final snapshot = _fuseBiometricStreams(healthData);

      // 3. Clinical Calculation: Determine dynamic target shifts
      final adjustment = _calculateMetabolicAdjustment(snapshot, profile);

      // 4. Persistence: Sync to Cloud and update local state
      await _saveMetabolicState(userId, snapshot, adjustment);

      notifyListeners();
      return {
        'success': true,
        'adjustment': adjustment,
        'snapshot': snapshot,
      };
    } catch (e) {
      debugPrint('❌ Metabolic Sync Failure: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================
  // METABOLIC INTELLIGENCE (The Moat)
  // ============================================

  BiometricSnapshot _fuseBiometricStreams(List<HealthDataPoint> points) {
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
      activeCals: activeBurn,
      basalCals: basalBurn,
      hrvRecovery: latestHRV,
    );
  }

  MetabolicAdjustment _calculateMetabolicAdjustment(BiometricSnapshot bio, UserProfile profile) {
    // Lead Dev Formula: Dynamic TDEE + Recovery-based Scaling
    // If Recovery (HRV) is low, we decrease carb tolerance to avoid spikes.
    final tdee = bio.activeCals + bio.basalCals;
    final isRecovered = bio.hrvRecovery > 45;

    return MetabolicAdjustment(
      calorieTarget: (tdee * 1.1).round(), // 10% safety buffer
      carbCeilingG: isRecovered ? (profile.targetCarbs * 1.15) : (profile.targetCarbs * 0.85),
      status: isRecovered ? "Optimal Recovery" : "Under-recovered",
      insight: isRecovered 
          ? "Recovery is high. Your metabolism is primed for higher glycemic complexity."
          : "Systemic stress detected. Prioritize protein and keep carbs low to stabilize glucose.",
    );
  }

  // ============================================
  // ECOSYSTEM WRITE: SOURCE OF TRUTH
  // ============================================

  /// Exports Wellor's verified nutrition back to the OS Health app.
  Future<void> writeMealToHealthKit(VerifiedNutritionData meal) async {
    try {
      await _health.writeHealthData(
        value: meal.calories,
        type: HealthDataType.NUTRITION,
        startTime: DateTime.now().subtract(const Duration(minutes: 15)),
        endTime: DateTime.now(),
      );
      debugPrint('🍏 Ecosystem Sync: Verified meal exported.');
    } catch (e) {
      debugPrint('❌ Ecosystem Write Failure: $e');
    }
  }

  Future<void> _saveMetabolicState(String uid, BiometricSnapshot bio, MetabolicAdjustment adj) async {
    final docId = DateTime.now().toIso8601String().split('T')[0];
    
    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid).collection('metabolic_history').doc(docId), {
      'metrics': bio.toJson(),
      'adjustment': adj.toJson(),
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.update(_firestore.collection('users').doc(uid), {
      'currentMetabolicTarget': adj.calorieTarget,
      'lastSync': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}

// ============================================
// MODELS: UNICORN DATA ENTITIES
// ============================================

class BiometricSnapshot {
  final int steps;
  final double activeCals, basalCals, hrvRecovery;
  BiometricSnapshot({required this.steps, required this.activeCals, 
                    required this.basalCals, required this.hrvRecovery});

  Map<String, dynamic> toJson() => {'steps': steps, 'active_cals': activeCals, 'hrv': hrvRecovery};
}

class MetabolicAdjustment {
  final int calorieTarget;
  final double carbCeilingG;
  final String status, insight;

  MetabolicAdjustment({required this.calorieTarget, required this.carbCeilingG, 
                      required this.status, required this.insight});

  Map<String, dynamic> toJson() => {'calories': calorieTarget, 'carb_ceiling': carbCeilingG, 'status': status};
}
