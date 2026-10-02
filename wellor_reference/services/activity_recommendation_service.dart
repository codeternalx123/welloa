import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './behavioral_psychology_service.dart';
import './personality_adaptation_service.dart';
import './goal_achievement_optimizer.dart';
import './cgm_integration_service.dart';
import './wearable_integration_service.dart';
import 'subscription_entitlement_resolver.dart';

/// 🎬 **ACTIVITY RECOMMENDATION ENGINE**
/// Context-aware recommendations based on capability, time, location, energy, and goals.
///
/// **Recommendation Factors:**
/// - Current capability (what user CAN do now)
/// - Time availability (5 min vs 30 min vs 1 hour)
/// - Location context (home, work, gym, travel)
/// - Energy level (tired vs energized)
/// - Health state (glucose level, sleep quality, stress)
/// - Goal alignment (what moves needle on goals)
/// - Habit momentum (build on existing habits)
///
/// **Recommendation Types:**
/// - Just-in-time interventions (right moment)
/// - Progressive overload (gradually harder)
/// - Variety injection (prevent boredom)
/// - Plateau breakers (new approaches)

enum RecommendationType {
  action,        // Specific action to take now
  habit,         // Habit to start building
  insight,       // Learning/educational content
  rest,          // Recovery recommendation
  celebration,   // Celebrate achievement
  adjustment,    // Modify existing behavior
}

enum ContextType {
  time,          // Morning, afternoon, evening
  location,      // Home, work, gym, travel
  energy,        // Low, medium, high
  health,        // Glucose, sleep, stress
  social,        // Alone, with family, with friends
}

enum CapabilityLevel {
  veryLow,       // Exhausted, sick, stressed
  low,           // Tired, low motivation
  moderate,      // Normal day
  high,          // Energized, motivated
  veryHigh,      // Peak state, flow
}

class ActivityRecommendation {
  final String id;
  final String userId;
  final RecommendationType type;
  final String title;
  final String description;
  final int estimatedMinutes;
  final CapabilityLevel requiredCapability;
  final List<ContextType> idealContexts;
  final double impactScore; // 0-100 (how much this helps goals)
  final double feasibilityScore; // 0-100 (how likely user will do it)
  final double priorityScore; // 0-100 (combined impact × feasibility)
  final List<String> relatedGoals; // Goal IDs this supports
  final Map<String, dynamic> reasoning; // Why this recommendation
  final DateTime recommendedAt;
  final DateTime? expiresAt; // Time-sensitive recommendations
  final bool isTimeSensitive;

  ActivityRecommendation({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.requiredCapability,
    required this.idealContexts,
    required this.impactScore,
    required this.feasibilityScore,
    required this.priorityScore,
    required this.relatedGoals,
    required this.reasoning,
    required this.recommendedAt,
    this.expiresAt,
    this.isTimeSensitive = false,
  });

