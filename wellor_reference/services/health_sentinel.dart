// lib/services/health_sentinel.dart
// UNIFIED SENTINEL PATTERN: Event-driven watchdog for ALL health domains.
// Zero AI cost when all metrics are stable — only wakes Gemini on threshold breach.
//
// Domains:
//   🩸 Glucose  → GlucoseSentinel (existing, manages its own Firestore listeners)
//   💧 Hydration → Firestore listener on water_logs, rule-based gap detection
//   🏃 Activity  → Firestore listener on daily_activity, step deficit rules
//   😴 Sleep     → Firestore listener on sleep_logs, quality/duration rules
//   🍽️ Meals     → Firestore listener on meal_logs, timing + glucose-aware rules
//   💓 Vitals    → Firestore listener on biometrics/current, HR/SpO2/BP rules

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'agent_trace_logger.dart';
import 'medical_safety_filter.dart';
import 'gluco_coach_ai_service.dart';
import 'multi_ai_service.dart';
import 'voice_alert_sentinel.dart';
import 'subscription_entitlement_resolver.dart';

// ═══════════════════════════════════════════════════════════════════
// HEALTH EVENT — Output from any sentinel rule
// ═══════════════════════════════════════════════════════════════════

enum HealthDomain { hydration, activity, sleep, meals, vitals }
enum AlertSeverity { info, nudge, warning, urgent }

class HealthEvent {
  final HealthDomain domain;
  final AlertSeverity severity;
  final String eventType;
  final String reason;
  final bool shouldWakeAI;
  final Map<String, dynamic> data;

  const HealthEvent({
    required this.domain,
    required this.severity,
    required this.eventType,
    required this.reason,
    required this.shouldWakeAI,
    this.data = const {},
  });
}

// ═══════════════════════════════════════════════════════════════════
// PER-USER STATE — Tracks all health domains
// ═══════════════════════════════════════════════════════════════════

class _UserHealthState {
  // Hydration
  int waterTodayMl;
  DateTime? lastWaterLogTime;
  int waterGoalMl;

  // Activity
  int stepsToday;
  DateTime? lastActivityTime;
  int stepGoal;

  // Sleep
  double? lastSleepHours;
  int? lastSleepQuality;
  DateTime? lastSleepLogTime;

  // Meals
  int mealsToday;
  DateTime? lastMealTime;

  // Vitals
  double? heartRate;
  double? bloodOxygen;
  double? bodyTemperature;
  double? bpSystolic;
  double? bpDiastolic;

  // Cooldowns (keyed by eventType)
  final Map<String, DateTime> lastAlerts;

  _UserHealthState({
    this.waterTodayMl = 0,
    this.lastWaterLogTime,
    this.waterGoalMl = 2450,
    this.stepsToday = 0,
    this.lastActivityTime,
    this.stepGoal = 10000,
    this.lastSleepHours,
    this.lastSleepQuality,
    this.lastSleepLogTime,
    this.mealsToday = 0,
    this.lastMealTime,
    this.heartRate,
    this.bloodOxygen,
    this.bodyTemperature,
    this.bpSystolic,
    this.bpDiastolic,
  }) : lastAlerts = {};

  bool isCooldownActive(String eventType, Duration cooldown) {
    final last = lastAlerts[eventType];
    if (last == null) return false;
    return DateTime.now().difference(last) < cooldown;
  }

  void markAlerted(String eventType) {
    lastAlerts[eventType] = DateTime.now();
  }
}

// ═══════════════════════════════════════════════════════════════════
// HEALTH SENTINEL — Unified watchdog for all domains
// ═══════════════════════════════════════════════════════════════════

class HealthSentinel {
  static final HealthSentinel _instance = HealthSentinel._internal();
  factory HealthSentinel() => _instance;
  HealthSentinel._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AgentTraceLogger _tracer = AgentTraceLogger();
  final MedicalSafetyFilter _safetyFilter = MedicalSafetyFilter();
  final GlucoCoachAIService _glucoCoach = GlucoCoachAIService();
  final MultiAIService _ai = MultiAIService();

  // Per-user state
  final Map<String, _UserHealthState> _userStates = {};

  // Active Firestore listeners (keyed by "userId_domain")
  final Map<String, StreamSubscription> _listeners = {};

  // Master user list listener
  StreamSubscription? _userListSub;

  bool _isRunning = false;

