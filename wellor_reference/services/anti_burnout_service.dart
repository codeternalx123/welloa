import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './behavioral_psychology_service.dart';
import './personality_adaptation_service.dart';

/// 🛡️ **ANTI-BURNOUT SYSTEM**
/// Prevents psychological burnout and app fatigue through proactive intervention.
///
/// **Burnout Signals:**
/// - Declining engagement (50%+ drop in activity)
/// - Notification fatigue (opening <20% of notifications)
/// - Goal abandonment (3+ missed goals)
/// - Streak anxiety (stress from maintaining streaks)
/// - Feature overwhelm (using <30% of features)
/// - Repetitive behavior (same actions repeatedly)
///
/// **Recovery Strategies:**
/// - Strategic notification silence periods
/// - "Recovery weeks" with reduced goals
/// - Goal simplification (1-3 goals max)
/// - Habit consolidation (focus on strongest habits)
/// - Celebration of small wins
/// - Reframing: progress over perfection

enum BurnoutStage {
  healthy,       // No signs of burnout
  earlyWarning,  // 1-2 warning signs
  moderate,      // 3-4 warning signs
  severe,        // 5+ warning signs
  recovered,     // In recovery mode
}

enum BurnoutSignal {
  engagementDrop,        // 50%+ drop in activity
  notificationFatigue,   // Opening <20% of notifications
  goalAbandonment,       // 3+ incomplete goals
  streakAnxiety,         // Stress from maintaining streaks
  featureOverwhelm,      // Using <30% of features
  repetitiveBehavior,    // Doing same actions
  consecutiveMisses,     // Missing daily actions 3+ days
  increasedNegativity,   // Negative feedback/ratings
}

class BurnoutAssessment {
  final String userId;
  final DateTime assessmentDate;
  final BurnoutStage stage;
  final List<BurnoutSignal> detectedSignals;
  final double burnoutScore; // 0-100
  final Map<String, dynamic> metrics;
  final List<String> recommendations;
  final bool needsImmediateIntervention;

  BurnoutAssessment({
    required this.userId,
    required this.assessmentDate,
    required this.stage,
    required this.detectedSignals,
    required this.burnoutScore,
    required this.metrics,
    required this.recommendations,
    required this.needsImmediateIntervention,
  });

  bool get isHealthy => stage == BurnoutStage.healthy;
  bool get needsRecovery => stage == BurnoutStage.moderate || stage == BurnoutStage.severe;
}

class RecoveryPlan {
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final String recoveryStrategy;
  final List<String> actions;
  final Map<String, dynamic> adjustments; // Notification freq, goal count, etc.
  final bool isActive;

  RecoveryPlan({
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.recoveryStrategy,
    required this.actions,
    required this.adjustments,
    this.isActive = true,
  });

  Duration get duration => endDate.difference(startDate);
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
}

class AntiBurnoutService {
  static final AntiBurnoutService _instance = AntiBurnoutService._internal();
  factory AntiBurnoutService() => _instance;
  AntiBurnoutService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BehavioralPsychologyService _psychService = BehavioralPsychologyService();
  final PersonalityAdaptationService _personalityService = PersonalityAdaptationService();

  // ============================================================================
  // BURNOUT DETECTION
  // ============================================================================