  bool get isHighPriority => priorityScore > 70;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class ActivityRecommendationService {
  static final ActivityRecommendationService _instance = ActivityRecommendationService._internal();
  factory ActivityRecommendationService() => _instance;
  ActivityRecommendationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BehavioralPsychologyService _psychService = BehavioralPsychologyService();
  final PersonalityAdaptationService _personalityService = PersonalityAdaptationService();
  final GoalAchievementOptimizer _goalService = GoalAchievementOptimizer();
  final CGMIntegrationService _cgmService = CGMIntegrationService();
  final WearableIntegrationService _wearableService = WearableIntegrationService();

  // ============================================================================
  // CONTEXT DETECTION
  // ============================================================================

  /// Detect current user context
  Future<Map<String, dynamic>> detectContext(String userId) async {
    final now = DateTime.now();
    
    // Time context
    final timeContext = _detectTimeContext(now);

    // Energy level (from wearable data + recent activity)
    final energyLevel = await _detectEnergyLevel(userId);

    // Capability level (combination of energy, health, motivation)
    final capability = await _assessCurrentCapability(userId, energyLevel);

    // Health state (glucose, sleep, stress)
    final healthState = await _assessHealthState(userId);

    // Location context (would use GPS in production)
    final location = await _detectLocationContext(userId);

    // Available time (based on routine)
    final availableMinutes = await _estimateAvailableTime(userId, now);

    return {
      'time': timeContext,
      'energy': energyLevel,
      'capability': capability,
      'health': healthState,
      'location': location,
      'availableMinutes': availableMinutes,
      'timestamp': now,
    };
  }

  String _detectTimeContext(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }

  Future<double> _detectEnergyLevel(String userId) async {
    // Get recent sleep quality
    final sleepQuality = await _wearableService.getAverageSleepQuality(userId, days: 1);

    // Get recent activity level
    final exerciseMinutes = await _wearableService.getWeeklyExerciseMinutes(userId);

    // Combine factors
    double energy = 50.0; // Base

    // Sleep impact
    if (sleepQuality > 80) {
      energy += 20;
    } else if (sleepQuality < 50) {
      energy -= 20;
    }

    // Exercise impact (moderate exercise boosts energy)
    if (exerciseMinutes > 150) {
      energy += 15;
    } else if (exerciseMinutes < 50) {
      energy -= 10;
    }

    return energy.clamp(0, 100);
  }

  Future<CapabilityLevel> _assessCurrentCapability(String userId, double energyLevel) async {
    final profile = await _psychService.getProfile(userId);
    
    if (profile == null) return CapabilityLevel.moderate;

    // Factor in burnout risk
    double capability = energyLevel;

    if (profile.burnoutRisk > 70) {
      capability -= 30;
    }

    if (profile.engagementScore > 80) {
      capability += 20;
    }

    // Classify
    if (capability >= 80) return CapabilityLevel.veryHigh;
    if (capability >= 60) return CapabilityLevel.high;
    if (capability >= 40) return CapabilityLevel.moderate;
    if (capability >= 20) return CapabilityLevel.low;
    return CapabilityLevel.veryLow;
  }

  Future<Map<String, dynamic>> _assessHealthState(String userId) async {
    final healthState = <String, dynamic>{};

    // Get latest glucose reading
    final glucose = await _cgmService.getLatestReading(userId);
    if (glucose != null) {
      healthState['glucose'] = glucose.value;
      healthState['glucoseTrend'] = glucose.trend.toString();
      healthState['glucoseRisk'] = glucose.riskLevel;
    }

    // Get sleep quality
    final sleepQuality = await _wearableService.getAverageSleepQuality(userId, days: 1);
    healthState['sleepQuality'] = sleepQuality;

    // Overall health score
    double healthScore = 50.0;
    if (glucose != null && glucose.value >= 70 && glucose.value <= 140) {
      healthScore += 25;
    }
    if (sleepQuality > 70) {
      healthScore += 25;
    }
    healthState['overallHealthScore'] = healthScore;

    return healthState;
  }

  Future<String> _detectLocationContext(String userId) async {
    final now = DateTime.now();
    final routine = await _personalityService.getRoutineProfile(userId);

    if (routine == null) return 'unknown';

    // Infer from time and routine
    if (now.hour >= 9 && now.hour < 17) {
      return 'work';
    } else if (now.hour >= 5 && now.hour < 9) {
      return 'home_morning';
    } else if (now.hour >= 17 && now.hour < 22) {
      return 'home_evening';
    }

    return 'home';
  }

  Future<int> _estimateAvailableTime(String userId, DateTime now) async {
    final routine = await _personalityService.getRoutineProfile(userId);
    
    if (routine == null) return 30; // Default

    // Check if it's a peak productivity hour
    if (routine.peakProductivityHours.contains(now.hour)) {
      return 15; // User is busy, only short activities
    }

    // Check if it's low energy hour
    if (routine.lowEnergyHours.contains(now.hour)) {
      return 45; // User might have more time but less capability
    }

    // Check work hours
    final workStart = routine.workSchedule['startHour'] as int? ?? 9;
    final workEnd = routine.workSchedule['endHour'] as int? ?? 17;

    if (now.hour >= workStart && now.hour < workEnd) {
      return 10; // During work, only micro-activities
    }

    return 30; // Default
  }

  // ============================================================================
  // RECOMMENDATION GENERATION
  // ============================================================================

  /// Generate personalized activity recommendations
  Future<List<ActivityRecommendation>> generateRecommendations({
    required String userId,
    int maxRecommendations = 5,
  }) async {
    debugPrint('🎬 Generating recommendations for user $userId');

    if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(userId)) {
      debugPrint('🎬 Activity recommendations: Ultra required ([hasActivityRecommendations])');
      return [];
    }

    // Detect current context
    final context = await detectContext(userId);

    // Get active goals
    final goals = await _goalService.getAllGoals(userId);
    final activeGoals = goals.where((g) => g.isActive).toList();

    // Get user profile
    final profile = await _psychService.getProfile(userId);

    if (profile == null) return [];

    final recommendations = <ActivityRecommendation>[];

    // Recommendation 1: Goal-aligned action
    if (activeGoals.isNotEmpty) {
      final goalRec = await _recommendGoalAction(
        userId,
        activeGoals.first,
        context,
        profile,
      );
      if (goalRec != null) recommendations.add(goalRec);
    }

    // Recommendation 2: Health intervention (if needed)
    final healthRec = await _recommendHealthIntervention(userId, context);
    if (healthRec != null) recommendations.add(healthRec);

    // Recommendation 3: Habit momentum
    final habitRec = await _recommendHabitMomentum(userId, context, profile);
    if (habitRec != null) recommendations.add(habitRec);

    // Recommendation 4: Energy-matched activity
    final energyRec = await _recommendEnergyMatchedActivity(userId, context);
    if (energyRec != null) recommendations.add(energyRec);

    // Recommendation 5: Variety injection (prevent boredom)
    final varietyRec = await _recommendVariety(userId, context);
    if (varietyRec != null) recommendations.add(varietyRec);

    // Sort by priority score
    recommendations.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // Take top N
    final topRecommendations = recommendations.take(maxRecommendations).toList();

    // Store recommendations
    for (final rec in topRecommendations) {
      await _storeRecommendation(rec);
    }

    debugPrint('✅ Generated ${topRecommendations.length} recommendations');

    return topRecommendations;
  }