  // ─────────────────────────────────────────────────────────────────
  // THRESHOLDS & COOLDOWNS
  // ─────────────────────────────────────────────────────────────────

  // Hydration
  static const Duration _hydrationGapThreshold = Duration(hours: 3);
  static const Duration _hydrationCooldown = Duration(hours: 2);

  // Activity
  static const int _stepExpectedPerHour = 625; // 10K / 16 waking hours
  static const double _stepDeficitRatio = 0.5;  // alert when below 50% expected
  static const Duration _inactivityThreshold = Duration(hours: 2);
  static const Duration _activityCooldown = Duration(hours: 3);

  // Sleep
  static const double _minSleepHours = 6.0;
  static const int _lowSleepQuality = 50;
  static const Duration _sleepCooldown = Duration(hours: 12);

  // Meals
  static const Duration _mealGapThreshold = Duration(hours: 5);
  static const Duration _mealCooldown = Duration(hours: 4);

  // Vitals
  static const double _hrHigh = 120.0;
  static const double _hrLow = 50.0;
  static const double _spo2Low = 92.0;
  static const double _tempHigh = 38.0;
  static const double _bpSystolicHigh = 140.0;
  static const double _bpDiastolicHigh = 90.0;
  static const double _bpSystolicLow = 90.0;
  static const Duration _vitalsCooldown = Duration(minutes: 30);

  // ─────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────

  /// Start watching all opted-in users across all health domains.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    debugPrint('🛡️ HealthSentinel: Starting unified event-driven watch');

