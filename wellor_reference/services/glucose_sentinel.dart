// lib/services/glucose_sentinel.dart
// SENTINEL PATTERN: Event-driven glucose watchdog
// Zero AI cost when stable — only wakes Gemini on threshold breach.
//
// Architecture:
//   Firestore listener (glucose_readings)
//       ↓
//   Rule-based threshold check (pure Dart, zero API calls)
//       ↓  anomaly?
//   [YES] → GeminiAgentPipeline.invoke() → Safety Filter → GlucoCoach
//   [NO]  → update state, sleep (no cost)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'gemini_agent_pipeline.dart';
import 'medical_safety_filter.dart';
import 'agent_trace_logger.dart';
import 'gluco_coach_ai_service.dart';
import 'voice_alert_sentinel.dart';
import 'subscription_entitlement_resolver.dart';

// ═══════════════════════════════════════════════════════════════════
// SENTINEL STATE — Tracks per-user glucose trends
// ═══════════════════════════════════════════════════════════════════

class _UserGlucoseState {
  double lastGlucose;
  DateTime lastReadingTime;
  double velocityMgPerMin; // mg/dL per minute
  DateTime? lastAlertTime;
  String? lastAnomalyType;
  int consecutiveNormal; // count of normal readings in a row

  _UserGlucoseState({
    required this.lastGlucose,
    required this.lastReadingTime,
    this.velocityMgPerMin = 0.0,
    this.lastAlertTime,
    this.lastAnomalyType,
    this.consecutiveNormal = 0,
  });
}

// ═══════════════════════════════════════════════════════════════════
// ANOMALY RESULT — Output of the rule engine
// ═══════════════════════════════════════════════════════════════════

enum AnomalyLevel { none, watch, alert, critical }

class SentinelResult {
  final AnomalyLevel level;
  final String? anomalyType;
  final String reason;
  final bool shouldWakeAI;

  const SentinelResult({
    required this.level,
    this.anomalyType,
    required this.reason,
    required this.shouldWakeAI,
  });

  static const normal = SentinelResult(
    level: AnomalyLevel.none,
    reason: 'Glucose stable',
    shouldWakeAI: false,
  );
}

// ═══════════════════════════════════════════════════════════════════
// GLUCOSE SENTINEL — The watchdog
// ═══════════════════════════════════════════════════════════════════

class GlucoseSentinel {
  static final GlucoseSentinel _instance = GlucoseSentinel._internal();
  factory GlucoseSentinel() => _instance;
  GlucoseSentinel._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GeminiAgentPipeline _pipeline = GeminiAgentPipeline();
  final MedicalSafetyFilter _safetyFilter = MedicalSafetyFilter();
  final AgentTraceLogger _tracer = AgentTraceLogger();
  final GlucoCoachAIService _glucoCoach = GlucoCoachAIService();

  // Per-user state (keyed by userId)
  final Map<String, _UserGlucoseState> _userStates = {};

  // Active Firestore listeners
  final Map<String, StreamSubscription> _listeners = {};

  bool _isRunning = false;

  // ─────────────────────────────────────────────────────────────────
  // THRESHOLDS — Pure rule-based, no AI needed
  // ─────────────────────────────────────────────────────────────────

  static const double _hypoThreshold = 70.0;    // mg/dL
  static const double _hyperThreshold = 250.0;   // mg/dL
  static const double _highThreshold = 180.0;    // mg/dL
  static const double _risingFastVelocity = 2.0; // mg/dL per minute
  static const double _crashVelocity = -1.5;     // mg/dL per minute
  static const double _impendingSpikeVelocity = 1.2;
  static const Duration _alertCooldown = Duration(minutes: 30);
  static const Duration _criticalCooldown = Duration(minutes: 15);

  // ─────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────

  /// Start the sentinel — listens to opted-in users' glucose streams.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    debugPrint('🛡️ Sentinel: Starting event-driven glucose watch');