  Future<ActivityRecommendation?> _recommendGoalAction(
    String userId,
    Goal goal,
    Map<String, dynamic> context,
    UserPsychologyProfile profile,
  ) async {
    // Find next incomplete milestone
    final nextMilestone = goal.milestones.firstWhere(
      (m) => !m.isCompleted,
      orElse: () => goal.milestones.first,
    );

    // Calculate impact (how much this moves goal forward)
    final impact = (100 - goal.progress) * 0.8; // Closer to completion = more impact

    // Calculate feasibility based on context
    final capability = context['capability'] as CapabilityLevel;
    final availableMinutes = context['availableMinutes'] as int;

    double feasibility = 50.0;

    // Match capability
    if (capability == CapabilityLevel.high || capability == CapabilityLevel.veryHigh) {
      feasibility += 30;
    } else if (capability == CapabilityLevel.low || capability == CapabilityLevel.veryLow) {
      feasibility -= 30;
    }

    // Match time availability
    if (availableMinutes >= 15) {
      feasibility += 20;
    } else {
      feasibility -= 10;
    }

    final priority = (impact * feasibility) / 100;

    return ActivityRecommendation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      type: RecommendationType.action,
      title: nextMilestone.title,
      description: 'Complete this milestone to progress on "${goal.title}"',
      estimatedMinutes: 15,
      requiredCapability: CapabilityLevel.moderate,
      idealContexts: [ContextType.time, ContextType.energy],
      impactScore: impact,
      feasibilityScore: feasibility,
      priorityScore: priority,
      relatedGoals: [goal.id],
      reasoning: {
        'type': 'goal_progress',
        'goalTitle': goal.title,
        'milestoneOrder': nextMilestone.order,
      },
      recommendedAt: DateTime.now(),
    );
  }

  Future<ActivityRecommendation?> _recommendHealthIntervention(
    String userId,
    Map<String, dynamic> context,
  ) async {
    final healthState = context['health'] as Map<String, dynamic>;

    // Check glucose
    final glucoseRisk = healthState['glucoseRisk'] as String?;
    if (glucoseRisk == 'LOW') {
      return ActivityRecommendation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: RecommendationType.action,
        title: 'Treat Low Blood Sugar',
        description: 'Your glucose is ${healthState['glucose']} mg/dL. Have 15g fast-acting carbs.',
        estimatedMinutes: 5,
        requiredCapability: CapabilityLevel.veryLow, // Low capability OK
        idealContexts: [ContextType.health],
        impactScore: 100.0, // Critical
        feasibilityScore: 95.0,
        priorityScore: 97.5,
        relatedGoals: [],
        reasoning: {'type': 'health_urgent', 'condition': 'hypoglycemia'},
        recommendedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        isTimeSensitive: true,
      );
    }

    // Check sleep
    final sleepQuality = healthState['sleepQuality'] as double?;
    if (sleepQuality != null && sleepQuality < 50) {
      return ActivityRecommendation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: RecommendationType.rest,
        title: 'Take a Power Nap',
        description: 'Your sleep quality was poor last night (${sleepQuality.toStringAsFixed(0)}%). A 20-min nap can help.',
        estimatedMinutes: 20,
        requiredCapability: CapabilityLevel.low,
        idealContexts: [ContextType.energy],
        impactScore: 70.0,
        feasibilityScore: 60.0,
        priorityScore: 65.0,
        relatedGoals: [],
        reasoning: {'type': 'health_recovery', 'condition': 'poor_sleep'},
        recommendedAt: DateTime.now(),
      );
    }

    return null;
  }

  Future<ActivityRecommendation?> _recommendHabitMomentum(
    String userId,
    Map<String, dynamic> context,
    UserPsychologyProfile profile,
  ) async {
    // Recommend continuing strongest habit
    if (profile.currentStreak > 7) {
      return ActivityRecommendation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: RecommendationType.habit,
        title: 'Maintain Your ${profile.currentStreak}-Day Streak',
        description: 'Scan your next meal to keep your streak alive!',
        estimatedMinutes: 3,
        requiredCapability: CapabilityLevel.low, // Easy to maintain
        idealContexts: [ContextType.time],
        impactScore: 60.0,
        feasibilityScore: 85.0,
        priorityScore: 72.5,
        relatedGoals: [],
        reasoning: {'type': 'habit_momentum', 'streak': profile.currentStreak},
        recommendedAt: DateTime.now(),
      );
    }

    return null;
  }

  Future<ActivityRecommendation?> _recommendEnergyMatchedActivity(
    String userId,
    Map<String, dynamic> context,
  ) async {
    final capability = context['capability'] as CapabilityLevel;
    final availableMinutes = context['availableMinutes'] as int;

    if (capability == CapabilityLevel.veryHigh && availableMinutes >= 30) {
      // High energy: challenge them
      return ActivityRecommendation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: RecommendationType.action,
        title: 'Create This Week\'s Meal Plan',
        description: 'You\'re in peak state! Perfect time for planning ahead.',
        estimatedMinutes: 25,
        requiredCapability: CapabilityLevel.high,
        idealContexts: [ContextType.energy, ContextType.time],
        impactScore: 75.0,
        feasibilityScore: 80.0,
        priorityScore: 77.5,
        relatedGoals: [],
        reasoning: {'type': 'energy_matched', 'capabilityLevel': 'high'},
        recommendedAt: DateTime.now(),
      );
    } else if (capability == CapabilityLevel.low && availableMinutes >= 10) {
      // Low energy: something easy
      return ActivityRecommendation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: RecommendationType.insight,
        title: 'Read Today\'s Health Insight',
        description: 'Low energy? Just read a quick health tip (2 min).',
        estimatedMinutes: 2,
        requiredCapability: CapabilityLevel.veryLow,
        idealContexts: [ContextType.energy],
        impactScore: 30.0,
        feasibilityScore: 95.0,
        priorityScore: 62.5,
        relatedGoals: [],
        reasoning: {'type': 'energy_matched', 'capabilityLevel': 'low'},
        recommendedAt: DateTime.now(),
      );
    }

    return null;
  }

  Future<ActivityRecommendation?> _recommendVariety(
    String userId,
    Map<String, dynamic> context,
  ) async {
    // Get recent activity types
    final recentEvents = await _getRecentEvents(userId, days: 7);
    final eventTypes = recentEvents.map((e) => e.eventType).toSet();

    // If user hasn't tried meal planning recently
    if (!eventTypes.contains('meal_plan')) {
      return ActivityRecommendation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: RecommendationType.action,
        title: 'Try AI Meal Planning',
        description: 'Generate a personalized meal plan based on your health goals.',
        estimatedMinutes: 10,
        requiredCapability: CapabilityLevel.moderate,
        idealContexts: [ContextType.time],
        impactScore: 65.0,
        feasibilityScore: 70.0,
        priorityScore: 67.5,
        relatedGoals: [],
        reasoning: {'type': 'variety_injection', 'feature': 'meal_planning'},
        recommendedAt: DateTime.now(),
      );
    }

    return null;
  }

  // ============================================================================
  // DATA RETRIEVAL
  // ============================================================================

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

  Future<void> _storeRecommendation(ActivityRecommendation rec) async {
    await _firestore
        .collection('users')
        .doc(rec.userId)
        .collection('recommendations')
        .doc(rec.id)
        .set({
      'type': rec.type.toString(),
      'title': rec.title,
      'description': rec.description,
      'estimatedMinutes': rec.estimatedMinutes,
      'requiredCapability': rec.requiredCapability.toString(),
      'idealContexts': rec.idealContexts.map((c) => c.toString()).toList(),
      'impactScore': rec.impactScore,
      'feasibilityScore': rec.feasibilityScore,
      'priorityScore': rec.priorityScore,
      'relatedGoals': rec.relatedGoals,
      'reasoning': rec.reasoning,
      'recommendedAt': rec.recommendedAt.toIso8601String(),
      'expiresAt': rec.expiresAt?.toIso8601String(),
      'isTimeSensitive': rec.isTimeSensitive,
    });
  }
}