  /// Assess user for burnout signals
  Future<BurnoutAssessment> assessBurnout(String userId) async {
    debugPrint('🛡️ Assessing burnout for user $userId');

    final profile = await _psychService.getProfile(userId);
    if (profile == null) {
      return BurnoutAssessment(
        userId: userId,
        assessmentDate: DateTime.now(),
        stage: BurnoutStage.healthy,
        detectedSignals: [],
        burnoutScore: 0,
        metrics: {},
        recommendations: [],
        needsImmediateIntervention: false,
      );
    }

    final signals = <BurnoutSignal>[];
    final metrics = <String, dynamic>{};

    // Signal 1: Engagement drop
    final engagementDrop = await _detectEngagementDrop(userId);
    metrics['engagementDrop'] = engagementDrop;
    if (engagementDrop > 50) signals.add(BurnoutSignal.engagementDrop);

    // Signal 2: Notification fatigue
    final notificationOpenRate = await _calculateNotificationOpenRate(userId);
    metrics['notificationOpenRate'] = notificationOpenRate;
    if (notificationOpenRate < 20) signals.add(BurnoutSignal.notificationFatigue);

    // Signal 3: Goal abandonment
    final abandonedGoals = await _countAbandonedGoals(userId);
    metrics['abandonedGoals'] = abandonedGoals;
    if (abandonedGoals >= 3) signals.add(BurnoutSignal.goalAbandonment);

    // Signal 4: Streak anxiety
    final streakAnxiety = _detectStreakAnxiety(profile);
    metrics['streakAnxiety'] = streakAnxiety;
    if (streakAnxiety) signals.add(BurnoutSignal.streakAnxiety);

    // Signal 5: Feature overwhelm
    final featureUsage = await _calculateFeatureUsage(userId);
    metrics['featureUsage'] = featureUsage;
    if (featureUsage < 30) signals.add(BurnoutSignal.featureOverwhelm);

    // Signal 6: Repetitive behavior
    final repetitiveBehavior = await _detectRepetitiveBehavior(userId);
    metrics['repetitiveBehavior'] = repetitiveBehavior;
    if (repetitiveBehavior) signals.add(BurnoutSignal.repetitiveBehavior);

    // Signal 7: Consecutive misses
    final consecutiveMisses = await _countConsecutiveMisses(userId);
    metrics['consecutiveMisses'] = consecutiveMisses;
    if (consecutiveMisses >= 3) signals.add(BurnoutSignal.consecutiveMisses);

    // Calculate burnout score
    final burnoutScore = _calculateBurnoutScore(signals, profile);

    // Determine stage
    final stage = _determineBurnoutStage(signals.length, burnoutScore);

    // Generate recommendations
    final recommendations = _generateRecommendations(signals, profile, stage);

    final assessment = BurnoutAssessment(
      userId: userId,
      assessmentDate: DateTime.now(),
      stage: stage,
      detectedSignals: signals,
      burnoutScore: burnoutScore,
      metrics: metrics,
      recommendations: recommendations,
      needsImmediateIntervention: stage == BurnoutStage.severe,
    );

    // Store assessment
    await _storeAssessment(assessment);

    debugPrint('🛡️ Burnout assessment: ${stage.toString().split('.').last}, ${signals.length} signals detected');

    return assessment;
  }

  Future<double> _detectEngagementDrop(String userId) async {
    final now = DateTime.now();
    final recent3Days = await _getEventCount(userId, now.subtract(const Duration(days: 3)), now);
    final previous4Days = await _getEventCount(
      userId,
      now.subtract(const Duration(days: 7)),
      now.subtract(const Duration(days: 3)),
    );

    if (previous4Days == 0) return 0;

    final drop = ((previous4Days - recent3Days) / previous4Days * 100).clamp(0, 100);
    return drop.toDouble();
  }

  Future<double> _calculateNotificationOpenRate(String userId) async {
    final now = DateTime.now();
    final sent = await _getNotificationCount(userId, 'sent', now.subtract(const Duration(days: 7)), now);
    final opened = await _getNotificationCount(userId, 'opened', now.subtract(const Duration(days: 7)), now);

    if (sent == 0) return 100; // No notifications sent = no fatigue

    return (opened / sent * 100).clamp(0, 100);
  }

