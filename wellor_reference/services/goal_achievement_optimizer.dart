import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './behavioral_psychology_service.dart';
import './personality_adaptation_service.dart';
import 'subscription_entitlement_resolver.dart';

/// 🎯 **GOAL ACHIEVEMENT OPTIMIZER**
/// Science-based goal system targeting 95% achievement rate.
///
/// **Core Principles:**
/// - SMART goals (Specific, Measurable, Achievable, Relevant, Time-bound)
/// - Micro-stepping (break large goals into tiny milestones)
/// - Adaptive difficulty (too easy = boredom, too hard = burnout)
/// - Implementation intentions ("if-then" planning)
/// - Obstacle pre-mortem (plan for failures)
/// - Progress celebration (dopamine reinforcement)
/// - Social commitment (accountability)
/// - Goal shielding (protect from competing priorities)
///
/// **Key Features:**
/// - Automatic milestone decomposition
/// - Difficulty auto-adjustment
/// - Failure recovery protocols
/// - Progress visualization
/// - Celebration triggers

enum GoalStatus {
  planning,      // Goal created but not started
  active,        // Currently working on it
  achieved,      // Successfully completed
  abandoned,     // User gave up
  paused,        // Temporarily paused
  failed,        // Deadline passed without completion
}

enum GoalDifficulty {
  veryEasy,      // 95%+ success rate
  easy,          // 80-95% success rate
  moderate,      // 60-80% success rate
  challenging,   // 40-60% success rate
  difficult,     // 20-40% success rate
  tooHard,       // <20% success rate
}

enum GoalCategory {
  nutrition,     // Meal planning, calorie goals
  exercise,      // Activity, steps, workouts
  sleep,         // Sleep duration, quality
  medication,    // Adherence, timing
  health,        // Blood sugar, weight, vitals
  habit,         // General habit formation
}

class Goal {
  final String id;
  final String userId;
  final String title;
  final String description;
  final GoalCategory category;
  final GoalStatus status;
  final GoalDifficulty difficulty;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? deadline;
  final DateTime? completedAt;
  final List<Milestone> milestones;
  final double progress; // 0-100
  final int attemptCount; // How many times user tried
  final Map<String, dynamic> implementationIntention; // "If X, then Y"
  final List<String> obstacles; // Predicted obstacles
  final List<String> solutions; // Pre-planned solutions
  final bool socialCommitment; // Shared with community
  final Map<String, dynamic> rewards; // Celebration triggers

  Goal({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.difficulty,
    required this.createdAt,
    this.startedAt,
    this.deadline,
    this.completedAt,
    required this.milestones,
    required this.progress,
    this.attemptCount = 1,
    required this.implementationIntention,
    required this.obstacles,
    required this.solutions,
    this.socialCommitment = false,
    required this.rewards,
  });

  bool get isActive => status == GoalStatus.active;
  bool get isCompleted => status == GoalStatus.achieved;
  bool get needsAdjustment => difficulty == GoalDifficulty.tooHard || difficulty == GoalDifficulty.veryEasy;
  int get daysUntilDeadline => deadline != null ? deadline!.difference(DateTime.now()).inDays : -1;
}

class Milestone {
  final String id;
  final String title;
  final int order; // 1, 2, 3...
  final DateTime? completedAt;
  final bool isCompleted;
  final String actionVerb; // "Scan 3 meals", "Walk 5000 steps"
  final Map<String, dynamic> criteria; // Success criteria

  Milestone({
    required this.id,
    required this.title,
    required this.order,
    this.completedAt,
    this.isCompleted = false,
    required this.actionVerb,
    required this.criteria,
  });
}

class GoalAchievementOptimizer {
  static final GoalAchievementOptimizer _instance = GoalAchievementOptimizer._internal();
  factory GoalAchievementOptimizer() => _instance;
  GoalAchievementOptimizer._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BehavioralPsychologyService _psychService = BehavioralPsychologyService();
  final PersonalityAdaptationService _personalityService = PersonalityAdaptationService();

  // ============================================================================
  // GOAL CREATION & OPTIMIZATION
  // ============================================================================

  /// Create optimized SMART goal
  Future<Goal> createOptimizedGoal({
    required String userId,
    required String title,
    required String description,
    required GoalCategory category,
    DateTime? deadline,
  }) async {
    debugPrint('🎯 Creating optimized goal: $title');

    if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(userId)) {
      throw StateError(
        'Goal optimizer requires an active Ultra subscription ([hasGoalOptimizer]).',
      );
    }

