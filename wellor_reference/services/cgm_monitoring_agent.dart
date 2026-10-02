// lib/services/cgm_monitoring_agent.dart
// MEDICAL-GRADE: Continuous Glucose Monitoring Agent
// Continuously monitors CGM data, calculates dG/dt, and detects trends.
// Part of the Predictive Metabolic Twin system.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/glucose_context.dart';
import '../models/safety_state.dart';
import 'deterministic_safety_engine.dart';
import 'glucose_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// CGM MONITORING AGENT
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Core Responsibilities:**
/// 1. Continuously ingest CGM readings (every 5 minutes)
/// 2. Calculate velocity (dG/dt) and acceleration (d²G/dt²)
/// 3. Predict future glucose values (20min, 45min, 90min)
/// 4. Evaluate safety state using deterministic logic
/// 5. Trigger interventions when thresholds are breached
/// 
/// **Data Sources:**
/// - CGM devices (FreeStyle Libre)
/// - Manual glucose entries
/// - Health Connect / Apple Health
/// 
/// **Monitoring Loop:**
/// - Check every 5 minutes for new readings
/// - Maintain 60-minute rolling history
/// - Local-first with cloud backup
/// ═══════════════════════════════════════════════════════════════════

class CGMMonitoringAgent {
  static final CGMMonitoringAgent _instance = CGMMonitoringAgent._internal();
  factory CGMMonitoringAgent() => _instance;
  CGMMonitoringAgent._internal();
  
  final GlucoseService _glucoseService = GlucoseService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  
  /// Current glucose context (latest state)
  GlucoseContext? _currentContext;
  GlucoseContext? get currentContext => _currentContext;
  
  /// Safety evaluation callbacks
  final List<void Function(SafetyEvaluation)> _safetyCallbacks = [];
  
  /// Context update callbacks
  final List<void Function(GlucoseContext)> _contextCallbacks = [];
  
  // ═══════════════════════════════════════════════════════════════════
  // MONITORING LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════
  
  /// Start continuous monitoring
  Future<void> startMonitoring({
    required String userId,
    Duration interval = const Duration(minutes: 5),
  }) async {
    if (_isMonitoring) {
      debugPrint('🩺 CGM Agent: Already monitoring');
      return;
    }
    
    _isMonitoring = true;
    debugPrint('🩺 CGM Agent: Starting continuous monitoring (${interval.inMinutes}min intervals)');
    
    // Immediate check
    await _performMonitoringCycle(userId);
    
    // Schedule recurring checks
    _monitoringTimer = Timer.periodic(interval, (_) async {
      await _performMonitoringCycle(userId);
    });
  }
  