  Future<int> _countAbandonedGoals(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .where('status', isEqualTo: 'abandoned')
        .where('abandonedAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
        .get();

    return snapshot.docs.length;
  }

  bool _detectStreakAnxiety(UserPsychologyProfile profile) {
    // Long streaks (60+) + high neuroticism = anxiety
    if (profile.currentStreak > 60) {
      final neuroticism = profile.bigFiveTraits['neuroticism'] ?? 50;
      return neuroticism > 60;
    }
    return false;
  }

  Future<double> _calculateFeatureUsage(String userId) async {
    final usedFeatures = await _getUsedFeatures(userId, days: 14);
    const totalFeatures = 15; // scan, meal plan, health team, etc.

    return (usedFeatures.length / totalFeatures * 100).clamp(0, 100);
  }

  Future<bool> _detectRepetitiveBehavior(String userId) async {
    final events = await _getRecentEvents(userId, days: 7);
    
    // Check if user is doing the same action >80% of the time
    final eventCounts = <String, int>{};
    for (final event in events) {
      eventCounts[event.eventType] = (eventCounts[event.eventType] ?? 0) + 1;
    }

    if (eventCounts.isEmpty) return false;

    final maxCount = eventCounts.values.reduce((a, b) => a > b ? a : b);
    final repetitionRate = maxCount / events.length;

    return repetitionRate > 0.8;
  }

  Future<int> _countConsecutiveMisses(String userId) async {
    final events = await _getRecentEvents(userId, days: 7);

    // Count consecutive days without meaningful activity
    int consecutiveMisses = 0;
    DateTime checkDate = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final dayEvents = events.where((e) {
        final eventDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
        final checkNormalized = DateTime(checkDate.year, checkDate.month, checkDate.day);
        return eventDate == checkNormalized;
      }).toList();

      final meaningfulEvents = dayEvents.where((e) => 
        e.eventType == 'scan' || e.eventType == 'meal_plan'
      ).length;

      if (meaningfulEvents == 0) {
        consecutiveMisses++;
      } else {
        break; // Stop at first active day
      }

      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return consecutiveMisses;
  }

  double _calculateBurnoutScore(List<BurnoutSignal> signals, UserPsychologyProfile profile) {
    double score = signals.length * 15.0; // Base: 15 points per signal

    // Amplify based on profile
    if (profile.burnoutRisk > 70) score += 20;
    if (profile.engagementScore < 30) score += 15;
    if (profile.habitStrength < 30) score += 10;

    return score.clamp(0, 100);
  }

  BurnoutStage _determineBurnoutStage(int signalCount, double burnoutScore) {
    if (burnoutScore >= 75 || signalCount >= 5) return BurnoutStage.severe;
    if (burnoutScore >= 50 || signalCount >= 3) return BurnoutStage.moderate;
    if (burnoutScore >= 25 || signalCount >= 1) return BurnoutStage.earlyWarning;
    return BurnoutStage.healthy;
  }

  List<String> _generateRecommendations(
    List<BurnoutSignal> signals,
    UserPsychologyProfile profile,
    BurnoutStage stage,
  ) {
    final recommendations = <String>[];

    if (signals.contains(BurnoutSignal.notificationFatigue)) {
      recommendations.add('Reduce notifications by 50% for the next week');
    }

    if (signals.contains(BurnoutSignal.goalAbandonment)) {
      recommendations.add('Simplify to 1-2 core goals only');
    }

    if (signals.contains(BurnoutSignal.streakAnxiety)) {
      recommendations.add('Introduce "flex days" where streaks don\'t break');
    }

    if (signals.contains(BurnoutSignal.featureOverwhelm)) {
      recommendations.add('Focus on core features: scan + meal plan only');
    }

    if (signals.contains(BurnoutSignal.repetitiveBehavior)) {
      recommendations.add('Introduce variety: try new features or meal types');
    }

    if (stage == BurnoutStage.severe) {
      recommendations.insert(0, 'URGENT: Initiate 7-day recovery mode');
    }

    return recommendations;
  }

  // ============================================================================
  // RECOVERY INTERVENTIONS
  // ============================================================================

  /// Initiate recovery mode
  Future<RecoveryPlan> initiateRecoveryMode({
    required String userId,
    int durationDays = 7,
  }) async {
    debugPrint('🛡️ Initiating recovery mode for user $userId');

    final profile = await _psychService.getProfile(userId);
    final assessment = await assessBurnout(userId);

    // Determine recovery strategy based on burnout stage
    String strategy = '';
    List<String> actions = [];
    Map<String, dynamic> adjustments = {};

    if (assessment.stage == BurnoutStage.severe) {
      strategy = 'Intensive Recovery';
      actions = [
        'Pause all goals except 1 core habit',
        'Reduce notifications to 1 per day',
        'No streak pressure (auto-forgive misses)',
        'Focus on self-compassion',
        'Celebrate ANY engagement',
      ];
      adjustments = {
        'notificationFrequency': 'minimal',
        'maxActiveGoals': 1,
        'streakAutoForgive': true,
        'celebrateSmallWins': true,
      };
    } else if (assessment.stage == BurnoutStage.moderate) {
      strategy = 'Moderate Recovery';
      actions = [
        'Reduce goals to 2-3 core habits',
        'Cut notifications by 50%',
        'Add 2 flex days per week (no streak penalty)',
        'Simplify meal plans',
      ];
      adjustments = {
        'notificationFrequency': 'reduced',
        'maxActiveGoals': 3,
        'flexDaysPerWeek': 2,
        'simplifiedMealPlans': true,
      };
    } else {
      strategy = 'Gentle Recovery';
      actions = [
        'Maintain 3-4 core habits',
        'Optimize notification timing',
        'Add 1 flex day per week',
        'Celebrate progress over perfection',
      ];
      adjustments = {
        'notificationFrequency': 'optimized',
        'maxActiveGoals': 4,
        'flexDaysPerWeek': 1,
      };
    }

    final plan = RecoveryPlan(
      userId: userId,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: durationDays)),
      recoveryStrategy: strategy,
      actions: actions,
      adjustments: adjustments,
    );

