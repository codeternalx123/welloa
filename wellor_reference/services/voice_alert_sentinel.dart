// lib/services/voice_alert_sentinel.dart
// VOICE ALERT SENTINEL: Critical-event voice call escalation engine
//
// Decides when a health event is severe enough to warrant an
// outbound Twilio voice call. Runs AFTER GlucoCoach text alert.
//
// Trigger conditions:
//   - GlucoseSentinel: AnomalyLevel.critical (HYPO <70, HYPER >250)
//   - HealthSentinel:  AlertSeverity.urgent  (vitals crisis)
//   - Combined signals (glucose critical + sick flag → highest priority)
//
// Safety controls:
//   - Per-user cooldown: 30 min between voice calls
//   - Max 3 calls per user per day
//   - Quiet hours bypass: critical always calls (life-threatening)
//   - Voice backend failure → log to Firestore for manual follow-up

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'twilio_voice_service.dart';
import 'subscription_entitlement_resolver.dart';

// ═══════════════════════════════════════════════════════════════════
// VOICE ESCALATION RESULT
// ═══════════════════════════════════════════════════════════════════

class VoiceEscalationResult {
  final bool called;
  final String? callId;
  final String? skipReason;

  VoiceEscalationResult.initiated(this.callId)
      : called = true,
        skipReason = null;

  VoiceEscalationResult.skipped(this.skipReason)
      : called = false,
        callId = null;
}

// ═══════════════════════════════════════════════════════════════════
// VOICE ALERT SENTINEL — Singleton
// ═══════════════════════════════════════════════════════════════════

class VoiceAlertSentinel {
  static final VoiceAlertSentinel _instance = VoiceAlertSentinel._internal();
  factory VoiceAlertSentinel() => _instance;
  VoiceAlertSentinel._internal();

  final TwilioVoiceService _voice = TwilioVoiceService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Per-user cooldown tracking (userId → last call timestamp)
  final Map<String, DateTime> _lastCallTime = {};
  // Per-user daily call count (userId → {date: count})
  final Map<String, Map<String, int>> _dailyCounts = {};

  // Cooldown between voice calls per user
  static const Duration _callCooldown = Duration(minutes: 30);
  // Max calls per user per day
  static const int _maxCallsPerDay = 3;

  // ═══════════════════════════════════════════════════════════════════
  // GLUCOSE ESCALATION — Called from GlucoseSentinel._invokeAgentPipeline
  // ═══════════════════════════════════════════════════════════════════