    // Listen for opted-in users and set up per-user glucose listeners
    _db
        .collection('glucoCoach_opted_in')
        .where('active', isEqualTo: true)
        .where('glucoseAlerts', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) => _syncUserListeners(snapshot),
      onError: (e) => debugPrint('🛡️ Sentinel: User sync error: $e'),
    );
  }

  /// Stop all listeners and clean up.
  void stop() {
    _isRunning = false;
    for (final sub in _listeners.values) {
      sub.cancel();
    }
    _listeners.clear();
    _userStates.clear();
    debugPrint('🛡️ Sentinel: Stopped');
  }

  /// Sync user listeners when the opted-in collection changes.
  void _syncUserListeners(QuerySnapshot snapshot) {
    final activeUserIds = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      if (userId == null) continue;

      activeUserIds.add(userId);

      // Only create listener if not already watching this user
      if (!_listeners.containsKey(userId)) {
        _startUserListener(userId, data);
      }
    }

    // Remove listeners for users who opted out
    final toRemove = _listeners.keys
        .where((uid) => !activeUserIds.contains(uid))
        .toList();
    for (final uid in toRemove) {
      _listeners[uid]?.cancel();
      _listeners.remove(uid);
      _userStates.remove(uid);
      debugPrint('🛡️ Sentinel: Removed watcher for $uid');
    }
  }

  /// Start listening to a single user's glucose readings.
  void _startUserListener(String userId, Map<String, dynamic> userData) {
    debugPrint('🛡️ Sentinel: Watching glucose for user $userId');

    final sub = _db
        .collection('users')
        .doc(userId)
        .collection('glucose_readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          _onNewGlucoseReading(userId, userData, snapshot.docs.first);
        }
      },
      onError: (e) {
        debugPrint('🛡️ Sentinel: Glucose listener error for $userId: $e');
      },
    );

    _listeners[userId] = sub;
  }

  // ─────────────────────────────────────────────────────────────────
  // EVENT HANDLER — Fires on each new glucose reading
  // ─────────────────────────────────────────────────────────────────

  Future<void> _onNewGlucoseReading(
    String userId,
    Map<String, dynamic> userData,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final glucose = (data['value'] ?? data['glucose_level'] ?? 0).toDouble();
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Ignore stale readings (older than 15 minutes)
    if (DateTime.now().difference(timestamp).inMinutes > 15) return;

    // Calculate velocity from previous state
    final prevState = _userStates[userId];
    double velocity = 0.0;
    if (prevState != null) {
      final timeDiffMin = timestamp.difference(prevState.lastReadingTime).inSeconds / 60.0;
      if (timeDiffMin > 0) {
        velocity = (glucose - prevState.lastGlucose) / timeDiffMin;
      }
    }

    // Update user state
    final currentState = _UserGlucoseState(
      lastGlucose: glucose,
      lastReadingTime: timestamp,
      velocityMgPerMin: velocity,
      lastAlertTime: prevState?.lastAlertTime,
      lastAnomalyType: prevState?.lastAnomalyType,
      consecutiveNormal: prevState?.consecutiveNormal ?? 0,
    );
    _userStates[userId] = currentState;

    // ── RULE ENGINE ── Pure Dart, zero API cost ──
    final result = _evaluateRules(glucose, velocity, currentState);

    if (!result.shouldWakeAI) {
      // Stable — increment normal counter, no cost
      currentState.consecutiveNormal++;
      return;
    }

    // Reset normal counter
    currentState.consecutiveNormal = 0;

    // Check cooldown
    if (!_isCooldownExpired(currentState, result.level)) {
      debugPrint('🛡️ Sentinel: Cooldown active for $userId, skipping');
      return;
    }

    // ── WAKE THE AI ── Only here do we spend API credits
    debugPrint('🛡️ Sentinel: ANOMALY for $userId → ${result.anomalyType} '
        '(glucose=${glucose.toStringAsFixed(0)}, velocity=${velocity.toStringAsFixed(2)})');

    await _invokeAgentPipeline(userId, userData, glucose, velocity, result);

    // Update alert time
    currentState.lastAlertTime = DateTime.now();
    currentState.lastAnomalyType = result.anomalyType;
  }

  // ─────────────────────────────────────────────────────────────────
  // RULE ENGINE — The core sentinel logic (zero AI cost)
  // ─────────────────────────────────────────────────────────────────

  SentinelResult _evaluateRules(
    double glucose,
    double velocity,
    _UserGlucoseState state,
  ) {
    // ── CRITICAL: Immediate threats ──
    if (glucose < _hypoThreshold) {
      return SentinelResult(
        level: AnomalyLevel.critical,
        anomalyType: 'HYPOGLYCEMIA',
        reason: 'Glucose ${glucose.toStringAsFixed(0)} mg/dL below ${_hypoThreshold.toStringAsFixed(0)}',
        shouldWakeAI: true,
      );
    }

    if (glucose > _hyperThreshold) {
      return SentinelResult(
        level: AnomalyLevel.critical,
        anomalyType: 'HYPERGLYCEMIA',
        reason: 'Glucose ${glucose.toStringAsFixed(0)} mg/dL above ${_hyperThreshold.toStringAsFixed(0)}',
        shouldWakeAI: true,
      );
    }

    // ── ALERT: Velocity-based threats ──
    if (velocity < _crashVelocity) {
      return SentinelResult(
        level: AnomalyLevel.alert,
        anomalyType: 'RAPID_DROP',
        reason: 'Falling at ${velocity.toStringAsFixed(2)} mg/dL/min',
        shouldWakeAI: true,
      );
    }

    if (velocity > _risingFastVelocity && glucose > 120) {
      return SentinelResult(
        level: AnomalyLevel.alert,
        anomalyType: 'ACTIVE_SPIKE',
        reason: 'Rising fast at ${velocity.toStringAsFixed(2)} mg/dL/min, already at ${glucose.toStringAsFixed(0)}',
        shouldWakeAI: true,
      );
    }

    // ── WATCH: Impending issues ──
    if (glucose > _highThreshold) {
      return SentinelResult(
        level: AnomalyLevel.watch,
        anomalyType: 'HIGH_GLUCOSE',
        reason: 'Above ${_highThreshold.toStringAsFixed(0)} mg/dL threshold',
        shouldWakeAI: true,
      );
    }

    if (velocity > _impendingSpikeVelocity && glucose > 100) {
      return SentinelResult(
        level: AnomalyLevel.watch,
        anomalyType: 'IMPENDING_SPIKE',
        reason: 'Rising at ${velocity.toStringAsFixed(2)} mg/dL/min from ${glucose.toStringAsFixed(0)}',
        shouldWakeAI: true,
      );
    }

    // ── NORMAL: No action needed ──
    return SentinelResult.normal;
  }

  /// Check if the cooldown period has expired for this alert level.
  bool _isCooldownExpired(_UserGlucoseState state, AnomalyLevel level) {
    if (state.lastAlertTime == null) return true;

    final cooldown = level == AnomalyLevel.critical
        ? _criticalCooldown
        : _alertCooldown;

    return DateTime.now().difference(state.lastAlertTime!) >= cooldown;
  }

  // ─────────────────────────────────────────────────────────────────
  // AI INVOCATION — Only called when rules detect anomaly
  // ─────────────────────────────────────────────────────────────────

  Future<void> _invokeAgentPipeline(
    String userId,
    Map<String, dynamic> userData,
    double glucose,
    double velocity,
    SentinelResult sentinel,
  ) async {
    final traceId = _tracer.startTrace(
      userId: userId,
      trigger: 'sentinel_${sentinel.anomalyType}',
    );

    try {
      // Build patient profile
      final name = userData['name'] as String? ?? 'Patient';
      final phoneNumber = userData['phoneNumber'] as String?;
      final conditions = List<String>.from(userData['diseases'] ?? userData['conditions'] ?? []);
      final goals = List<String>.from(userData['healthGoals'] ?? []);
      final glucotype = userData['glucotype'] as String?;

      final profile = StringBuffer('$name. ');
      if (glucotype != null) profile.write('Glucotype: $glucotype. ');
      if (conditions.isNotEmpty) profile.write('Conditions: ${conditions.join(", ")}. ');
      if (goals.isNotEmpty) profile.write('Goals: ${goals.join(", ")}.');

      // ── Trace: Sentinel node ──
      _tracer.logNode(
        traceId: traceId,
        node: 'sentinel',
        model: 'rule_engine',
        input: {'glucose': glucose, 'velocity': velocity},
        output: {
          'anomalyType': sentinel.anomalyType,
          'level': sentinel.level.name,
          'reason': sentinel.reason,
        },
        latencyMs: 0, // Rule engine is instant
      );

      final patientState = PatientState(
        patientId: userId,
        phoneNumber: phoneNumber,
        glucoseLevel: glucose,
        glucoseVelocity: velocity,
        patientProfile: profile.toString(),
      );

      // ── Run pipeline (Reasoning → Execution) ──
      final result = await _pipeline.invoke(patientState);

      // ── Trace: Pipeline result ──
      _tracer.logNode(
        traceId: traceId,
        node: 'pipeline',
        model: 'gemini-2.5-flash',
        input: patientState.toJson(),
        output: result.toJson(),
        latencyMs: DateTime.now().millisecondsSinceEpoch,
      );

      // ── Safety filter ── Check before sending to user
      if (result.interventionPlan != null && result.interventionPlan!.isNotEmpty) {
        final filtered = await _safetyFilter.filter(
          message: result.interventionPlan!,
          anomalyType: sentinel.anomalyType ?? 'UNKNOWN',
          glucoseLevel: glucose,
          patientConditions: conditions,
        );

        _tracer.logNode(
          traceId: traceId,
          node: 'safety_filter',
          model: 'rule_engine',
          input: {'original': result.interventionPlan},
          output: {
            'filtered': filtered.message,
            'wasModified': filtered.wasModified,
            'flags': filtered.flags,
          },
          latencyMs: 0,
        );

        if (filtered.blocked) {
          debugPrint('🛡️ Sentinel: Safety filter BLOCKED response for $userId');
          _tracer.endTrace(traceId: traceId, status: 'blocked_by_safety');

          // Log blocked interaction
          await _db.collection('agent_traces').doc(traceId).set(
            _tracer.getTrace(traceId),
            SetOptions(merge: true),
          );
          return;
        }

        // Send the safe message (Premium+ GlucoCoach entitlement)
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          final entitled = await SubscriptionEntitlementResolver.instance
              .hasGlucoCoach(userId);
          if (!entitled) {
            debugPrint('🩸 Sentinel: Skipping GlucoCoach — Premium+ required');
          } else {
            await _glucoCoach.sendProactiveMessage(
      userId: userId,
      message: filtered.message,
    );
          }
        }

        // Log to Firestore for chat UI
        await _db.collection('agent_interactions').add({
          'userId': userId,
          'type': 'sentinel_alert',
          'anomalyType': sentinel.anomalyType,
          'level': sentinel.level.name,
          'glucoseLevel': glucose,
          'velocity': velocity,
          'message': filtered.message,
          'wasFiltered': filtered.wasModified,
          'safetyFlags': filtered.flags,
          'traceId': traceId,
          'pipeline': 'sentinel_v2',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // ── Voice call escalation for CRITICAL anomalies ──
        if (sentinel.level == AnomalyLevel.critical) {
          final voiceResult = await VoiceAlertSentinel().evaluateGlucoseAnomaly(
            userId: userId,
            userData: userData,
            glucose: glucose,
            velocity: velocity,
            anomalyType: sentinel.anomalyType ?? 'UNKNOWN',
            anomalyLevel: sentinel.level.name,
            traceId: traceId,
          );
          if (voiceResult.called) {
            debugPrint('📞 Sentinel: Voice call initiated for $userId — ${voiceResult.callId}');
          }
        }
      }

      _tracer.endTrace(traceId: traceId, status: 'completed');

      // Persist trace
      await _db.collection('agent_traces').doc(traceId).set(
        _tracer.getTrace(traceId),
      );
    } catch (e) {
      debugPrint('🛡️ Sentinel: Pipeline error for $userId: $e');
      _tracer.endTrace(traceId: traceId, status: 'error', error: e.toString());

      await _db.collection('agent_traces').doc(traceId).set(
        _tracer.getTrace(traceId),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DIAGNOSTICS
  // ─────────────────────────────────────────────────────────────────

  /// Get current sentinel status for all watched users.
  Map<String, Map<String, dynamic>> getStatus() {
    return _userStates.map((userId, state) => MapEntry(userId, {
      'lastGlucose': state.lastGlucose,
      'velocity': state.velocityMgPerMin,
      'lastReading': state.lastReadingTime.toIso8601String(),
      'lastAlert': state.lastAlertTime?.toIso8601String(),
      'lastAnomalyType': state.lastAnomalyType,
      'consecutiveNormal': state.consecutiveNormal,
      'isListening': _listeners.containsKey(userId),
    }));
  }

  /// Number of users currently being watched.
  int get watchedUserCount => _listeners.length;

  /// Whether the sentinel is running.
  bool get isRunning => _isRunning;
}