    final profile = await _psychService.getProfile(userId);
    
    // Decompose into micro-milestones
    final milestones = await _decomposeIntoMilestones(title, description, category);

    // Assess difficulty
    final difficulty = await _assessGoalDifficulty(userId, category, milestones);

    // Generate implementation intentions
    final implementationIntention = _generateImplementationIntention(title, category);

    // Predict obstacles
    final obstacles = _predictObstacles(userId, category);

    // Generate solutions
    final solutions = _generateSolutions(obstacles, category);

    // Set default deadline if not provided (based on milestones)
    deadline ??= DateTime.now().add(Duration(days: milestones.length * 7));

    final goal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: title,
      description: description,
      category: category,
      status: GoalStatus.planning,
      difficulty: difficulty,
      createdAt: DateTime.now(),
      deadline: deadline,
      milestones: milestones,
      progress: 0.0,
      implementationIntention: implementationIntention,
      obstacles: obstacles,
      solutions: solutions,
      rewards: {
        'milestoneReward': 'badge',
        'completionReward': 'achievement + social share',
      },
    );

    // Store goal
    await _storeGoal(goal);

    debugPrint('✅ Goal created with ${milestones.length} milestones, difficulty: ${difficulty.toString().split('.').last}');

    return goal;
  }

  Future<List<Milestone>> _decomposeIntoMilestones(
    String title,
    String description,
    GoalCategory category,
  ) async {
    // Decompose goal into 5-7 micro-milestones
    final milestones = <Milestone>[];

    // Example decomposition (would be AI-generated in production)
    if (category == GoalCategory.nutrition) {
      milestones.addAll([
        Milestone(
          id: '1',
          title: 'Scan 3 meals for 2 days',
          order: 1,
          actionVerb: 'Scan meals',
          criteria: {'meals': 6, 'days': 2},
        ),
        Milestone(
          id: '2',
          title: 'Complete 1 meal plan',
          order: 2,
          actionVerb: 'Generate meal plan',
          criteria: {'mealPlans': 1},
        ),
        Milestone(
          id: '3',
          title: 'Follow meal plan for 3 days',
          order: 3,
          actionVerb: 'Follow plan',
          criteria: {'days': 3, 'adherence': 80},
        ),
        Milestone(
          id: '4',
          title: 'Track macros for 1 week',
          order: 4,
          actionVerb: 'Track macros',
          criteria: {'days': 7},
        ),
        Milestone(
          id: '5',
          title: 'Achieve target calories 5/7 days',
          order: 5,
          actionVerb: 'Hit calorie target',
          criteria: {'days': 5, 'target': 'calories'},
        ),
      ]);
    } else if (category == GoalCategory.exercise) {
      milestones.addAll([
        Milestone(
          id: '1',
          title: 'Walk 5000 steps for 3 days',
          order: 1,
          actionVerb: 'Walk steps',
          criteria: {'steps': 5000, 'days': 3},
        ),
        Milestone(
          id: '2',
          title: 'Walk 7500 steps for 3 days',
          order: 2,
          actionVerb: 'Walk steps',
          criteria: {'steps': 7500, 'days': 3},
        ),
        Milestone(
          id: '3',
          title: 'Walk 10000 steps for 5 days',
          order: 3,
          actionVerb: 'Walk steps',
          criteria: {'steps': 10000, 'days': 5},
        ),
      ]);
    } else if (category == GoalCategory.medication) {
      milestones.addAll([
        Milestone(
          id: '1',
          title: 'Take medication on time for 3 days',
          order: 1,
          actionVerb: 'Take medication',
          criteria: {'days': 3, 'onTime': true},
        ),
        Milestone(
          id: '2',
          title: 'Achieve 100% adherence for 1 week',
          order: 2,
          actionVerb: 'Medication adherence',
          criteria: {'days': 7, 'adherence': 100},
        ),
      ]);
    }

    return milestones;
  }

  Future<GoalDifficulty> _assessGoalDifficulty(
    String userId,
    GoalCategory category,
    List<Milestone> milestones,
  ) async {
    // Analyze user's past success rate for this category
    final pastGoals = await _getPastGoals(userId, category: category);
    
    if (pastGoals.isEmpty) {
      return GoalDifficulty.easy; // Start easy for new users
    }

    final successCount = pastGoals.where((g) => g.isCompleted).length;
    final successRate = successCount / pastGoals.length * 100;

    // Classify difficulty
    if (successRate >= 95) return GoalDifficulty.veryEasy;
    if (successRate >= 80) return GoalDifficulty.easy;
    if (successRate >= 60) return GoalDifficulty.moderate;
    if (successRate >= 40) return GoalDifficulty.challenging;
    if (successRate >= 20) return GoalDifficulty.difficult;
    return GoalDifficulty.tooHard;
  }

  Map<String, dynamic> _generateImplementationIntention(String title, GoalCategory category) {
    // "If X happens, then I will do Y"
    final intentions = <String, dynamic>{};

    if (category == GoalCategory.nutrition) {
      intentions['trigger'] = 'When I finish eating';
      intentions['action'] = 'I will scan my meal in the app';
    } else if (category == GoalCategory.exercise) {
      intentions['trigger'] = 'After morning coffee';
      intentions['action'] = 'I will walk for 10 minutes';
    } else if (category == GoalCategory.medication) {
      intentions['trigger'] = 'After breakfast';
      intentions['action'] = 'I will take my medication';
    }

    return intentions;
  }

  List<String> _predictObstacles(String userId, GoalCategory category) {
    // Common obstacles by category
    final obstacles = <String>[];

    if (category == GoalCategory.nutrition) {
      obstacles.addAll([
        'Eating out (hard to scan)',
        'Weekend social events',
        'Stress eating',
        'Meal planning takes time',
      ]);
    } else if (category == GoalCategory.exercise) {
      obstacles.addAll([
        'Bad weather',
        'Lack of time',
        'Fatigue after work',
        'No motivation',
      ]);
    } else if (category == GoalCategory.medication) {
      obstacles.addAll([
        'Forgetting to take it',
        'Running out of medication',
        'Side effects',
        'Traveling without pills',
      ]);
    }

    return obstacles;
  }

  List<String> _generateSolutions(List<String> obstacles, GoalCategory category) {
    final solutions = <String>[];

    for (final obstacle in obstacles) {
      if (obstacle.contains('Eating out')) {
        solutions.add('Take photos of menu items, scan later');
      } else if (obstacle.contains('Bad weather')) {
        solutions.add('Indoor exercise alternatives (yoga, dancing)');
      } else if (obstacle.contains('Forgetting')) {
        solutions.add('Set 3 daily reminders 10 min before medication time');
      } else if (obstacle.contains('time')) {
        solutions.add('Start with 5-minute version of the activity');
      } else if (obstacle.contains('stress')) {
        solutions.add('Call AI health coach for support');
      }
    }

    return solutions;
  }

  // ============================================================================
  // ADAPTIVE DIFFICULTY ADJUSTMENT
  // ============================================================================

  /// Adjust goal difficulty based on performance
  Future<void> adjustGoalDifficulty(String goalId) async {
    final goal = await _getGoal(goalId);
    if (goal == null) return;

    // Check milestone completion rate
    final completedMilestones = goal.milestones.where((m) => m.isCompleted).length;
    final milestoneCompletionRate = completedMilestones / goal.milestones.length * 100;

    GoalDifficulty newDifficulty = goal.difficulty;

    // Too easy: User completing milestones way ahead of schedule
    if (milestoneCompletionRate > 80 && goal.attemptCount == 1) {
      newDifficulty = _increaseDifficulty(goal.difficulty);
      debugPrint('📈 Increasing difficulty: ${newDifficulty.toString().split('.').last}');
    }
    // Too hard: User struggling (multiple attempts, low completion)
    else if (goal.attemptCount > 2 || milestoneCompletionRate < 20) {
      newDifficulty = _decreaseDifficulty(goal.difficulty);
      debugPrint('📉 Decreasing difficulty: ${newDifficulty.toString().split('.').last}');
    }

    if (newDifficulty != goal.difficulty) {
      await _updateGoalDifficulty(goalId, newDifficulty);
    }
  }

  GoalDifficulty _increaseDifficulty(GoalDifficulty current) {
    switch (current) {
      case GoalDifficulty.veryEasy:
        return GoalDifficulty.easy;
      case GoalDifficulty.easy:
        return GoalDifficulty.moderate;
      case GoalDifficulty.moderate:
        return GoalDifficulty.challenging;
      default:
        return current; // Don't increase beyond challenging
    }
  }

  GoalDifficulty _decreaseDifficulty(GoalDifficulty current) {
    switch (current) {
      case GoalDifficulty.tooHard:
        return GoalDifficulty.difficult;
      case GoalDifficulty.difficult:
        return GoalDifficulty.challenging;
      case GoalDifficulty.challenging:
        return GoalDifficulty.moderate;
      case GoalDifficulty.moderate:
        return GoalDifficulty.easy;
      default:
        return GoalDifficulty.veryEasy;
    }
  }

  // ============================================================================
  // FAILURE RECOVERY
  // ============================================================================

  /// Recover from goal failure
  Future<void> recoverFromFailure(String goalId) async {
    final goal = await _getGoal(goalId);
    if (goal == null) return;

    debugPrint('🔄 Recovering from goal failure: ${goal.title}');

    // Strategy 1: Simplify the goal
    final simplifiedMilestones = goal.milestones.take(3).toList(); // Keep only first 3 milestones

    // Strategy 2: Extend deadline
    final newDeadline = DateTime.now().add(const Duration(days: 14));

    // Strategy 3: Lower difficulty
    final newDifficulty = _decreaseDifficulty(goal.difficulty);

    // Strategy 4: Add accountability
    final socialCommitment = true;

    // Create revised goal
    await _firestore.collection('users').doc(goal.userId).collection('goals').doc(goalId).update({
      'milestones': simplifiedMilestones.map((m) => _milestoneToJson(m)).toList(),
      'deadline': newDeadline.toIso8601String(),
      'difficulty': newDifficulty.toString(),
      'socialCommitment': socialCommitment,
      'attemptCount': goal.attemptCount + 1,
      'status': GoalStatus.active.toString(),
    });

    debugPrint('✅ Goal recovered with simplified milestones and extended deadline');
  }

  // ============================================================================
  // PROGRESS CELEBRATION
  // ============================================================================

  /// Celebrate milestone completion
  Future<void> celebrateMilestone(String goalId, String milestoneId) async {
    final goal = await _getGoal(goalId);
    if (goal == null) return;

    final milestone = goal.milestones.firstWhere((m) => m.id == milestoneId);

    debugPrint('🎉 Celebrating milestone: ${milestone.title}');

    // Trigger celebration based on user archetype
    final profile = await _psychService.getProfile(goal.userId);
    
    if (profile?.archetype == UserArchetype.achiever) {
      // Show achievement badge
      await _triggerBadgeReward(goal.userId, 'milestone_${milestone.order}');
    } else if (profile?.archetype == UserArchetype.socializer) {
      // Offer social share
      await _triggerSocialShare(goal.userId, milestone.title);
    } else if (profile?.archetype == UserArchetype.explorer) {
      // Show insight/learning
      await _triggerInsightReward(goal.userId, milestone.title);
    }

    // Universal: Progress visualization
    await _updateProgressVisualization(goalId);
  }

  Future<void> _triggerBadgeReward(String userId, String badgeId) async {
    // TODO: Integrate with rewards system
    debugPrint('🏆 Badge earned: $badgeId');
  }

  Future<void> _triggerSocialShare(String userId, String achievement) async {
    // TODO: Integrate with social features
    debugPrint('📢 Social share prompted: $achievement');
  }

  Future<void> _triggerInsightReward(String userId, String achievement) async {
    // TODO: Generate personalized insight
    debugPrint('💡 Insight generated: $achievement');
  }

  Future<void> _updateProgressVisualization(String goalId) async {
    final goal = await _getGoal(goalId);
    if (goal == null) return;

    final completedCount = goal.milestones.where((m) => m.isCompleted).length;
    final progress = (completedCount / goal.milestones.length * 100);

    await _firestore.collection('users').doc(goal.userId).collection('goals').doc(goalId).update({
      'progress': progress,
    });
  }

  // ============================================================================
  // GOAL ANALYTICS
  // ============================================================================

  /// Calculate user's overall achievement rate
  Future<double> calculateAchievementRate(String userId) async {
    final goals = await getAllGoals(userId);

    if (goals.isEmpty) return 0.0;

    final achievedGoals = goals.where((g) => g.isCompleted).length;
    return (achievedGoals / goals.length * 100);
  }

  /// Get goal success prediction
  Future<double> predictGoalSuccess(String goalId) async {
    final goal = await _getGoal(goalId);
    if (goal == null) return 0.0;

    if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(goal.userId)) {
      return 50.0;
    }

    // Factors: difficulty, milestone progress, user history, time remaining
    double successProbability = 50.0; // Base

    // Factor 1: Difficulty
    switch (goal.difficulty) {
      case GoalDifficulty.veryEasy:
        successProbability += 30;
        break;
      case GoalDifficulty.easy:
        successProbability += 20;
        break;
      case GoalDifficulty.moderate:
        successProbability += 10;
        break;
      case GoalDifficulty.challenging:
        successProbability -= 10;
        break;
      case GoalDifficulty.difficult:
        successProbability -= 20;
        break;
      case GoalDifficulty.tooHard:
        successProbability -= 30;
        break;
    }

    // Factor 2: Current progress
    successProbability += goal.progress * 0.3;

    // Factor 3: User's historical success rate
    final achievementRate = await calculateAchievementRate(goal.userId);
    successProbability += (achievementRate - 50) * 0.2;

    // Factor 4: Time pressure
    if (goal.daysUntilDeadline < 3) {
      successProbability -= 15; // Tight deadline = stress
    }

    return successProbability.clamp(0, 100);
  }

  // ============================================================================
  // DATA RETRIEVAL
  // ============================================================================

  Future<Goal?> _getGoal(String goalId) async {
    // TODO: Implement goal retrieval
    return null;
  }

  Future<List<Goal>> _getPastGoals(String userId, {GoalCategory? category}) async {
    Query query = _firestore.collection('users').doc(userId).collection('goals');

    if (category != null) {
      query = query.where('category', isEqualTo: category.toString());
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => _goalFromDoc(doc)).toList();
  }

  Future<List<Goal>> getAllGoals(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .get();

    return snapshot.docs.map((doc) => _goalFromDoc(doc)).toList();
  }

  Goal _goalFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Goal(
      id: doc.id,
      userId: data['userId'],
      title: data['title'],
      description: data['description'],
      category: GoalCategory.values.firstWhere((e) => e.toString() == data['category']),
      status: GoalStatus.values.firstWhere((e) => e.toString() == data['status']),
      difficulty: GoalDifficulty.values.firstWhere((e) => e.toString() == data['difficulty']),
      createdAt: DateTime.parse(data['createdAt']),
      startedAt: data['startedAt'] != null ? DateTime.parse(data['startedAt']) : null,
      deadline: data['deadline'] != null ? DateTime.parse(data['deadline']) : null,
      completedAt: data['completedAt'] != null ? DateTime.parse(data['completedAt']) : null,
      milestones: (data['milestones'] as List).map((m) => _milestoneFromJson(m)).toList(),
      progress: (data['progress'] as num).toDouble(),
      attemptCount: data['attemptCount'] ?? 1,
      implementationIntention: Map<String, dynamic>.from(data['implementationIntention']),
      obstacles: List<String>.from(data['obstacles']),
      solutions: List<String>.from(data['solutions']),
      socialCommitment: data['socialCommitment'] ?? false,
      rewards: Map<String, dynamic>.from(data['rewards']),
    );
  }

  Milestone _milestoneFromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'],
      title: json['title'],
      order: json['order'],
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      isCompleted: json['isCompleted'] ?? false,
      actionVerb: json['actionVerb'],
      criteria: Map<String, dynamic>.from(json['criteria']),
    );
  }

  Map<String, dynamic> _milestoneToJson(Milestone milestone) {
    return {
      'id': milestone.id,
      'title': milestone.title,
      'order': milestone.order,
      'completedAt': milestone.completedAt?.toIso8601String(),
      'isCompleted': milestone.isCompleted,
      'actionVerb': milestone.actionVerb,
      'criteria': milestone.criteria,
    };
  }

  Future<void> _storeGoal(Goal goal) async {
    await _firestore
        .collection('users')
        .doc(goal.userId)
        .collection('goals')
        .doc(goal.id)
        .set({
      'userId': goal.userId,
      'title': goal.title,
      'description': goal.description,
      'category': goal.category.toString(),
      'status': goal.status.toString(),
      'difficulty': goal.difficulty.toString(),
      'createdAt': goal.createdAt.toIso8601String(),
      'startedAt': goal.startedAt?.toIso8601String(),
      'deadline': goal.deadline?.toIso8601String(),
      'completedAt': goal.completedAt?.toIso8601String(),
      'milestones': goal.milestones.map((m) => _milestoneToJson(m)).toList(),
      'progress': goal.progress,
      'attemptCount': goal.attemptCount,
      'implementationIntention': goal.implementationIntention,
      'obstacles': goal.obstacles,
      'solutions': goal.solutions,
      'socialCommitment': goal.socialCommitment,
      'rewards': goal.rewards,
    });
  }

  Future<void> _updateGoalDifficulty(String goalId, GoalDifficulty difficulty) async {
    // TODO: Update goal difficulty in Firestore
  }
}