  /// Stop continuous monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    debugPrint('🩺 CGM Agent: Stopped monitoring');
  }
  
  /// Is agent currently monitoring?
  bool get isMonitoring => _isMonitoring;
  
  // ═══════════════════════════════════════════════════════════════════
  // MONITORING CYCLE
  // ═══════════════════════════════════════════════════════════════════
  
  /// Execute one monitoring cycle
  Future<void> _performMonitoringCycle(String userId) async {
    try {
      debugPrint('🩺 CGM Agent: Starting monitoring cycle');
      
      // 1. Fetch latest glucose reading
      final latestReading = await _fetchLatestReading(userId);
      if (latestReading == null) {
        debugPrint('🩺 CGM Agent: No glucose data available');
        return;
      }
      
      // 2. Fetch recent history (last 60 minutes)
      final history = await _fetchRecentHistory(userId, Duration(minutes: 60));
      
      // 3. Fetch contextual data
      final minutesSinceLastMeal = await _getMinutesSinceLastMeal(userId);
      final minutesSinceLastExercise = await _getMinutesSinceLastExercise(userId);
      final activeInsulin = await _getActiveInsulin(userId);
      
      // 4. Build glucose context
      final context = GlucoseContext.fromReadings(
        current: latestReading,
        history: history,
        minutesSinceLastMeal: minutesSinceLastMeal,
        minutesSinceLastExercise: minutesSinceLastExercise,
        activeInsulin: activeInsulin,
      );
      
      _currentContext = context;
      
      debugPrint('🩺 CGM Agent: Context built - ${context.currentValue.toStringAsFixed(0)} mg/dL ${context.arrow} '
          '(${context.velocity.toStringAsFixed(1)} mg/dL/min)');
      
      // 5. Evaluate safety state (deterministic)
      final evaluation = DeterministicSafetyEngine.evaluateSafety(context);
      
      debugPrint('🩺 CGM Agent: Safety state = ${evaluation.state.label} '
          '(confidence: ${(evaluation.confidence * 100).toStringAsFixed(0)}%)');
      
      // 6. Store reading locally and in cloud
      await _storeReading(userId, latestReading, context, evaluation);
      
      // 7. Notify listeners
      _notifyContextListeners(context);
      _notifySafetyListeners(evaluation);
      
      // 8. Log for audit trail
      await _logMonitoringEvent(userId, context, evaluation);
      
    } catch (e) {
      debugPrint('❌ CGM Agent: Monitoring cycle error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // DATA FETCHING
  // ═══════════════════════════════════════════════════════════════════
  
  /// Fetch latest glucose reading
  Future<GlucoseReading?> _fetchLatestReading(String userId) async {
    try {
      // Try local cache first (Hive)
      final box = await Hive.openBox('glucose_readings');
      final cached = box.get('latest_reading_$userId');
      if (cached != null) {
        final reading = GlucoseReading.fromJson(Map<String, dynamic>.from(cached as Map));
        
        // Only use if recent (< 15 minutes old)
        if (DateTime.now().difference(reading.timestamp).inMinutes < 15) {
          return reading;
        }
      }
      
      // Fetch from Firestore
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('glucose_readings')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final data = snapshot.docs.first.data();
      return GlucoseReading(
        value: (data['value'] as num).toDouble(),
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        source: data['source'] as String? ?? 'manual',
      );
    } catch (e) {
      debugPrint('❌ CGM Agent: Error fetching latest reading: $e');
      return null;
    }
  }
  
  /// Fetch recent history
  Future<List<GlucoseReading>> _fetchRecentHistory(String userId, Duration duration) async {
    try {
      final since = DateTime.now().subtract(duration);
      
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('glucose_readings')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: false)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GlucoseReading(
          value: (data['value'] as num).toDouble(),
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          source: data['source'] as String? ?? 'manual',
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ CGM Agent: Error fetching history: $e');
      return [];
    }
  }
  
  /// Get minutes since last meal
  Future<int?> _getMinutesSinceLastMeal(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('meals')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final timestamp = (snapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
      return DateTime.now().difference(timestamp).inMinutes;
    } catch (e) {
      return null;
    }
  }
  
  /// Get minutes since last exercise
  Future<int?> _getMinutesSinceLastExercise(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final timestamp = (snapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
      return DateTime.now().difference(timestamp).inMinutes;
    } catch (e) {
      return null;
    }
  }
  
  /// Get active insulin on board (if user tracks insulin)
  Future<double?> _getActiveInsulin(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('insulin_doses')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 6))))
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      // Simple IOB calculation (would be more sophisticated in production)
      double iob = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dose = (data['units'] as num).toDouble();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final hoursAgo = DateTime.now().difference(timestamp).inHours;
        
        // Simple decay model (4-hour insulin action)
        if (hoursAgo < 4) {
          iob += dose * (1 - hoursAgo / 4);
        }
      }
      
      return iob;
    } catch (e) {
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // DATA STORAGE
  // ═══════════════════════════════════════════════════════════════════
  
  /// Store reading locally and in cloud
  Future<void> _storeReading(
    String userId,
    GlucoseReading reading,
    GlucoseContext context,
    SafetyEvaluation evaluation,
  ) async {
    try {
      // Store in Hive (local cache)
      final box = await Hive.openBox('glucose_readings');
      await box.put('latest_reading_$userId', reading.toJson());
      await box.put('latest_context_$userId', context.toJson());
      
      // Store in Firestore (cloud backup)
      await _db
          .collection('users')
          .doc(userId)
          .collection('glucose_contexts')
          .add({
            'reading': reading.toJson(),
            'context': context.toJson(),
            'evaluation': evaluation.toJson(),
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('❌ CGM Agent: Error storing reading: $e');
    }
  }
  
  /// Log monitoring event for audit trail
  Future<void> _logMonitoringEvent(
    String userId,
    GlucoseContext context,
    SafetyEvaluation evaluation,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('monitoring_events')
          .add({
            'type': 'cgm_check',
            'glucose': context.currentValue,
            'velocity': context.velocity,
            'safetyState': evaluation.state.name,
            'confidence': evaluation.confidence,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('❌ CGM Agent: Error logging event: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // CALLBACKS & LISTENERS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Register callback for safety evaluations
  void onSafetyEvaluation(void Function(SafetyEvaluation) callback) {
    _safetyCallbacks.add(callback);
  }
  
  /// Register callback for context updates
  void onContextUpdate(void Function(GlucoseContext) callback) {
    _contextCallbacks.add(callback);
  }
  
  /// Notify safety listeners
  void _notifySafetyListeners(SafetyEvaluation evaluation) {
    for (final callback in _safetyCallbacks) {
      try {
        callback(evaluation);
      } catch (e) {
        debugPrint('❌ CGM Agent: Error in safety callback: $e');
      }
    }
  }
  
  /// Notify context listeners
  void _notifyContextListeners(GlucoseContext context) {
    for (final callback in _contextCallbacks) {
      try {
        callback(context);
      } catch (e) {
        debugPrint('❌ CGM Agent: Error in context callback: $e');
      }
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MANUAL OPERATIONS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Manually add a glucose reading (user input)
  Future<void> addManualReading({
    required String userId,
    required double glucose,
  }) async {
    try {
      // Validate reading
      if (!DeterministicSafetyEngine.isValidReading(glucose)) {
        throw Exception('Invalid glucose reading: $glucose mg/dL');
      }
      
      final reading = GlucoseReading(
        value: glucose,
        timestamp: DateTime.now(),
        source: 'manual',
      );
      
      // Store in Firestore
      await _db
          .collection('users')
          .doc(userId)
          .collection('glucose_readings')
          .add(reading.toJson());
      
      debugPrint('🩺 CGM Agent: Manual reading added: ${glucose.toStringAsFixed(0)} mg/dL');
      
      // Trigger immediate monitoring cycle
      await _performMonitoringCycle(userId);
    } catch (e) {
      debugPrint('❌ CGM Agent: Error adding manual reading: $e');
      rethrow;
    }
  }
  
  /// Get current safety state
  SafetyState? getCurrentSafetyState() {
    if (_currentContext == null) return null;
    final evaluation = DeterministicSafetyEngine.evaluateSafety(_currentContext!);
    return evaluation.state;
  }
  
  /// Get glucose statistics
  Future<GlucoseStatistics> getStatistics(String userId, {Duration period = const Duration(days: 7)}) async {
    try {
      final since = DateTime.now().subtract(period);
      
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('glucose_readings')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();
      
      if (snapshot.docs.isEmpty) {
        return GlucoseStatistics.empty();
      }
      
      final readings = snapshot.docs.map((doc) {
        return (doc.data()['value'] as num).toDouble();
      }).toList();
      
      return GlucoseStatistics.fromReadings(readings);
    } catch (e) {
      debugPrint('❌ CGM Agent: Error getting statistics: $e');
      return GlucoseStatistics.empty();
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// GLUCOSE STATISTICS
/// ═══════════════════════════════════════════════════════════════════

class GlucoseStatistics {
  final double mean;
  final double median;
  final double min;
  final double max;
  final double timeInRange;      // % 70-180 mg/dL
  final double timeBelowRange;   // % <70 mg/dL
  final double timeAboveRange;   // % >180 mg/dL
  final double coefficientOfVariation;
  final int totalReadings;
  
  const GlucoseStatistics({
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.timeInRange,
    required this.timeBelowRange,
    required this.timeAboveRange,
    required this.coefficientOfVariation,
    required this.totalReadings,
  });
  
  factory GlucoseStatistics.empty() => const GlucoseStatistics(
    mean: 0,
    median: 0,
    min: 0,
    max: 0,
    timeInRange: 0,
    timeBelowRange: 0,
    timeAboveRange: 0,
    coefficientOfVariation: 0,
    totalReadings: 0,
  );
  
  factory GlucoseStatistics.fromReadings(List<double> readings) {
    if (readings.isEmpty) return GlucoseStatistics.empty();
    
    final sorted = List<double>.from(readings)..sort();
    final sum = readings.reduce((a, b) => a + b);
    final mean = sum / readings.length;
    final median = sorted[sorted.length ~/ 2];
    
    // Time in range calculations
    final inRange = readings.where((g) => g >= 70 && g <= 180).length;
    final below = readings.where((g) => g < 70).length;
    final above = readings.where((g) => g > 180).length;
    
    // Coefficient of variation
    final variance = readings.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / readings.length;
    final stdDev = variance > 0 ? variance : 0.0;
    final cv = mean > 0 ? (stdDev / mean) * 100 : 0.0;
    
    return GlucoseStatistics(
      mean: mean,
      median: median,
      min: sorted.first,
      max: sorted.last,
      timeInRange: (inRange / readings.length) * 100,
      timeBelowRange: (below / readings.length) * 100,
      timeAboveRange: (above / readings.length) * 100,
      coefficientOfVariation: cv,
      totalReadings: readings.length,
    );
  }
}
