// lib/services/adaptive_engagement_agent.dart
// MEDICAL-GRADE: Adaptive Engagement Agent
// Prevents notification fatigue while maintaining safety
// Part of the Predictive Metabolic Twin system

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/safety_state.dart';
import 'intervention_escalation_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// ADAPTIVE ENGAGEMENT AGENT
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Problem**: Notification Fatigue Paradox
/// - Too many alerts → user ignores them (alarm blindness)
/// - Too few alerts → user misses critical events
/// 
/// **Solution**: Adaptive Intervention Strategy
/// - Critical states ALWAYS intervene (medical safety override)
/// - Non-critical states adaptively filtered based on:
///   1. User engagement score (dismissal rate, response time)
///   2. Recent intervention frequency
///   3. Preferred communication tone
///   4. Time of day & context
/// 
/// **Key Innovations:**
/// - Machine learning of user preferences
/// - Tone variation (clinical, casual, motivational, humorous)
/// - Channel rotation (GlucoCoach, in-app, SMS)
/// - Timing intelligence (respect sleep, meetings)
/// - Gamification rewards for compliance
/// ═══════════════════════════════════════════════════════════════════

class AdaptiveEngagementAgent {
  static final AdaptiveEngagementAgent _instance = AdaptiveEngagementAgent._internal();
  factory AdaptiveEngagementAgent() => _instance;
  AdaptiveEngagementAgent._internal();
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // ═══════════════════════════════════════════════════════════════════
  // DECISION ENGINE
  // ═══════════════════════════════════════════════════════════════════
  
  /// Decide whether to send an intervention
  Future<InterventionDecision> shouldIntervene({
    required SafetyState currentState,
    required String userId,
  }) async {
    try {
      // 1. DETERMINISTIC OVERRIDE: Always intervene for critical states
      if (currentState.isCritical) {
        debugPrint('🧠 Engagement: CRITICAL state → immediate intervention');
        return InterventionDecision.immediate(
          channel: currentState.recommendedChannel,
          message: 'CRITICAL: Immediate action required',
        );
      }
      
      // 2. Load engagement profile
      final profile = await _getEngagementProfile(userId);
      
      // 3. Calculate fatigue score
      final fatigueScore = _calculateFatigueScore(profile);
      
      debugPrint('🧠 Engagement: Fatigue score = ${(fatigueScore * 100).toStringAsFixed(0)}%');
      
      // 4. Apply adaptive thresholds
      if (currentState == SafetyState.urgent) {
        // Urgent: Send unless extremely fatigued
        if (fatigueScore > 0.8) {
          return InterventionDecision.defer(
            reason: 'User extremely fatigued (${(fatigueScore * 100).toStringAsFixed(0)}%)',
          );
        }
      } else if (currentState.isPreventative) {
        // Preventative: More strict filtering
        if (fatigueScore > 0.5) {
          return InterventionDecision.defer(
            reason: 'User moderately fatigued (${(fatigueScore * 100).toStringAsFixed(0)}%)',
          );
        }
      }
      
      // 5. Check timing appropriateness
      if (!_isAppropriateTime(userId, profile)) {
        // Still send if urgent, just defer cautionary
        if (currentState == SafetyState.cautionary) {
          return InterventionDecision.defer(
            reason: 'Inappropriate time (sleep hours or DND)',
          );
        }
      }
      
      // 6. Select optimal intervention style
      final style = _selectInterventionStyle(profile);
      
      debugPrint('🧠 Engagement: ✅ Sending intervention (${style.tone.label} tone)');
      
      return InterventionDecision.send(
        channel: style.preferredChannel,
        message: 'Intervention approved',
        tone: style.tone,
      );
      
    } catch (e) {
      debugPrint('❌ Engagement: Error deciding intervention: $e');
      
      // Fail-safe: If uncertain, send the intervention
      return InterventionDecision.send(
        channel: currentState.recommendedChannel,
        message: 'Intervention (fail-safe)',
      );
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // ENGAGEMENT PROFILE
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get user's engagement profile
  Future<EngagementProfile> _getEngagementProfile(String userId) async {
    try {
      // Try local cache first (Hive)
      final box = await Hive.openBox('engagement_profiles');
      final cached = box.get('profile_$userId');
      
      if (cached != null) {
        final profile = EngagementProfile.fromJson(Map<String, dynamic>.from(cached as Map));
        
        // Only use if recent (< 24 hours old)
        if (DateTime.now().difference(profile.lastUpdated).inHours < 24) {
          return profile;
        }
      }
      
      // Fetch from Firestore and calculate
      final profile = await _calculateEngagementProfile(userId);
      
      // Cache locally
      await box.put('profile_$userId', profile.toJson());
      
      return profile;
      
    } catch (e) {
      debugPrint('❌ Engagement: Error getting profile: $e');
      return EngagementProfile.empty(userId);
    }
  }
  
  /// Calculate engagement profile from historical data
  Future<EngagementProfile> _calculateEngagementProfile(String userId) async {
    try {
      final now = DateTime.now();
      final last7Days = now.subtract(Duration(days: 7));
      
      // Get intervention history
      final interventionsSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('interventions')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last7Days))
          .get();
      
      if (interventionsSnapshot.docs.isEmpty) {
        return EngagementProfile.empty(userId);
      }
      
      // Calculate metrics
      final total = interventionsSnapshot.docs.length;
      final dismissed = interventionsSnapshot.docs.where((doc) {
        return doc.data()['dismissed'] == true;
      }).length;
      
      final dismissalRate = dismissed / total;
      
      // Calculate average response time
      final responseTimes = <Duration>[];
      for (final doc in interventionsSnapshot.docs) {
        final data = doc.data();
        final responded = data['respondedAt'] as Timestamp?;
        final sent = data['timestamp'] as Timestamp;
        
        if (responded != null) {
          responseTimes.add(responded.toDate().difference(sent.toDate()));
        }
      }
      
      final avgResponseTime = responseTimes.isEmpty
          ? Duration(hours: 1)
          : Duration(
              milliseconds: responseTimes
                  .map((d) => d.inMilliseconds)
                  .reduce((a, b) => a + b) ~/
                  responseTimes.length,
            );
      
      // Calculate tone effectiveness
      final toneEffectiveness = await _calculateToneEffectiveness(userId);
      
      return EngagementProfile(
        userId: userId,
        interventionsLast7Days: total,
        dismissedCount: dismissed,
        deliveredCount: total,
        dismissalRate: dismissalRate,
        averageResponseTime: avgResponseTime,
        toneEffectiveness: toneEffectiveness,
        lastUpdated: now,
      );
      
    } catch (e) {
      debugPrint('❌ Engagement: Error calculating profile: $e');
      return EngagementProfile.empty(userId);
    }
  }
  