    // Store recovery plan
    await _storeRecoveryPlan(plan);

    // Apply adjustments immediately
    await _applyRecoveryAdjustments(userId, adjustments);

    debugPrint('✅ Recovery mode activated: $strategy for $durationDays days');

    return plan;
  }

  Future<void> _applyRecoveryAdjustments(String userId, Map<String, dynamic> adjustments) async {
    // Update user preferences
    await _firestore.collection('users').doc(userId).update({
      'recoveryMode': true,
      'recoveryAdjustments': adjustments,
    });

    // TODO: Integrate with notification service to reduce frequency
    // TODO: Integrate with goal service to pause goals
  }

  /// Check if recovery plan is complete
  Future<bool> checkRecoveryProgress(String userId) async {
    final plan = await _getActiveRecoveryPlan(userId);
    if (plan == null) return false;

    if (DateTime.now().isAfter(plan.endDate)) {
      // Recovery period ended - assess progress
      final newAssessment = await assessBurnout(userId);

      if (newAssessment.burnoutScore < 40) {
        // Recovery successful!
        await _completeRecoveryPlan(userId);
        debugPrint('✅ Recovery complete! Burnout score: ${newAssessment.burnoutScore}');
        return true;
      } else {
        // Extend recovery
        await _extendRecoveryPlan(userId, days: 7);
        debugPrint('⏰ Recovery extended by 7 days');
        return false;
      }
    }

    return false;
  }

  Future<void> _completeRecoveryPlan(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'recoveryMode': false,
      'recoveryAdjustments': null,
    });

    // Mark plan as inactive
    final planDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('recovery_plans')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (planDoc.docs.isNotEmpty) {
      await planDoc.docs.first.reference.update({'isActive': false});
    }
  }

  Future<void> _extendRecoveryPlan(String userId, {int days = 7}) async {
    final planDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('recovery_plans')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (planDoc.docs.isNotEmpty) {
      final currentEndDate = DateTime.parse(planDoc.docs.first.data()['endDate']);
      await planDoc.docs.first.reference.update({
        'endDate': currentEndDate.add(Duration(days: days)).toIso8601String(),
      });
    }
  }

  // ============================================================================
  // PROACTIVE BURNOUT PREVENTION
  // ============================================================================

  /// Schedule automatic burnout checks
  Future<void> scheduleAutomaticBurnoutChecks(String userId) async {
    // Check burnout every 3 days
    // TODO: Integrate with background task scheduler
    debugPrint('🛡️ Scheduled automatic burnout checks for user $userId');
  }

  /// Preemptive intervention before burnout occurs
  Future<void> preemptiveBurnoutPrevention(String userId) async {
    final assessment = await assessBurnout(userId);

    if (assessment.stage == BurnoutStage.earlyWarning) {
      // Subtle adjustments before it gets worse
      debugPrint('⚠️ Early burnout warning - applying preemptive measures');

      await _firestore.collection('users').doc(userId).update({
        'preemptiveBurnoutPrevention': {
          'reduceNotifications': true,
          'encourageRestDays': true,
          'simplifyGoals': true,
        },
      });
    }
  }

  // ============================================================================
  // DATA RETRIEVAL
  // ============================================================================

  Future<int> _getEventCount(String userId, DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('behavioral_events')
        .where('timestamp', isGreaterThan: start.toIso8601String())
        .where('timestamp', isLessThan: end.toIso8601String())
        .get();

    return snapshot.docs.length;
  }

  Future<int> _getNotificationCount(String userId, String type, DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: type)
        .where('timestamp', isGreaterThan: start.toIso8601String())
        .where('timestamp', isLessThan: end.toIso8601String())
        .get();

    return snapshot.docs.length;
  }

  Future<Set<String>> _getUsedFeatures(String userId, {int days = 14}) async {
    final events = await _getRecentEvents(userId, days: days);
    return events.map((e) => e.eventType).toSet();
  }

  Future<List<BehavioralEvent>> _getRecentEvents(String userId, {int days = 7}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('behavioral_events')
        .where('timestamp', isGreaterThan: startDate.toIso8601String())
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return BehavioralEvent(
        userId: userId,
        eventType: data['eventType'],
        timestamp: DateTime.parse(data['timestamp']),
        metadata: data['metadata'] ?? {},
      );
    }).toList();
  }

  Future<void> _storeAssessment(BurnoutAssessment assessment) async {
    await _firestore
        .collection('users')
        .doc(assessment.userId)
        .collection('burnout_assessments')
        .add({
      'assessmentDate': assessment.assessmentDate.toIso8601String(),
      'stage': assessment.stage.toString(),
      'detectedSignals': assessment.detectedSignals.map((s) => s.toString()).toList(),
      'burnoutScore': assessment.burnoutScore,
      'metrics': assessment.metrics,
      'recommendations': assessment.recommendations,
      'needsImmediateIntervention': assessment.needsImmediateIntervention,
    });
  }

  Future<void> _storeRecoveryPlan(RecoveryPlan plan) async {
    await _firestore
        .collection('users')
        .doc(plan.userId)
        .collection('recovery_plans')
        .add({
      'startDate': plan.startDate.toIso8601String(),
      'endDate': plan.endDate.toIso8601String(),
      'recoveryStrategy': plan.recoveryStrategy,
      'actions': plan.actions,
      'adjustments': plan.adjustments,
      'isActive': plan.isActive,
    });
  }

  Future<RecoveryPlan?> _getActiveRecoveryPlan(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('recovery_plans')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return RecoveryPlan(
      userId: userId,
      startDate: DateTime.parse(data['startDate']),
      endDate: DateTime.parse(data['endDate']),
      recoveryStrategy: data['recoveryStrategy'],
      actions: List<String>.from(data['actions']),
      adjustments: Map<String, dynamic>.from(data['adjustments']),
      isActive: data['isActive'],
    );
  }
}