    _userListSub = _db
        .collection('glucoCoach_opted_in')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen(
      _syncAllUserListeners,
      onError: (e) => debugPrint('🛡️ HealthSentinel: User sync error: $e'),
    );
  }

  /// Stop all listeners.
  void stop() {
    _isRunning = false;
    _userListSub?.cancel();
    for (final sub in _listeners.values) {
      sub.cancel();
    }
    _listeners.clear();
    _userStates.clear();
    debugPrint('🛡️ HealthSentinel: Stopped');
  }

  /// Sync listeners when opted-in users change.
  void _syncAllUserListeners(QuerySnapshot snapshot) {
    final activeUserIds = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      if (userId == null) continue;

      activeUserIds.add(userId);

      // Initialize state if needed
      _userStates.putIfAbsent(userId, () {
        final weightKg = (data['weight'] as num?)?.toDouble() ?? 70.0;
        return _UserHealthState(waterGoalMl: (weightKg * 35).round());
      });

      // Set up domain listeners (only if not already watching)
      final prefs = data;
      _ensureListener(userId, prefs, 'hydration', prefs['hydrationReminders'] == true, _startHydrationListener);
      _ensureListener(userId, prefs, 'activity', prefs['exerciseReminders'] == true, _startActivityListener);
      _ensureListener(userId, prefs, 'sleep', prefs['sleepReminders'] == true, _startSleepListener);
      _ensureListener(userId, prefs, 'meals', true, _startMealListener);
      _ensureListener(userId, prefs, 'vitals', true, _startVitalsListener);
    }

    // Remove listeners for users who opted out
    final toRemove = _listeners.keys
        .where((key) => !activeUserIds.contains(key.split('_').first))
        .toList();
    for (final key in toRemove) {
      _listeners[key]?.cancel();
      _listeners.remove(key);
    }
    // Remove state for fully opted-out users
    _userStates.keys
        .where((uid) => !activeUserIds.contains(uid))
        .toList()
        .forEach(_userStates.remove);
  }

  void _ensureListener(
    String userId,
    Map<String, dynamic> prefs,
    String domain,
    bool enabled,
    void Function(String userId, Map<String, dynamic> prefs) startFn,
  ) {
    final key = '${userId}_$domain';
    if (enabled && !_listeners.containsKey(key)) {
      startFn(userId, prefs);
    } else if (!enabled && _listeners.containsKey(key)) {
      _listeners[key]?.cancel();
      _listeners.remove(key);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // HYDRATION SENTINEL
  // ─────────────────────────────────────────────────────────────────

  void _startHydrationListener(String userId, Map<String, dynamic> prefs) {
    final key = '${userId}_hydration';
    debugPrint('🛡️ HealthSentinel: Watching hydration for $userId');

    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final sub = _db
        .collection('users')
        .doc(userId)
        .collection('water_logs')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) => _onHydrationUpdate(userId, prefs, snapshot),
      onError: (e) => debugPrint('🛡️ Hydration listener error for $userId: $e'),
    );

    _listeners[key] = sub;
  }

  Future<void> _onHydrationUpdate(
    String userId,
    Map<String, dynamic> userData,
    QuerySnapshot snapshot,
  ) async {
    final state = _userStates[userId];
    if (state == null) return;

    final hour = DateTime.now().hour;
    // Only during waking hours (7am - 10pm)
    if (hour < 7 || hour >= 22) return;

    if (snapshot.docs.isNotEmpty) {
      final lastLog = snapshot.docs.first.data() as Map<String, dynamic>;
      final logTime = (lastLog['timestamp'] as Timestamp?)?.toDate();
      state.lastWaterLogTime = logTime;
    }

    // ── RULE: No water in 3+ hours ──
    final timeSinceWater = state.lastWaterLogTime != null
        ? DateTime.now().difference(state.lastWaterLogTime!)
        : null;

    if (timeSinceWater == null || timeSinceWater >= _hydrationGapThreshold) {
      if (state.isCooldownActive('hydration_gap', _hydrationCooldown)) return;

      final event = HealthEvent(
        domain: HealthDomain.hydration,
        severity: AlertSeverity.nudge,
        eventType: 'hydration_gap',
        reason: timeSinceWater != null
            ? 'No water logged in ${timeSinceWater.inHours}h ${timeSinceWater.inMinutes % 60}m'
            : 'No water logged today',
        shouldWakeAI: false, // Static message, no AI needed
        data: {'hoursSinceWater': timeSinceWater?.inHours},
      );

      await _handleEvent(userId, userData, event);
      state.markAlerted('hydration_gap');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // ACTIVITY SENTINEL
  // ─────────────────────────────────────────────────────────────────

  void _startActivityListener(String userId, Map<String, dynamic> prefs) {
    final key = '${userId}_activity';
    debugPrint('🛡️ HealthSentinel: Watching activity for $userId');

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final sub = _db
        .collection('users')
        .doc(userId)
        .collection('daily_activity')
        .doc(todayStr)
        .snapshots()
        .listen(
      (snapshot) => _onActivityUpdate(userId, prefs, snapshot),
      onError: (e) => debugPrint('🛡️ Activity listener error for $userId: $e'),
    );

    _listeners[key] = sub;
  }

  Future<void> _onActivityUpdate(
    String userId,
    Map<String, dynamic> userData,
    DocumentSnapshot snapshot,
  ) async {
    final state = _userStates[userId];
    if (state == null) return;

    final hour = DateTime.now().hour;
    // Only during active hours (8am - 8pm)
    if (hour < 8 || hour >= 20) return;

    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    state.stepsToday = (data['steps'] as int?) ?? 0;
    final lastUpdated = data['lastUpdated'] as Timestamp?;
    state.lastActivityTime = lastUpdated?.toDate();

    // ── RULE: Steps below 50% of expected AND inactive for 2+ hours ──
    final expectedSteps = (hour - 7) * _stepExpectedPerHour;
    if (state.stepsToday >= expectedSteps * _stepDeficitRatio) return; // On track

    final timeSinceActivity = state.lastActivityTime != null
        ? DateTime.now().difference(state.lastActivityTime!)
        : null;

    if (timeSinceActivity != null && timeSinceActivity < _inactivityThreshold) return; // Recently active

    if (state.isCooldownActive('activity_deficit', _activityCooldown)) return;

    final event = HealthEvent(
      domain: HealthDomain.activity,
      severity: AlertSeverity.nudge,
      eventType: 'activity_deficit',
      reason: '${state.stepsToday} steps vs ${expectedSteps} expected by ${hour}:00',
      shouldWakeAI: false, // Static message
      data: {
        'steps': state.stepsToday,
        'expected': expectedSteps,
        'hoursSinceActivity': timeSinceActivity?.inHours,
      },
    );

    await _handleEvent(userId, userData, event);
    state.markAlerted('activity_deficit');
  }

  // ─────────────────────────────────────────────────────────────────
  // SLEEP SENTINEL
  // ─────────────────────────────────────────────────────────────────

  void _startSleepListener(String userId, Map<String, dynamic> prefs) {
    final key = '${userId}_sleep';
    debugPrint('🛡️ HealthSentinel: Watching sleep for $userId');

    final sub = _db
        .collection('users')
        .doc(userId)
        .collection('sleep_logs')
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) => _onSleepUpdate(userId, prefs, snapshot),
      onError: (e) => debugPrint('🛡️ Sleep listener error for $userId: $e'),
    );

    _listeners[key] = sub;
  }

  Future<void> _onSleepUpdate(
    String userId,
    Map<String, dynamic> userData,
    QuerySnapshot snapshot,
  ) async {
    final state = _userStates[userId];
    if (state == null) return;

    if (snapshot.docs.isEmpty) return;

    final data = snapshot.docs.first.data() as Map<String, dynamic>;
    final hours = (data['total_hours'] ?? data['duration_hours'] ?? 0).toDouble();
    final quality = (data['quality'] ?? data['score'] ?? 100) as int;
    final logDate = data['date'] as String?;

    state.lastSleepHours = hours;
    state.lastSleepQuality = quality;
    state.lastSleepLogTime = DateTime.now();

    // Only fire for today's or last night's sleep log
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (logDate != todayStr && logDate != yesterdayStr) return;

    // ── RULE: Poor sleep → wake AI for personalized recovery advice ──
    if (hours >= _minSleepHours && quality >= _lowSleepQuality) return; // Sleep was fine

    if (state.isCooldownActive('poor_sleep', _sleepCooldown)) return;

    final issues = <String>[];
    if (hours < _minSleepHours) issues.add('${hours.toStringAsFixed(1)}h (need ${_minSleepHours}h+)');
    if (quality < _lowSleepQuality) issues.add('quality $quality/100');

    final event = HealthEvent(
      domain: HealthDomain.sleep,
      severity: AlertSeverity.warning,
      eventType: 'poor_sleep',
      reason: 'Poor sleep detected: ${issues.join(", ")}',
      shouldWakeAI: true, // AI gives personalized recovery plan
      data: {
        'hours': hours,
        'quality': quality,
      },
    );

    await _handleEvent(userId, userData, event);
    state.markAlerted('poor_sleep');
  }

  // ─────────────────────────────────────────────────────────────────
  // MEAL SENTINEL
  // ─────────────────────────────────────────────────────────────────

  void _startMealListener(String userId, Map<String, dynamic> prefs) {
    final key = '${userId}_meals';
    debugPrint('🛡️ HealthSentinel: Watching meals for $userId');

    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final sub = _db
        .collection('users')
        .doc(userId)
        .collection('meal_logs')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) => _onMealUpdate(userId, prefs, snapshot),
      onError: (e) => debugPrint('🛡️ Meal listener error for $userId: $e'),
    );

    _listeners[key] = sub;
  }

  Future<void> _onMealUpdate(
    String userId,
    Map<String, dynamic> userData,
    QuerySnapshot snapshot,
  ) async {
    final state = _userStates[userId];
    if (state == null) return;

    final hour = DateTime.now().hour;
    // Only during meal hours (7am - 9pm)
    if (hour < 7 || hour >= 21) return;

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      state.lastMealTime = (data['timestamp'] as Timestamp?)?.toDate();
      state.mealsToday++;
    }

    // ── RULE: No meal in 5+ hours during daytime ──
    final timeSinceMeal = state.lastMealTime != null
        ? DateTime.now().difference(state.lastMealTime!)
        : null;

    // Before 10am: skip if no breakfast yet (not everyone eats early)
    if (hour < 10 && timeSinceMeal == null) return;

    if (timeSinceMeal != null && timeSinceMeal < _mealGapThreshold) return; // Ate recently

    // After 11am with no meal logged at all today
    if (timeSinceMeal == null && hour < 11) return;

    if (state.isCooldownActive('meal_gap', _mealCooldown)) return;

    // Get current glucose for context-aware advice
    double? glucose;
    try {
      final glucoseSnap = await _db
          .collection('glucose_readings')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (glucoseSnap.docs.isNotEmpty) {
        glucose = (glucoseSnap.docs.first.data()['glucose_level'] as num?)?.toDouble();
      }
    } catch (_) {}

    final needsAI = glucose != null && (glucose < 80 || glucose > 150);

    final event = HealthEvent(
      domain: HealthDomain.meals,
      severity: glucose != null && glucose < 70 ? AlertSeverity.warning : AlertSeverity.nudge,
      eventType: 'meal_gap',
      reason: timeSinceMeal != null
          ? 'No meal in ${timeSinceMeal.inHours}h (glucose: ${glucose?.toStringAsFixed(0) ?? "?"})'
          : 'No meals logged today',
      shouldWakeAI: needsAI, // AI only if glucose is abnormal
      data: {
        'hoursSinceMeal': timeSinceMeal?.inHours,
        'glucose': glucose,
      },
    );

    await _handleEvent(userId, userData, event);
    state.markAlerted('meal_gap');
  }

  // ─────────────────────────────────────────────────────────────────
  // VITALS SENTINEL
  // ─────────────────────────────────────────────────────────────────

  void _startVitalsListener(String userId, Map<String, dynamic> prefs) {
    final key = '${userId}_vitals';
    debugPrint('🛡️ HealthSentinel: Watching vitals for $userId');

    final sub = _db
        .collection('users')
        .doc(userId)
        .collection('biometrics')
        .doc('current')
        .snapshots()
        .listen(
      (snapshot) => _onVitalsUpdate(userId, prefs, snapshot),
      onError: (e) => debugPrint('🛡️ Vitals listener error for $userId: $e'),
    );

    _listeners[key] = sub;
  }

  Future<void> _onVitalsUpdate(
    String userId,
    Map<String, dynamic> userData,
    DocumentSnapshot snapshot,
  ) async {
    final state = _userStates[userId];
    if (state == null) return;

    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    if (data.isEmpty) return;

    state.heartRate = (data['heartRate'] as num?)?.toDouble();
    state.bloodOxygen = (data['bloodOxygen'] as num?)?.toDouble();
    state.bodyTemperature = (data['bodyTemperature'] as num?)?.toDouble();
    state.bpSystolic = (data['bloodPressureSystolic'] as num?)?.toDouble();
    state.bpDiastolic = (data['bloodPressureDiastolic'] as num?)?.toDouble();

    // ── RULE: Check all vital thresholds ──
    final anomalies = <String>[];
    String? eventType;
    var severity = AlertSeverity.warning;

    if (state.heartRate != null && state.heartRate! > _hrHigh) {
      anomalies.add('Heart rate ${state.heartRate!.toStringAsFixed(0)} bpm (high)');
      eventType = 'hr_high';
    }
    if (state.heartRate != null && state.heartRate! < _hrLow) {
      anomalies.add('Heart rate ${state.heartRate!.toStringAsFixed(0)} bpm (low)');
      eventType = 'hr_low';
    }
    if (state.bloodOxygen != null && state.bloodOxygen! < _spo2Low) {
      anomalies.add('SpO2 ${state.bloodOxygen!.toStringAsFixed(0)}% (low)');
      eventType = 'spo2_low';
      severity = AlertSeverity.urgent;
    }
    if (state.bodyTemperature != null && state.bodyTemperature! > _tempHigh) {
      anomalies.add('Temperature ${state.bodyTemperature!.toStringAsFixed(1)}°C (elevated)');
      eventType = 'temp_high';
    }
    if (state.bpSystolic != null && state.bpSystolic! > _bpSystolicHigh) {
      anomalies.add('BP ${state.bpSystolic!.toStringAsFixed(0)}/${state.bpDiastolic?.toStringAsFixed(0) ?? "?"} (high)');
      eventType = 'bp_high';
    }
    if (state.bpSystolic != null && state.bpSystolic! < _bpSystolicLow) {
      anomalies.add('BP ${state.bpSystolic!.toStringAsFixed(0)}/${state.bpDiastolic?.toStringAsFixed(0) ?? "?"} (low)');
      eventType = 'bp_low';
      severity = AlertSeverity.urgent;
    }

    if (anomalies.isEmpty) return; // All vitals normal — zero cost

    if (state.isCooldownActive('vitals_${eventType}', _vitalsCooldown)) return;

    final event = HealthEvent(
      domain: HealthDomain.vitals,
      severity: severity,
      eventType: 'vitals_$eventType',
      reason: anomalies.join('; '),
      shouldWakeAI: true, // Always wake AI for vital anomalies
      data: {
        'heartRate': state.heartRate,
        'bloodOxygen': state.bloodOxygen,
        'bodyTemperature': state.bodyTemperature,
        'bpSystolic': state.bpSystolic,
        'bpDiastolic': state.bpDiastolic,
        'anomalies': anomalies,
      },
    );

    await _handleEvent(userId, userData, event);
    state.markAlerted('vitals_$eventType');
  }

  // ─────────────────────────────────────────────────────────────────
  // EVENT HANDLER — Routes to static message or AI pipeline
  // ─────────────────────────────────────────────────────────────────

  Future<void> _handleEvent(
    String userId,
    Map<String, dynamic> userData,
    HealthEvent event,
  ) async {
    final phoneNumber = userData['phoneNumber'] as String?;
    if (phoneNumber == null || phoneNumber.isEmpty) return;

    final traceId = _tracer.startTrace(
      userId: userId,
      trigger: 'sentinel_${event.domain.name}_${event.eventType}',
    );

    try {
      _tracer.logNode(
        traceId: traceId,
        node: '${event.domain.name}_sentinel',
        model: 'rule_engine',
        input: event.data,
        output: {
          'eventType': event.eventType,
          'severity': event.severity.name,
          'reason': event.reason,
          'shouldWakeAI': event.shouldWakeAI,
        },
        latencyMs: 0,
      );

      String message;

      if (event.shouldWakeAI) {
        // ── Wake Gemini for personalized response ──
        message = await _generateAIResponse(userId, userData, event, traceId);
      } else {
        // ── Use static template — zero AI cost ──
        message = _getStaticMessage(event);
      }

      // Safety filter
      final conditions = List<String>.from(userData['diseases'] ?? userData['conditions'] ?? []);
      final filtered = await _safetyFilter.filter(
        message: message,
        anomalyType: event.eventType,
        glucoseLevel: (event.data['glucose'] as double?) ?? 100.0,
        patientConditions: conditions,
      );

      _tracer.logNode(
        traceId: traceId,
        node: 'safety_filter',
        model: 'rule_engine',
        input: {'original_length': message.length},
        output: {'wasModified': filtered.wasModified, 'blocked': filtered.blocked, 'flags': filtered.flags},
        latencyMs: 0,
      );

      if (filtered.blocked) {
        debugPrint('🛡️ HealthSentinel: Safety filter BLOCKED ${event.eventType} for $userId');
        _tracer.endTrace(traceId: traceId, status: 'blocked_by_safety');
        await _persistTrace(traceId);
        return;
      }

      // Send via GlucoCoach (Premium+ entitlement)
      final entitled =
          await SubscriptionEntitlementResolver.instance.hasGlucoCoach(userId);
      if (!entitled) {
        debugPrint('💓 HealthSentinel: Skipping GlucoCoach — Premium+ required');
        _tracer.endTrace(traceId: traceId, status: 'skipped_not_entitled');
        await _persistTrace(traceId);
        return;
      }

      await _glucoCoach.sendProactiveMessage(
      userId: userId,
      message: filtered.message,
    );

      // Log for chat UI and analytics
      await _db.collection('agent_interactions').add({
        'userId': userId,
        'type': 'sentinel_${event.domain.name}',
        'eventType': event.eventType,
        'severity': event.severity.name,
        'reason': event.reason,
        'message': filtered.message,
        'wasFiltered': filtered.wasModified,
        'safetyFlags': filtered.flags,
        'usedAI': event.shouldWakeAI,
        'traceId': traceId,
        'pipeline': 'health_sentinel_v2',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // ── Voice call escalation for URGENT events ──
      if (event.severity == AlertSeverity.urgent) {
        final voiceResult = await VoiceAlertSentinel().evaluateHealthEvent(
          userId: userId,
          userData: userData,
          eventType: event.eventType,
          severity: event.severity.name,
          eventData: event.data,
          traceId: traceId,
        );
        if (voiceResult.called) {
          debugPrint('📞 HealthSentinel: Voice call initiated for $userId — ${voiceResult.callId}');
        }
      }

      _tracer.endTrace(traceId: traceId, status: 'completed');
      await _persistTrace(traceId);

      debugPrint('🛡️ HealthSentinel: ${event.domain.name}/${event.eventType} '
          '→ ${event.shouldWakeAI ? "AI" : "static"} message sent to $userId');
    } catch (e) {
      debugPrint('🛡️ HealthSentinel: Error handling ${event.eventType} for $userId: $e');
      _tracer.endTrace(traceId: traceId, status: 'error', error: e.toString());
      await _persistTrace(traceId);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // STATIC MESSAGES — Zero AI cost templates
  // ─────────────────────────────────────────────────────────────────

  String _getStaticMessage(HealthEvent event) {
    switch (event.domain) {
      case HealthDomain.hydration:
        final hours = event.data['hoursSinceWater'];
        return '💧 *Hydration Check!*\n\n'
            '${hours != null ? "It\'s been ${hours}h since your last water log." : "No water logged today."}\n\n'
            '• Staying hydrated helps energy and focus\n'
            '• Aim for 8 glasses throughout the day\n\n'
            'Grab a glass now and reply "drank water" to log it! 🥤';

      case HealthDomain.activity:
        final steps = event.data['steps'] ?? 0;
        return '🏃 *Activity Nudge!*\n\n'
            'You have $steps steps so far today. Let\'s get moving!\n\n'
            'Quick wins:\n'
            '• Take a 5-minute walk right now\n'
            '• Do 10 jumping jacks\n'
            '• Stretch at your desk\n\n'
            'Movement is medicine — even small amounts help! 💪';

      case HealthDomain.meals:
        final hours = event.data['hoursSinceMeal'];
        final glucose = event.data['glucose'];
        final glucoseNote = glucose != null ? ' (glucose: ${(glucose as double).toStringAsFixed(0)} mg/dL)' : '';
        return '🍽️ *Meal Reminder*\n\n'
            '${hours != null ? "It\'s been ${hours}h since your last meal$glucoseNote." : "No meals logged today."}\n\n'
            '• Regular meals help stabilize glucose\n'
            '• Vegetables first, then protein, carbs last\n'
            '• Stay hydrated with your meal\n\n'
            'What are you planning to eat? 🍎';

      case HealthDomain.sleep:
        // Sleep always wakes AI, but fallback just in case
        final hours = event.data['hours'];
        final quality = event.data['quality'];
        return '😴 *Sleep Check*\n\n'
            'Last night: ${hours != null ? "${(hours as double).toStringAsFixed(1)}h" : "?"} sleep'
            '${quality != null ? ", quality: $quality/100" : ""}.\n\n'
            '• Consider a short nap if possible\n'
            '• Extra hydration helps recovery\n'
            '• Go easier on exercise today\n\n'
            'Take care of yourself! 💚';

      case HealthDomain.vitals:
        // Vitals always wake AI, but fallback just in case
        final anomalies = event.data['anomalies'] as List?;
        return '💓 *Vitals Alert*\n\n'
            '${anomalies?.join("\n") ?? event.reason}\n\n'
            'Please monitor how you feel and contact your healthcare provider if symptoms persist.';
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // AI RESPONSE GENERATION — Only called when rules say "wake AI"
  // ─────────────────────────────────────────────────────────────────

  Future<String> _generateAIResponse(
    String userId,
    Map<String, dynamic> userData,
    HealthEvent event,
    String traceId,
  ) async {
    final name = userData['name'] as String? ?? 'there';
    final conditions = List<String>.from(userData['diseases'] ?? []);
    final goals = List<String>.from(userData['healthGoals'] ?? []);
    final glucotype = userData['glucotype'] as String?;

    String domainContext;
    String domainInstruction;

    switch (event.domain) {
      case HealthDomain.sleep:
        domainContext = 'Sleep data: ${event.data['hours']?.toStringAsFixed(1)}h, quality ${event.data['quality']}/100';
        domainInstruction = '''
Generate a recovery plan for poor sleep:
1. Acknowledge their sleep quality without being negative
2. Suggest ONE specific energy-boosting action for today
3. Recommend adjusted exercise intensity
4. Give ONE specific tip for tonight's sleep
5. If diabetic: mention insulin sensitivity may be affected''';

      case HealthDomain.vitals:
        domainContext = 'Vitals: ${(event.data['anomalies'] as List?)?.join(", ") ?? event.reason}';
        domainInstruction = '''
Generate a health alert for abnormal vitals:
1. State which vital is concerning and what the normal range is
2. Give ONE immediate action (sit down, drink water, rest, etc.)
3. Suggest when to recheck
4. Include when to seek medical help
5. Be calm and reassuring, not alarming''';

      case HealthDomain.meals:
        domainContext = 'Last meal: ${event.data['hoursSinceMeal'] ?? "?"}h ago, glucose: ${event.data['glucose']?.toStringAsFixed(0) ?? "?"}';
        domainInstruction = '''
Generate a meal suggestion based on current glucose:
1. If glucose < 80: suggest quick energy food with specific portions
2. If glucose > 150: suggest waiting or low-glycemic options
3. Give ONE specific meal idea suitable for the time of day
4. Remind about food order (vegetables → protein → carbs)''';

      default:
        domainContext = event.reason;
        domainInstruction = 'Generate a helpful, specific health message.';
    }

    final prompt = '''
You are a friendly health coach from Wellor messaging $name on GlucoCoach.

USER: $name
Conditions: ${conditions.join(', ').isEmpty ? 'None' : conditions.join(', ')}
Goals: ${goals.join(', ').isEmpty ? 'General health' : goals.join(', ')}
${glucotype != null ? 'Glucotype: $glucotype' : ''}

SITUATION: ${event.reason}
$domainContext

$domainInstruction

RULES:
- 4-5 short lines max
- Be specific (exact portions, exact exercises, exact times)
- Use 1-2 emojis
- Sound like a supportive coach, not a doctor
- Under 100 words

Respond as plain GlucoCoach message text only.''';

    try {
      final aiStart = DateTime.now();
      final response = await _ai.chatCompletionText(
        prompt: prompt,
        temperature: 0.6,
        maxTokens: 250,
      );

      _tracer.logNode(
        traceId: traceId,
        node: '${event.domain.name}_ai',
        model: 'gemini-2.5-flash',
        input: {'prompt_length': prompt.length, 'event': event.eventType},
        output: {'response_length': response.length},
        latencyMs: DateTime.now().difference(aiStart).inMilliseconds,
      );

      // Add domain header
      final header = _getDomainHeader(event);
      return '$header\n\n$response';
    } catch (e) {
      debugPrint('🛡️ HealthSentinel: AI error for ${event.domain.name}: $e');
      // Fallback to static message
      return _getStaticMessage(event);
    }
  }

  String _getDomainHeader(HealthEvent event) {
    switch (event.domain) {
      case HealthDomain.sleep:
        return '😴 *Sleep Recovery Plan*';
      case HealthDomain.vitals:
        switch (event.eventType) {
          case 'vitals_hr_high':
          case 'vitals_hr_low':
            return '💓 *Heart Rate Alert*';
          case 'vitals_spo2_low':
            return '🫁 *Blood Oxygen Alert*';
          case 'vitals_bp_high':
          case 'vitals_bp_low':
            return '🩸 *Blood Pressure Alert*';
          case 'vitals_temp_high':
            return '🌡️ *Temperature Alert*';
          default:
            return '💓 *Vitals Alert*';
        }
      case HealthDomain.meals:
        return '🍽️ *Meal Suggestion*';
      case HealthDomain.hydration:
        return '💧 *Hydration Check*';
      case HealthDomain.activity:
        return '🏃 *Activity Nudge*';
    }
  }

  Future<void> _persistTrace(String traceId) async {
    try {
      await _db.collection('agent_traces').doc(traceId).set(
        _tracer.getTrace(traceId),
      );
    } catch (e) {
      debugPrint('🛡️ HealthSentinel: Trace persist error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DIAGNOSTICS
  // ─────────────────────────────────────────────────────────────────

  /// Get current status for all watched users and domains.
  Map<String, Map<String, dynamic>> getStatus() {
    return _userStates.map((userId, state) => MapEntry(userId, {
      'hydration': {
        'waterTodayMl': state.waterTodayMl,
        'lastWater': state.lastWaterLogTime?.toIso8601String(),
        'goalMl': state.waterGoalMl,
      },
      'activity': {
        'stepsToday': state.stepsToday,
        'lastActivity': state.lastActivityTime?.toIso8601String(),
        'stepGoal': state.stepGoal,
      },
      'sleep': {
        'lastHours': state.lastSleepHours,
        'lastQuality': state.lastSleepQuality,
      },
      'meals': {
        'mealsToday': state.mealsToday,
        'lastMeal': state.lastMealTime?.toIso8601String(),
      },
      'vitals': {
        'heartRate': state.heartRate,
        'bloodOxygen': state.bloodOxygen,
        'bodyTemperature': state.bodyTemperature,
        'bpSystolic': state.bpSystolic,
      },
      'activeListeners': _listeners.keys
          .where((k) => k.startsWith('${userId}_'))
          .map((k) => k.split('_').last)
          .toList(),
      'alertCooldowns': state.lastAlerts.map(
        (k, v) => MapEntry(k, v.toIso8601String()),
      ),
    }));
  }

  int get watchedUserCount => _userStates.length;
  int get activeListenerCount => _listeners.length;
  bool get isRunning => _isRunning;
}