  /// Calculate which tones work best for this user
  Future<Map<InterventionTone, double>> _calculateToneEffectiveness(String userId) async {
    final effectiveness = <InterventionTone, double>{};
    
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('interventions')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(Duration(days: 30))))
          .get();
      
      // Count successes by tone
      final toneSuccesses = <String, int>{};
      final toneTotal = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tone = data['tone'] as String?;
        final responded = data['respondedAt'] != null;
        
        if (tone != null) {
          toneTotal[tone] = (toneTotal[tone] ?? 0) + 1;
          if (responded) {
            toneSuccesses[tone] = (toneSuccesses[tone] ?? 0) + 1;
          }
        }
      }
      
      // Calculate success rate per tone
      for (final tone in InterventionTone.values) {
        final total = toneTotal[tone.name] ?? 0;
        if (total > 0) {
          final successes = toneSuccesses[tone.name] ?? 0;
          effectiveness[tone] = successes / total;
        } else {
          effectiveness[tone] = 0.5; // Default 50%
        }
      }
      
    } catch (e) {
      debugPrint('❌ Engagement: Error calculating tone effectiveness: $e');
      // Default all to 50%
      for (final tone in InterventionTone.values) {
        effectiveness[tone] = 0.5;
      }
    }
    
    return effectiveness;
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // FATIGUE CALCULATION
  // ═══════════════════════════════════════════════════════════════════
  
  /// Calculate user fatigue score (0.0 = not fatigued, 1.0 = extremely fatigued)
  double _calculateFatigueScore(EngagementProfile profile) {
    // Component 1: Dismissal rate (50% weight)
    final dismissalComponent = profile.dismissalRate * 0.5;
    
    // Component 2: Response time (30% weight)
    // Slow response = fatigued
    final responseMinutes = profile.averageResponseTime.inMinutes.toDouble();
    final responseComponent = min(responseMinutes / 60.0, 1.0) * 0.3;
    
    // Component 3: Recent intervention frequency (20% weight)
    // Too many recent interventions = fatigued
    final frequencyComponent = min(profile.interventionsLast7Days / 50.0, 1.0) * 0.2;
    
    final totalScore = dismissalComponent + responseComponent + frequencyComponent;
    
    return totalScore.clamp(0.0, 1.0);
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // INTERVENTION STYLE SELECTION
  // ═══════════════════════════════════════════════════════════════════
  
  /// Select optimal intervention style for user
  InterventionStyle _selectInterventionStyle(EngagementProfile profile) {
    // Find best-performing tone
    final sortedTones = profile.toneEffectiveness.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final bestTone = sortedTones.first.key;
    
    // 10% of the time, try a different tone to keep learning
    final shouldExplore = Random().nextDouble() < 0.1;
    
    final selectedTone = shouldExplore
        ? InterventionTone.values[Random().nextInt(InterventionTone.values.length)]
        : bestTone;
    
    debugPrint('🧠 Engagement: Selected tone = ${selectedTone.label} '
        '(effectiveness: ${(sortedTones.first.value * 100).toStringAsFixed(0)}%)');
    
    return InterventionStyle.fromTone(selectedTone);
  }
  
  /// Check if current time is appropriate for non-critical interventions
  bool _isAppropriateTime(String userId, EngagementProfile profile) {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Don't send non-critical alerts during sleep hours (10 PM - 7 AM)
    if (hour >= 22 || hour < 7) {
      return false;
    }
    
    // TODO: Check user's calendar for meetings
    // TODO: Check user's DND status
    
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // FEEDBACK RECORDING
  // ═══════════════════════════════════════════════════════════════════
  
  /// Record that user responded to intervention
  Future<void> recordResponse({
    required String userId,
    required String interventionId,
    required bool wasHelpful,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('interventions')
          .doc(interventionId)
          .update({
            'respondedAt': FieldValue.serverTimestamp(),
            'wasHelpful': wasHelpful,
          });
      
      // Clear cache to force recalculation
      final box = await Hive.openBox('engagement_profiles');
      await box.delete('profile_$userId');
      
    } catch (e) {
      debugPrint('❌ Engagement: Error recording response: $e');
    }
  }
  
  /// Record that user dismissed intervention
  Future<void> recordDismissal({
    required String userId,
    required String interventionId,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('interventions')
          .doc(interventionId)
          .update({
            'dismissedAt': FieldValue.serverTimestamp(),
            'dismissed': true,
          });
      
      // Clear cache to force recalculation
      final box = await Hive.openBox('engagement_profiles');
      await box.delete('profile_$userId');
      
    } catch (e) {
      debugPrint('❌ Engagement: Error recording dismissal: $e');
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// ENGAGEMENT PROFILE
/// ═══════════════════════════════════════════════════════════════════

class EngagementProfile {
  final String userId;
  final int interventionsLast7Days;
  final int dismissedCount;
  final int deliveredCount;
  final double dismissalRate;
  final Duration averageResponseTime;
  final Map<InterventionTone, double> toneEffectiveness;
  final DateTime lastUpdated;
  
  const EngagementProfile({
    required this.userId,
    required this.interventionsLast7Days,
    required this.dismissedCount,
    required this.deliveredCount,
    required this.dismissalRate,
    required this.averageResponseTime,
    required this.toneEffectiveness,
    required this.lastUpdated,
  });
  
  factory EngagementProfile.empty(String userId) => EngagementProfile(
    userId: userId,
    interventionsLast7Days: 0,
    dismissedCount: 0,
    deliveredCount: 0,
    dismissalRate: 0.0,
    averageResponseTime: Duration(minutes: 30),
    toneEffectiveness: {
      for (final tone in InterventionTone.values) tone: 0.5
    },
    lastUpdated: DateTime.now(),
  );
  
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'interventionsLast7Days': interventionsLast7Days,
    'dismissedCount': dismissedCount,
    'deliveredCount': deliveredCount,
    'dismissalRate': dismissalRate,
    'averageResponseTime': averageResponseTime.inMinutes,
    'toneEffectiveness': toneEffectiveness.map((k, v) => MapEntry(k.name, v)),
    'lastUpdated': lastUpdated.toIso8601String(),
  };
  
  factory EngagementProfile.fromJson(Map<String, dynamic> json) => EngagementProfile(
    userId: json['userId'] as String,
    interventionsLast7Days: json['interventionsLast7Days'] as int? ?? 0,
    dismissedCount: json['dismissedCount'] as int? ?? 0,
    deliveredCount: json['deliveredCount'] as int? ?? 0,
    dismissalRate: (json['dismissalRate'] as num?)?.toDouble() ?? 0.0,
    averageResponseTime: Duration(minutes: json['averageResponseTime'] as int? ?? 30),
    toneEffectiveness: (json['toneEffectiveness'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(
              InterventionTone.values.firstWhere((t) => t.name == k),
              (v as num).toDouble(),
            )) ??
        {for (final tone in InterventionTone.values) tone: 0.5},
    lastUpdated: DateTime.parse(json['lastUpdated'] as String? ?? DateTime.now().toIso8601String()),
  );
}

/// ═══════════════════════════════════════════════════════════════════
/// INTERVENTION DECISION
/// ═══════════════════════════════════════════════════════════════════

class InterventionDecision {
  final bool shouldSend;
  final InterventionChannel? channel;
  final String? message;
  final InterventionTone? tone;
  final String? reason;
  final Duration? deferUntil;
  
  const InterventionDecision.immediate({
    required this.channel,
    required this.message,
    this.tone,
  }) : shouldSend = true, reason = 'Critical state - immediate intervention required', deferUntil = null;
  
  const InterventionDecision.send({
    required this.channel,
    required this.message,
    this.tone,
  }) : shouldSend = true, reason = 'Intervention approved', deferUntil = null;
  
  const InterventionDecision.defer({required this.reason})
      : shouldSend = false,
        channel = null,
        message = null,
        tone = null,
        deferUntil = null;
  
  const InterventionDecision.skip()
      : shouldSend = false,
        channel = null,
        message = null,
        tone = null,
        reason = 'Not necessary',
        deferUntil = null;
}