  /// Evaluate a glucose anomaly for voice call escalation.
  /// Only critical-level anomalies (HYPO <70, HYPER >250) trigger calls.
  Future<VoiceEscalationResult> evaluateGlucoseAnomaly({
    required String userId,
    required Map<String, dynamic> userData,
    required double glucose,
    required double velocity,
    required String anomalyType,
    required String anomalyLevel, // 'critical', 'alert', etc.
    String? traceId,
    List<String> actionItems = const [],
  }) async {
    // Only escalate critical anomalies to voice
    if (anomalyLevel != 'critical') {
      return VoiceEscalationResult.skipped('not_critical');
    }

    return _executeEscalation(
      userId: userId,
      userData: userData,
      anomalyType: anomalyType,
      severity: 'critical',
      glucoseLevel: glucose,
      glucoseVelocity: velocity,
      traceId: traceId,
      actionItems: actionItems,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEALTH ESCALATION — Called from HealthSentinel._handleEvent
  // ═══════════════════════════════════════════════════════════════════

  /// Evaluate a health event for voice call escalation.
  /// Only urgent-level events (vitals crisis) trigger calls.
  Future<VoiceEscalationResult> evaluateHealthEvent({
    required String userId,
    required Map<String, dynamic> userData,
    required String eventType,
    required String severity, // 'urgent', 'warning', etc.
    required Map<String, dynamic> eventData,
    String? traceId,
    List<String> actionItems = const [],
  }) async {
    // Only escalate urgent events to voice
    if (severity != 'urgent') {
      return VoiceEscalationResult.skipped('not_urgent');
    }

    // Extract vitals from event data for call context
    final extraContext = <String, dynamic>{};
    if (eventData.containsKey('heartRate')) extraContext['heartRate'] = eventData['heartRate'];
    if (eventData.containsKey('bloodOxygen')) extraContext['bloodOxygen'] = eventData['bloodOxygen'];
    if (eventData.containsKey('bodyTemperature')) extraContext['bodyTemperature'] = eventData['bodyTemperature'];
    if (eventData.containsKey('bpSystolic') && eventData.containsKey('bpDiastolic')) {
      extraContext['bloodPressure'] = '${eventData['bpSystolic']}/${eventData['bpDiastolic']}';
    }

    return _executeEscalation(
      userId: userId,
      userData: userData,
      anomalyType: eventType,
      severity: 'urgent',
      glucoseLevel: (eventData['glucose'] as double?),
      traceId: traceId,
      actionItems: actionItems,
      extraContext: extraContext,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CORE ESCALATION ENGINE
  // ═══════════════════════════════════════════════════════════════════

  Future<VoiceEscalationResult> _executeEscalation({
    required String userId,
    required Map<String, dynamic> userData,
    required String anomalyType,
    required String severity,
    double? glucoseLevel,
    double? glucoseVelocity,
    String? traceId,
    List<String> actionItems = const [],
    Map<String, dynamic> extraContext = const {},
  }) async {
    // ── Check: voice backend configured ──
    if (!_voice.isConfigured) {
      debugPrint('📞 VoiceAlert: Voice backend not configured — skipping voice call');
      return VoiceEscalationResult.skipped('voice_backend_not_configured');
    }

    // ── Ultra: voice escalation is a paid entitlement ([SubscriptionProvider.hasVoiceEscalation]) ──
    if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(userId)) {
      debugPrint('📞 VoiceAlert: Skipping — active Ultra subscription required');
      return VoiceEscalationResult.skipped('subscription_not_ultra');
    }

    // ── Check: User has phone number ──
    final phoneNumber = userData['phoneNumber'] as String?;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return VoiceEscalationResult.skipped('no_phone_number');
    }

    // ── Check: Per-user cooldown ──
    final lastCall = _lastCallTime[userId];
    if (lastCall != null && DateTime.now().difference(lastCall) < _callCooldown) {
      final remaining = _callCooldown - DateTime.now().difference(lastCall);
      debugPrint('📞 VoiceAlert: Cooldown active for $userId — ${remaining.inMinutes}min remaining');
      return VoiceEscalationResult.skipped('cooldown_active');
    }

    // ── Check: Daily call limit ──
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayCount = (_dailyCounts[userId]?[today]) ?? 0;
    if (todayCount >= _maxCallsPerDay) {
      debugPrint('📞 VoiceAlert: Daily limit reached for $userId ($todayCount/$_maxCallsPerDay)');
      return VoiceEscalationResult.skipped('daily_limit_reached');
    }

    // ── Check: User opted in to voice calls ──
    final voiceEnabled = userData['voiceCallsEnabled'] as bool? ?? true;
    if (!voiceEnabled) {
      return VoiceEscalationResult.skipped('user_opted_out');
    }

    // ── Build voice call request ──
    final name = userData['name'] as String? ?? 'there';
    final conditions = List<String>.from(
        userData['diseases'] ?? userData['conditions'] ?? []);

    final request = VoiceCallRequest(
      userId: userId,
      toNumber: phoneNumber,
      patientName: name,
      anomalyType: anomalyType,
      severity: severity,
      glucoseLevel: glucoseLevel,
      glucoseVelocity: glucoseVelocity,
      conditions: conditions,
      actionItems: actionItems,
      traceId: traceId,
      extraContext: extraContext,
    );

    // ── Execute call ──
    debugPrint('📞 VoiceAlert: ESCALATING to voice call — '
        '$anomalyType ($severity) for $userId');

    final result = await _voice.createCall(request);

    if (result.success) {
      // Update cooldown
      _lastCallTime[userId] = DateTime.now();

      // Update daily count
      _dailyCounts.putIfAbsent(userId, () => {});
      _dailyCounts[userId]![today] = todayCount + 1;

      debugPrint('📞 VoiceAlert: Call initiated — callId=${result.callId}');
      return VoiceEscalationResult.initiated(result.callId);
    } else {
      debugPrint('📞 VoiceAlert: Call failed — ${result.error}');

      // Log failed escalation for manual follow-up
      await _logFailedEscalation(userId, anomalyType, severity, result.error);

      return VoiceEscalationResult.skipped('call_failed: ${result.error}');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // FAILED ESCALATION LOGGING
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _logFailedEscalation(
    String userId,
    String anomalyType,
    String severity,
    String? error,
  ) async {
    try {
      await _db.collection('failed_voice_escalations').add({
        'userId': userId,
        'anomalyType': anomalyType,
        'severity': severity,
        'error': error,
        'requiresManualFollowUp': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('📞 VoiceAlert: Error logging failed escalation: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIAGNOSTICS
  // ═══════════════════════════════════════════════════════════════════

  /// Get voice alert status for monitoring.
  Map<String, dynamic> getStatus() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return {
      'voiceBackendConfigured': _voice.isConfigured,
      'trackedUsers': _lastCallTime.length,
      'cooldowns': _lastCallTime.map((userId, time) => MapEntry(userId, {
        'lastCall': time.toIso8601String(),
        'cooldownActive': DateTime.now().difference(time) < _callCooldown,
        'cooldownRemaining': DateTime.now().difference(time) < _callCooldown
            ? (_callCooldown - DateTime.now().difference(time)).inMinutes
            : 0,
      })),
      'dailyCounts': _dailyCounts.map((userId, counts) => MapEntry(userId, {
        'today': counts[today] ?? 0,
        'max': _maxCallsPerDay,
      })),
    };
  }
}
