import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/medication_models.dart';
import 'subscription_entitlement_resolver.dart';
import 'gluco_coach_health_service.dart';
import 'cgm_integration_service.dart';

/// Multi-agent wellness orchestration for Ultra subscribers.
/// Uses meals, medications, optional CGM readings, and `users/{uid}/biometrics/current`
/// (Health Connect / HealthKit via [WearableDataService]) — not a medical device.

// ============================================================================
// MODELS
// ============================================================================

enum AgentType {
  metabolic,
  sleep,
  exercise,
  nutrition,
  stress,
  medication,
}

enum AgentStatus {
  active,
  paused,
  error,
  analyzing,
}

enum HealthGoalCategory {
  weightLoss,
  muscleGain,
  bloodSugarControl,
  sleepQuality,
  stressReduction,
  exerciseFrequency,
  medicationAdherence,
  nutritionBalance,
}

enum HealthAlertSeverity {
  info,
  warning,
  urgent,
  critical,
}

class HealthAgent {
  final AgentType type;
  final AgentStatus status;
  final String name;
  final String description;
  final DateTime lastActive;
  final int interventionsCount;
  final double performanceScore; // 0.0 - 1.0
  final Map<String, dynamic> currentState;

  HealthAgent({
    required this.type,
    required this.status,
    required this.name,
    required this.description,
    required this.lastActive,
    required this.interventionsCount,
    required this.performanceScore,
    required this.currentState,
  });

  factory HealthAgent.create(AgentType type) {
    final agents = {
      AgentType.metabolic: {
        'name': 'Metabolic Optimization Agent',
        'description': 'Monitors glucose, insulin, and metabolic health markers',
      },
      AgentType.sleep: {
        'name': 'Sleep Quality Agent',
        'description': 'Analyzes sleep cycles and optimizes circadian rhythm',
      },
      AgentType.exercise: {
        'name': 'Exercise Performance Agent',
        'description': 'Tracks workouts and optimizes recovery',
      },
      AgentType.nutrition: {
        'name': 'Nutrition Precision Agent',
        'description': 'Optimizes meal timing and macronutrient balance',
      },
      AgentType.stress: {
        'name': 'Stress Management Agent',
        'description': 'Monitors cortisol and provides stress reduction guidance',
      },
      AgentType.medication: {
        'name': 'Medication Adherence Agent',
        'description': 'Tracks medications and warns of interactions',
      },
    };

    final agentData = agents[type]!;
    return HealthAgent(
      type: type,
      status: AgentStatus.active,
      name: agentData['name']!,
      description: agentData['description']!,
      lastActive: DateTime.now(),
      interventionsCount: 0,
      performanceScore: 0.5,
      currentState: {},
    );
  }

  HealthAgent copyWith({
    AgentStatus? status,
    DateTime? lastActive,
    int? interventionsCount,
    double? performanceScore,
    Map<String, dynamic>? currentState,
  }) {
    return HealthAgent(
      type: type,
      status: status ?? this.status,
      name: name,
      description: description,
      lastActive: lastActive ?? this.lastActive,
      interventionsCount: interventionsCount ?? this.interventionsCount,
      performanceScore: performanceScore ?? this.performanceScore,
      currentState: currentState ?? this.currentState,
    );
  }
}

class HealthGoal {
  final String id;
  final HealthGoalCategory category;
  final String title;
  final String description;
  final double targetValue;
  final double currentValue;
  final DateTime startDate;
  final DateTime targetDate;
  final List<String> milestones;
  final int completedMilestones;
  final double progress; // 0.0 - 1.0
  final bool isActive;

  HealthGoal({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.targetDate,
    required this.milestones,
    required this.completedMilestones,
    required this.progress,
    required this.isActive,
  });

  factory HealthGoal.fromJson(Map<String, dynamic> json) {
    return HealthGoal(
      id: json['id'],
      category: HealthGoalCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
        orElse: () => HealthGoalCategory.weightLoss,
      ),
      title: json['title'],
      description: json['description'],
      targetValue: (json['targetValue'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate']),
      targetDate: DateTime.parse(json['targetDate']),
      milestones: List<String>.from(json['milestones'] ?? []),
      completedMilestones: json['completedMilestones'] ?? 0,
      progress: (json['progress'] as num).toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.toString(),
      'title': title,
      'description': description,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'startDate': startDate.toIso8601String(),
      'targetDate': targetDate.toIso8601String(),
      'milestones': milestones,
      'completedMilestones': completedMilestones,
      'progress': progress,
      'isActive': isActive,
    };
  }
}

class HealthAlert {
  final String id;
  final HealthAlertSeverity severity;
  final String title;
  final String message;
  final DateTime timestamp;
  final AgentType? sourceAgent;
  final bool isRead;
  final Map<String, dynamic>? actionData;

  HealthAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    this.sourceAgent,
    this.isRead = false,
    this.actionData,
  });

  factory HealthAlert.fromJson(Map<String, dynamic> json) {
    return HealthAlert(
      id: json['id'],
      severity: HealthAlertSeverity.values.firstWhere(
        (e) => e.toString() == json['severity'],
        orElse: () => HealthAlertSeverity.info,
      ),
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      sourceAgent: json['sourceAgent'] != null
          ? AgentType.values.firstWhere(
              (e) => e.toString() == json['sourceAgent'],
              orElse: () => AgentType.metabolic,
            )
          : null,
      isRead: json['isRead'] ?? false,
      actionData: json['actionData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'severity': severity.toString(),
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'sourceAgent': sourceAgent?.toString(),
      'isRead': isRead,
      'actionData': actionData,
    };
  }
}

class AgentIntervention {
  final String id;
  final AgentType agentType;
  final DateTime timestamp;
  final String action;
  final String reasoning;
  final Map<String, dynamic> data;
  final bool wasSuccessful;

  AgentIntervention({
    required this.id,
    required this.agentType,
    required this.timestamp,
    required this.action,
    required this.reasoning,
    required this.data,
    required this.wasSuccessful,
  });
}

// ============================================================================
// 🦄 UNICORN-GRADE MODELS
// ============================================================================

/// Predictive health risk score (0-100)
class HealthRiskScore {
  final String userId;
  final DateTime timestamp;
  final double overallRisk; // 0-100
  final Map<String, double> riskByCategory; // e.g., 'cardiovascular': 35.2
  final List<String> predictedConditions;
  final Map<String, double> conditionProbabilities;
  final List<String> recommendedInterventions;
  final String? aiReasoning;

  HealthRiskScore({
    required this.userId,
    required this.timestamp,
    required this.overallRisk,
    required this.riskByCategory,
    required this.predictedConditions,
    required this.conditionProbabilities,
    required this.recommendedInterventions,
    this.aiReasoning,
  });
}

/// Multi-modal data fusion result
class DataFusionInsight {
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> wearableData;
  final Map<String, dynamic> scanData;
  final Map<String, dynamic> medicationData;
  final Map<String, dynamic> geneticData;
  final String fusedInsight;
  final double confidenceScore;
  final List<String> dataSourcesUsed;

  DataFusionInsight({
    required this.userId,
    required this.timestamp,
    required this.wearableData,
    required this.scanData,
    required this.medicationData,
    required this.geneticData,
    required this.fusedInsight,
    required this.confidenceScore,
    required this.dataSourcesUsed,
  });
}

/// Causal inference result
class CausalInference {
  final String healthOutcome;
  final List<String> causalFactors;
  final Map<String, double> factorImpact; // % contribution to outcome
  final String rootCause;
  final List<String> interventionPathways;
  final double confidenceLevel;

  CausalInference({
    required this.healthOutcome,
    required this.causalFactors,
    required this.factorImpact,
    required this.rootCause,
    required this.interventionPathways,
    required this.confidenceLevel,
  });
}

// ============================================================================
// AI HEALTH TEAM SERVICE
// ============================================================================

class AIHealthTeamService {
  static final AIHealthTeamService _instance = AIHealthTeamService._internal();
  factory AIHealthTeamService() => _instance;
  AIHealthTeamService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CGMIntegrationService _cgm = CGMIntegrationService();
  final Map<AgentType, HealthAgent> _agents = {};
  final GlucoCoachHealthService _glucoCoachService = GlucoCoachHealthService();
  Timer? _monitoringTimer;
  Timer? _medicationReminderTimer;
  StreamSubscription? _cgmSubscription;
  
  // Medication tracking
  final Map<String, List<MedicationSchedule>> _userMedications = {};
  
  // Drug-food interaction database (expandable)
  static final Map<String, List<String>> _drugFoodInteractions = {
    'warfarin': ['kale', 'spinach', 'broccoli', 'vitamin k', 'green tea'],
    'atorvastatin': ['grapefruit', 'pomelo'],
    'simvastatin': ['grapefruit', 'pomelo'],
    'lovastatin': ['grapefruit', 'pomelo'],
    'metformin': ['alcohol', 'excessive carbs'],
    'levothyroxine': ['soy', 'coffee', 'calcium', 'iron'],
    'lisinopril': ['potassium', 'salt substitutes'],
    'amlodipine': ['grapefruit'],
    'omeprazole': ['magnesium', 'calcium'],
  };

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize AI Health Team (Ultra tier only)
  Future<void> initialize(String userId) async {
    debugPrint('🤖 AIHealthTeam: Initializing for user $userId');

    if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(userId)) {
      debugPrint(
        '🤖 AIHealthTeam: Skipping init — Ultra required (incl. [hasMedicationTracking])',
      );
      return;
    }

    // Create all 6 agents
    for (final agentType in AgentType.values) {
      _agents[agentType] = HealthAgent.create(agentType);
    }

    // Load user medications
    await _loadUserMedications(userId);

    // Start continuous monitoring
    await _startContinuousMonitoring(userId);

    // Start medication reminder system
    await _startMedicationReminders(userId);

    // Load existing goals
    await _loadHealthGoals(userId);

    // Subscribe to CGM data if available
    await _subscribeToCGMData(userId);

    // Run initial health risk assessment
    await _performHealthRiskAssessment(userId);

    debugPrint('✅ AIHealthTeam: All 6 agents initialized and monitoring');
    debugPrint('💊 Medication tracking: ${_userMedications[userId]?.length ?? 0} medications loaded');
  }

  /// Shutdown AI Health Team
  Future<void> shutdown() async {
    _monitoringTimer?.cancel();
    _medicationReminderTimer?.cancel();
    await _cgmSubscription?.cancel();
    _agents.clear();
    _userMedications.clear();
    debugPrint('🛑 AIHealthTeam: Shutdown complete');
  }

  // ============================================================================
  // CONTINUOUS MONITORING
  // ============================================================================

  Future<void> _startContinuousMonitoring(String userId) async {
    // Run health checks every 5 minutes
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _runHealthChecks(userId);
    });

    debugPrint('👁️ AIHealthTeam: 24/7 monitoring started (5-minute intervals)');
  }

  Future<void> _runHealthChecks(String userId) async {
    debugPrint('🔍 AIHealthTeam: Running health checks...');

    try {
      // Run each agent's analysis in parallel
      final futures = _agents.keys.map((type) => _runAgentAnalysis(userId, type));
      await Future.wait(futures);
    } catch (e) {
      debugPrint('❌ AIHealthTeam: Error in health checks: $e');
    }
  }

  Future<void> _runAgentAnalysis(String userId, AgentType type) async {
    final agent = _agents[type]!;
    
    // Update agent status
    _agents[type] = agent.copyWith(
      status: AgentStatus.analyzing,
      lastActive: DateTime.now(),
    );

    try {
      switch (type) {
        case AgentType.metabolic:
          await _analyzeMetabolicHealth(userId);
          break;
        case AgentType.sleep:
          await _analyzeSleepQuality(userId);
          break;
        case AgentType.exercise:
          await _analyzeExercisePerformance(userId);
          break;
        case AgentType.nutrition:
          await _analyzeNutritionPrecision(userId);
          break;
        case AgentType.stress:
          await _analyzeStressLevels(userId);
          break;
        case AgentType.medication:
          await _analyzeMedicationAdherence(userId);
          break;
      }

      // Update agent status to active
      _agents[type] = _agents[type]!.copyWith(
        status: AgentStatus.active,
        interventionsCount: _agents[type]!.interventionsCount + 1,
      );
    } catch (e) {
      debugPrint('❌ Agent $type error: $e');
      _agents[type] = _agents[type]!.copyWith(status: AgentStatus.error);
    }
  }

  // ============================================================================
  // AGENT-SPECIFIC ANALYSIS
  // ============================================================================

  Future<void> _analyzeMetabolicHealth(String userId) async {
    debugPrint('🩸 Metabolic Agent: Analyzing glucose levels...');

    final cgm = await _cgm.getLatestReading(userId);
    if (cgm != null && (cgm.isHigh || cgm.isCriticalHigh)) {
      await _createHealthAlert(
        userId: userId,
        severity: HealthAlertSeverity.warning,
        title: 'Glucose above target',
        message:
            'Latest CGM reading ${cgm.value.toStringAsFixed(0)} mg/dL. Consider carbs, activity, and your care plan.',
        sourceAgent: AgentType.metabolic,
      );
      return;
    }
    if (cgm != null && (cgm.isLow || cgm.isCriticalLow)) {
      await _createHealthAlert(
        userId: userId,
        severity: HealthAlertSeverity.urgent,
        title: 'Glucose below target',
        message:
            'Latest CGM reading ${cgm.value.toStringAsFixed(0)} mg/dL. Follow your clinician’s hypoglycemia plan.',
        sourceAgent: AgentType.metabolic,
      );
      return;
    }

    final recentMeals = await _firestore
        .collection('users')
        .doc(userId)
        .collection('meals')
        .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(hours: 24)))
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    int highCarbMeals = 0;
    double totalCarbs = 0;

    for (final doc in recentMeals.docs) {
      final carbs = (doc.data()['carbs'] as num?)?.toDouble() ?? 0.0;
      totalCarbs += carbs;
      if (carbs > 60) highCarbMeals++;
    }

    // Generate alert if too many high-carb meals
    if (highCarbMeals >= 3) {
      await _createHealthAlert(
        userId: userId,
        severity: HealthAlertSeverity.warning,
        title: 'High Carb Pattern Detected',
        message: 'You\'ve had $highCarbMeals high-carb meals in the last 24 hours. This may cause glucose spikes. Consider lower-carb options.',
        sourceAgent: AgentType.metabolic,
      );
    }
  }

  Future<void> _analyzeSleepQuality(String userId) async {
    debugPrint('😴 Sleep Agent: Analyzing sleep patterns...');

    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('biometrics')
        .doc('current')
        .get();
    if (!snap.exists) return;
    final d = snap.data()!;
    final hours = (d['sleepHours'] as num?)?.toDouble();
    if (hours != null && hours > 0 && hours < 6) {
      await _createHealthAlert(
        userId: userId,
        severity: HealthAlertSeverity.info,
        title: 'Short sleep detected',
        message:
            'About ${hours.toStringAsFixed(1)} h logged. Aim for 7–9 h when you can — recovery supports metabolic goals.',
        sourceAgent: AgentType.sleep,
      );
    }
  }

  Future<void> _analyzeExercisePerformance(String userId) async {
    debugPrint('🏃 Exercise Agent: Analyzing workout data...');

    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('biometrics')
        .doc('current')
        .get();
    if (!snap.exists) return;
    final d = snap.data()!;
    final steps = d['stepsToday'] as int? ?? 0;
    final workoutMin = d['workoutMinutesToday'] as int? ?? 0;
    if (steps > 0 && steps < 2500 && workoutMin < 10) {
      await _createHealthAlert(
        userId: userId,
        severity: HealthAlertSeverity.info,
        title: 'Light movement day',
        message:
            'Steps are on the low side today. A short walk can help glucose and mood.',
        sourceAgent: AgentType.exercise,
      );
    }
  }

  Future<void> _analyzeNutritionPrecision(String userId) async {
    debugPrint('🍽️ Nutrition Agent: Analyzing meal timing...');
    
    // Check meal timing patterns
    final recentMeals = await _firestore
        .collection('users')
        .doc(userId)
        .collection('meals')
        .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
        .orderBy('timestamp', descending: true)
        .get();

    // Analyze macro balance
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final doc in recentMeals.docs) {
      totalProtein += (doc.data()['protein'] as num?)?.toDouble() ?? 0.0;
      totalCarbs += (doc.data()['carbs'] as num?)?.toDouble() ?? 0.0;
      totalFat += (doc.data()['fat'] as num?)?.toDouble() ?? 0.0;
    }

    final totalMacros = totalProtein + totalCarbs + totalFat;
    if (totalMacros > 0) {
      final proteinPercent = (totalProtein / totalMacros) * 100;
      
      if (proteinPercent < 15) {
        await _createHealthAlert(
          userId: userId,
          severity: HealthAlertSeverity.info,
          title: 'Low Protein Intake',
          message: 'Your protein intake is only ${proteinPercent.toStringAsFixed(0)}%. Aim for 25-30% for optimal muscle maintenance.',
          sourceAgent: AgentType.nutrition,
        );
      }
    }
  }

  Future<void> _analyzeStressLevels(String userId) async {
    debugPrint('🧘 Stress Agent: Analyzing stress markers...');

    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('biometrics')
        .doc('current')
        .get();
    if (!snap.exists) return;
    final d = snap.data()!;
    final hrv = (d['heartRateVariability'] as num?)?.toDouble();
    if (hrv != null && hrv > 0 && hrv < 25) {
      await _createHealthAlert(
        userId: userId,
        severity: HealthAlertSeverity.info,
        title: 'Recovery load',
        message:
            'HRV from your synced device looks low. Prioritize sleep, hydration, and easy movement.',
        sourceAgent: AgentType.stress,
      );
    }
  }

  Future<void> _analyzeMedicationAdherence(String userId) async {
    debugPrint('💊 Medication Agent: Checking adherence...');
    
    final medications = _userMedications[userId] ?? [];
    if (medications.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check for missed medications in the last 24 hours
    final logs = await _firestore
        .collection('users')
        .doc(userId)
        .collection('medication_logs')
        .where('scheduledTime', isGreaterThan: now.subtract(const Duration(hours: 24)))
        .where('status', isEqualTo: AdherenceStatus.missed.toString())
        .get();

    if (logs.docs.isNotEmpty) {
      // Calculate adherence rate
      final totalLogs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medication_logs')
          .where('scheduledTime', isGreaterThan: now.subtract(const Duration(days: 7)))
          .get();

      final missedCount = logs.docs.length;
      final totalCount = totalLogs.docs.length;
      final adherenceRate = totalCount > 0 
          ? ((totalCount - missedCount) / totalCount * 100) 
          : 100.0;

      if (adherenceRate < 80) {
        await _createHealthAlert(
          userId: userId,
          severity: HealthAlertSeverity.warning,
          title: 'Low Medication Adherence',
          message: 'Your medication adherence is ${adherenceRate.toStringAsFixed(0)}%. You\'ve missed ${missedCount} doses in the last 7 days. Consistent medication use is crucial for your health.',
          sourceAgent: AgentType.medication,
        );

        // Send GlucoCoach alert if enabled
        final userPhone = await _getUserGlucoCoachNumber(userId);
        if (userPhone != null) {
          await _glucoCoachService.sendHealthAlert(
            userPhoneNumber: userPhone,
            title: 'Medication Adherence Alert',
            message: 'Your adherence rate is ${adherenceRate.toStringAsFixed(0)}%. Let\'s work together to improve this. Reply for support.',
            severity: 'warning',
          );
        }
      }
    }

    // Check for recent food scans and detect drug-food interactions
    await _checkDrugFoodInteractions(userId, medications);
  }

  /// Check for drug-food interactions from recent food scans
  Future<void> _checkDrugFoodInteractions(
    String userId,
    List<MedicationSchedule> medications,
  ) async {
    // Get recent food scans (last 2 hours)
    final recentMeals = await _firestore
        .collection('users')
        .doc(userId)
        .collection('meals')
        .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(hours: 2)))
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    for (final mealDoc in recentMeals.docs) {
      final mealData = mealDoc.data();
      final ingredients = (mealData['ingredients'] as List?)?.cast<String>() ?? [];
      final foodName = mealData['name'] as String? ?? 'Unknown food';

      // Check each medication for interactions
      for (final med in medications) {
        final medName = med.medicationName.toLowerCase();
        final interactingFoods = _drugFoodInteractions[medName] ?? [];

        for (final ingredient in ingredients) {
          final ingredientLower = ingredient.toLowerCase();
          
          // Check for interaction
          for (final interactingFood in interactingFoods) {
            if (ingredientLower.contains(interactingFood) || 
                interactingFood.contains(ingredientLower)) {
              
              // Determine severity
              final severity = _getInteractionSeverity(medName, ingredientLower);
              
              // Create alert
              await _createHealthAlert(
                userId: userId,
                severity: severity,
                title: 'Drug-Food Interaction Detected',
                message: 'Your medication ${med.medicationName} may interact with ${ingredient} in "${foodName}". ${_getInteractionAdvice(medName, ingredientLower)}',
                sourceAgent: AgentType.medication,
              );

              // Send GlucoCoach alert (critical/urgent only)
              if (severity == HealthAlertSeverity.critical || 
                  severity == HealthAlertSeverity.urgent) {
                final userPhone = await _getUserGlucoCoachNumber(userId);
                if (userPhone != null) {
                  await _glucoCoachService.sendDrugFoodInteractionWarning(
                    userPhoneNumber: userPhone,
                    medicationName: med.medicationName,
                    foodIngredient: ingredient,
                    severity: severity == HealthAlertSeverity.critical ? 'critical' : 'major',
                    warning: 'This combination can affect your medication\'s effectiveness or cause adverse effects.',
                    recommendation: _getInteractionAdvice(medName, ingredientLower),
                  );
                }
              }

              debugPrint('⚠️ Drug-food interaction detected: ${med.medicationName} + $ingredient');
            }
          }
        }
      }
    }
  }

  /// Determine interaction severity
  HealthAlertSeverity _getInteractionSeverity(String medication, String food) {
    // Critical interactions
    if ((medication.contains('warfarin') && 
         (food.contains('kale') || food.contains('spinach'))) ||
        (medication.contains('metformin') && food.contains('alcohol'))) {
      return HealthAlertSeverity.critical;
    }

    // Major interactions
    if ((medication.contains('statin') && food.contains('grapefruit')) ||
        (medication.contains('levothyroxine') && food.contains('soy'))) {
      return HealthAlertSeverity.urgent;
    }

    // Moderate interactions
    return HealthAlertSeverity.warning;
  }

  /// Get interaction advice
  String _getInteractionAdvice(String medication, String food) {
    if (medication.contains('warfarin') && 
        (food.contains('kale') || food.contains('spinach'))) {
      return 'Vitamin K-rich foods can reduce Warfarin\'s effectiveness. Maintain consistent intake and consult your doctor.';
    }
    
    if (medication.contains('statin') && food.contains('grapefruit')) {
      return 'Grapefruit increases Statin blood levels, raising risk of side effects. Avoid grapefruit while on this medication.';
    }

    if (medication.contains('levothyroxine') && food.contains('soy')) {
      return 'Soy can interfere with thyroid hormone absorption. Take medication 4 hours before/after soy consumption.';
    }

    if (medication.contains('metformin') && food.contains('alcohol')) {
      return 'Alcohol with Metformin increases risk of lactic acidosis. Limit alcohol intake while on this medication.';
    }

    return 'This combination may affect medication effectiveness. Consult your doctor or pharmacist.';
  }

  // ============================================================================
  // GOAL ATTAINMENT SYSTEM
  // ============================================================================

  Future<void> _loadHealthGoals(String userId) async {
    debugPrint('🎯 Loading health goals for user $userId');

    try {
      final goalsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_goals')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in goalsSnapshot.docs) {
        final goal = HealthGoal.fromJson(doc.data());
        await _trackGoalProgress(userId, goal);
      }
    } catch (e) {
      debugPrint('❌ Error loading goals: $e');
    }
  }

  Future<void> _trackGoalProgress(String userId, HealthGoal goal) async {
    // Calculate progress
    final progress = (goal.currentValue / goal.targetValue).clamp(0.0, 1.0);

    // Check if milestone reached
    final expectedMilestones = (progress * goal.milestones.length).floor();
    if (expectedMilestones > goal.completedMilestones) {
      await _createHealthAlert(
        userId: userId,
        severity: HealthAlertSeverity.info,
        title: 'Milestone Reached! 🎉',
        message: 'Great job! You\'ve completed milestone ${expectedMilestones} of ${goal.milestones.length} for "${goal.title}"',
        sourceAgent: null,
      );

      // Update milestone count
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_goals')
          .doc(goal.id)
          .update({
        'completedMilestones': expectedMilestones,
        'progress': progress,
      });
    }
  }

  // ============================================================================
  // MEDICATION TRACKING & REMINDERS
  // ============================================================================

  /// Load user medications from Firestore
  Future<void> _loadUserMedications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();

      final medications = snapshot.docs
          .map((doc) => MedicationSchedule.fromJson(doc.data()))
          .toList();

      _userMedications[userId] = medications;
      
      debugPrint('💊 Loaded ${medications.length} medications for user');
    } catch (e) {
      debugPrint('❌ Error loading medications: $e');
    }
  }

  /// Start medication reminder system
  Future<void> _startMedicationReminders(String userId) async {
    // Check every minute for upcoming medication times
    _medicationReminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) => _checkMedicationReminders(userId),
    );
    
    debugPrint('⏰ Medication reminder system started');
  }

  /// Check if any medications are due
  Future<void> _checkMedicationReminders(String userId) async {
    final medications = _userMedications[userId] ?? [];
    if (medications.isEmpty) return;

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final med in medications) {
      for (final scheduleTime in med.scheduleTime) {
        // Check if current time matches schedule (within 1 minute)
        if (scheduleTime == currentTime) {
          // Send reminder
          await _sendMedicationReminder(userId, med);
        }

        // Check for missed medications (30+ minutes late)
        final scheduledDateTime = _parseScheduleTime(scheduleTime);
        final minutesLate = now.difference(scheduledDateTime).inMinutes;
        
        if (minutesLate > 30 && minutesLate < 60) {
          await _sendMissedMedicationAlert(userId, med, scheduleTime);
        }
      }
    }
  }

  /// Send medication reminder
  Future<void> _sendMedicationReminder(
    String userId,
    MedicationSchedule medication,
  ) async {
    debugPrint('⏰ Sending medication reminder: ${medication.medicationName}');

    // Create in-app alert
    await _createHealthAlert(
      userId: userId,
      severity: HealthAlertSeverity.info,
      title: 'Medication Reminder',
      message: 'Time to take ${medication.medicationName} (${medication.dosage}${medication.dosageUnit})${medication.takeWithFood ? ' with food' : ''}',
      sourceAgent: AgentType.medication,
    );

    // Send GlucoCoach reminder (Premium/Ultra only)
    final userPhone = await _getUserGlucoCoachNumber(userId);
    if (userPhone != null) {
      await _glucoCoachService.sendMedicationReminder(
        userPhoneNumber: userPhone,
        medicationName: medication.medicationName,
        dosage: '${medication.dosage}${medication.dosageUnit}',
        time: DateTime.now().toString().split(' ')[1].substring(0, 5),
        takeWithFood: medication.takeWithFood,
      );
    }
  }

  /// Send missed medication alert
  Future<void> _sendMissedMedicationAlert(
    String userId,
    MedicationSchedule medication,
    String missedTime,
  ) async {
    debugPrint('⚠️ Missed medication: ${medication.medicationName} at $missedTime');

    // Check if alert already sent for this dose
    final today = DateTime.now();
    final alertId = '${medication.id}_${today.year}${today.month}${today.day}_$missedTime';
    
    final existingAlert = await _firestore
        .collection('users')
        .doc(userId)
        .collection('health_alerts')
        .doc(alertId)
        .get();

    if (existingAlert.exists) return; // Already sent

    // Send GlucoCoach alert
    final userPhone = await _getUserGlucoCoachNumber(userId);
    if (userPhone != null) {
      await _glucoCoachService.sendMissedMedicationAlert(
        userPhoneNumber: userPhone,
        medicationName: medication.medicationName,
        missedTime: missedTime,
      );
    }

    // Log missed dose
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('medication_logs')
        .add(MedicationLog(
          id: alertId,
          userId: userId,
          medicationId: medication.id,
          scheduledTime: _parseScheduleTime(missedTime),
          status: AdherenceStatus.missed,
        ).toJson());
  }

  /// Parse schedule time string to DateTime
  DateTime _parseScheduleTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Get user GlucoCoach number
  Future<String?> _getUserGlucoCoachNumber(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      return userData?['glucoCoachNumber'] as String?;
    } catch (e) {
      debugPrint('❌ Error getting GlucoCoach number: $e');
      return null;
    }
  }

  // ============================================================================
  // 🦄 UNICORN-GRADE FEATURES
  // ============================================================================

  /// Predictive health risk assessment using ML
  Future<void> _performHealthRiskAssessment(String userId) async {
    debugPrint('🔮 Performing predictive health risk assessment...');

    try {
      // Collect multi-modal data
      final userData = await _firestore.collection('users').doc(userId).get();
      final userProfile = userData.data();

      // Get recent health metrics
      final recentMeals = await _firestore
          .collection('users')
          .doc(userId)
          .collection('meals')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final medications = _userMedications[userId] ?? [];
      final healthConditions = await _getUserHealthConditions(userId);

      // Calculate risk factors
      final riskFactors = <String, double>{};

      // Dietary risk
      double totalCarbs = 0;
      double totalSaturatedFat = 0;
      int mealCount = 0;

      for (final meal in recentMeals.docs) {
        final data = meal.data();
        totalCarbs += (data['carbs'] as num?)?.toDouble() ?? 0;
        totalSaturatedFat += (data['saturatedFat'] as num?)?.toDouble() ?? 0;
        mealCount++;
      }

      final avgDailyCarbs = mealCount > 0 ? totalCarbs / (mealCount / 3) : 0;
      final avgDailySatFat = mealCount > 0 ? totalSaturatedFat / (mealCount / 3) : 0;

      // Cardiovascular risk
      if (avgDailyCarbs > 250 || avgDailySatFat > 20) {
        riskFactors['cardiovascular'] = 45.0;
      } else {
        riskFactors['cardiovascular'] = 25.0;
      }

      // Diabetes risk
      if (avgDailyCarbs > 300) {
        riskFactors['diabetes'] = 60.0;
      } else if (avgDailyCarbs > 200) {
        riskFactors['diabetes'] = 35.0;
      } else {
        riskFactors['diabetes'] = 15.0;
      }

      // Medication adherence risk
      final adherenceRate = await _calculateAdherenceRate(userId);
      if (adherenceRate < 80) {
        riskFactors['medication_nonadherence'] = 70.0;
      } else {
        riskFactors['medication_nonadherence'] = 20.0;
      }

      // Calculate overall risk score
      final overallRisk = riskFactors.values.reduce((a, b) => a + b) / riskFactors.length;

      // Generate recommendations
      final recommendations = <String>[];
      if (riskFactors['cardiovascular']! > 40) {
        recommendations.add('Reduce saturated fat intake and increase physical activity');
      }
      if (riskFactors['diabetes']! > 50) {
        recommendations.add('Lower daily carbohydrate intake and monitor blood sugar');
      }
      if (riskFactors['medication_nonadherence']! > 60) {
        recommendations.add('Improve medication adherence - set reminders and track doses');
      }

      // Store risk assessment
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_risk_assessments')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'overallRisk': overallRisk,
        'riskByCategory': riskFactors,
        'recommendations': recommendations,
      });

      // Alert if high risk
      if (overallRisk > 60) {
        await _createHealthAlert(
          userId: userId,
          severity: HealthAlertSeverity.warning,
          title: 'Elevated Health Risk Detected',
          message: 'Our AI has detected elevated health risks. Risk score: ${overallRisk.toStringAsFixed(0)}/100. ${recommendations.isNotEmpty ? recommendations.first : ''}',
          sourceAgent: null,
        );

        // Send GlucoCoach alert
        final userPhone = await _getUserGlucoCoachNumber(userId);
        if (userPhone != null) {
          await _glucoCoachService.sendHealthCoachingMessage(
            userPhoneNumber: userPhone,
            coachingMessage: 'Your latest health risk assessment shows an elevated score of ${overallRisk.toStringAsFixed(0)}/100. Let\'s work together to improve your health!',
            actionItems: recommendations.join('\n• '),
          );
        }
      }

      debugPrint('✅ Health risk assessment complete: ${overallRisk.toStringAsFixed(1)}/100');
    } catch (e) {
      debugPrint('❌ Error in health risk assessment: $e');
    }
  }

  /// Get user health conditions
  Future<List<UserHealthCondition>> _getUserHealthConditions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_conditions')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => UserHealthCondition.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading health conditions: $e');
      return [];
    }
  }

  /// Calculate medication adherence rate
  Future<double> _calculateAdherenceRate(String userId) async {
    try {
      final logs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medication_logs')
          .where('scheduledTime', 
                 isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
          .get();

      if (logs.docs.isEmpty) return 100.0;

      final takenCount = logs.docs
          .where((doc) => doc.data()['status'] == AdherenceStatus.taken.toString())
          .length;

      return (takenCount / logs.docs.length) * 100;
    } catch (e) {
      return 100.0;
    }
  }

  // ============================================================================
  // HEALTH ALERTS & NOTIFICATIONS
  // ============================================================================

  Future<void> _createHealthAlert({
    required String userId,
    required HealthAlertSeverity severity,
    required String title,
    required String message,
    AgentType? sourceAgent,
    Map<String, dynamic>? actionData,
  }) async {
    final alert = HealthAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      severity: severity,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      sourceAgent: sourceAgent,
      isRead: false,
      actionData: actionData,
    );

    // Save to Firestore
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('health_alerts')
        .doc(alert.id)
        .set(alert.toJson());

    // 🏗️ PRODUCTION TODO: Send GlucoCoach notification if enabled
    // 🏗️ PRODUCTION TODO: Send push notification

    debugPrint('📢 Alert created: ${alert.title} (${alert.severity})');
  }

  // ============================================================================
  // CGM INTEGRATION
  // ============================================================================

  Future<void> _subscribeToCGMData(String userId) async {
    debugPrint('🩸 Subscribing to CGM data stream...');
    
    // 🏗️ PRODUCTION TODO: Integrate with Abbott FreeStyle Libre APIs
    // For now, listen to Firestore collection for manual CGM entries
    
    _cgmSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('glucose_readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final reading = snapshot.docs.first.data();
        final glucose = (reading['value'] as num).toDouble();
        _checkGlucoseAlert(userId, glucose);
      }
    });
  }

  Future<void> _checkGlucoseAlert(String userId, double glucose) async {
    HealthAlertSeverity? severity;
    String? message;
    bool isCritical = false;

    if (glucose < 70) {
      severity = HealthAlertSeverity.urgent;
      message = 'Low blood sugar detected ($glucose mg/dL). Consume 15g fast-acting carbs immediately.';
      isCritical = false;
    } else if (glucose > 180 && glucose <= 250) {
      severity = HealthAlertSeverity.warning;
      message = 'High blood sugar detected ($glucose mg/dL). Avoid additional carbs and stay hydrated.';
      isCritical = false;
    } else if (glucose > 250) {
      severity = HealthAlertSeverity.critical;
      message = 'CRITICAL: Very high blood sugar ($glucose mg/dL). Contact your doctor immediately.';
      isCritical = true;
    }

    if (severity != null && message != null) {
      await _createHealthAlert(
        userId: userId,
        severity: severity,
        title: 'Glucose Alert',
        message: message,
        sourceAgent: AgentType.metabolic,
      );

      // Send GlucoCoach alert for glucose warnings
      final userPhone = await _getUserGlucoCoachNumber(userId);
      if (userPhone != null) {
        if (glucose < 70) {
          await _glucoCoachService.sendLowGlucoseAlert(
            userPhoneNumber: userPhone,
            glucoseLevel: glucose,
          );
        } else if (glucose > 180) {
          await _glucoCoachService.sendHighGlucoseAlert(
            userPhoneNumber: userPhone,
            glucoseLevel: glucose,
            isCritical: isCritical,
          );
        }
      }
    }
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// Get all active agents
  List<HealthAgent> getActiveAgents() {
    return _agents.values.toList();
  }

  /// Get agent by type
  HealthAgent? getAgent(AgentType type) {
    return _agents[type];
  }

  /// Get recent health alerts
  Future<List<HealthAlert>> getRecentAlerts(String userId, {int limit = 10}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('health_alerts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => HealthAlert.fromJson(doc.data())).toList();
  }

  /// Mark alert as read
  Future<void> markAlertRead(String userId, String alertId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('health_alerts')
        .doc(alertId)
        .update({'isRead': true});
  }

  /// Get health goals
  Future<List<HealthGoal>> getHealthGoals(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('health_goals')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => HealthGoal.fromJson(doc.data())).toList();
  }

  /// Create new health goal
  Future<void> createHealthGoal(String userId, HealthGoal goal) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('health_goals')
        .doc(goal.id)
        .set(goal.toJson());

    debugPrint('🎯 Health goal created: ${goal.title}');
  }

  // ============================================================================
  // MEDICATION MANAGEMENT API
  // ============================================================================

  /// Add new medication schedule
  Future<void> addMedication(String userId, MedicationSchedule medication) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('medications')
        .doc(medication.id)
        .set(medication.toJson());

    // Reload medications
    await _loadUserMedications(userId);

    debugPrint('💊 Medication added: ${medication.medicationName}');
  }

  /// Log medication taken
  Future<void> logMedicationTaken(
    String userId,
    String medicationId,
    DateTime scheduledTime,
  ) async {
    final log = MedicationLog(
      id: '${medicationId}_${scheduledTime.millisecondsSinceEpoch}',
      userId: userId,
      medicationId: medicationId,
      scheduledTime: scheduledTime,
      takenTime: DateTime.now(),
      status: AdherenceStatus.taken,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('medication_logs')
        .doc(log.id)
        .set(log.toJson());

    debugPrint('✅ Medication logged as taken');
  }

  /// Get medication adherence analytics
  Future<AdherenceAnalytics> getMedicationAdherence(String userId) async {
    final medications = _userMedications[userId] ?? [];
    final periodStart = DateTime.now().subtract(const Duration(days: 30));
    final periodEnd = DateTime.now();

    final logs = await _firestore
        .collection('users')
        .doc(userId)
        .collection('medication_logs')
        .where('scheduledTime', isGreaterThan: periodStart)
        .get();

    final totalDoses = logs.docs.length;
    final takenDoses = logs.docs
        .where((doc) => doc.data()['status'] == AdherenceStatus.taken.toString())
        .length;
    final missedDoses = logs.docs
        .where((doc) => doc.data()['status'] == AdherenceStatus.missed.toString())
        .length;
    final delayedDoses = logs.docs
        .where((doc) => doc.data()['status'] == AdherenceStatus.delayed.toString())
        .length;

    final adherenceRate = totalDoses > 0 ? takenDoses / totalDoses : 1.0;

    // Calculate per-medication adherence
    final adherenceByMedication = <String, double>{};
    for (final med in medications) {
      final medLogs = logs.docs
          .where((doc) => doc.data()['medicationId'] == med.id)
          .toList();
      
      if (medLogs.isNotEmpty) {
        final medTaken = medLogs
            .where((doc) => doc.data()['status'] == AdherenceStatus.taken.toString())
            .length;
        adherenceByMedication[med.medicationName] = medTaken / medLogs.length;
      }
    }

    return AdherenceAnalytics(
      userId: userId,
      adherenceRate: adherenceRate,
      totalDoses: totalDoses,
      takenDoses: takenDoses,
      missedDoses: missedDoses,
      delayedDoses: delayedDoses,
      periodStart: periodStart,
      periodEnd: periodEnd,
      adherenceByMedication: adherenceByMedication,
    );
  }

  /// Get user medications
  List<MedicationSchedule> getUserMedications(String userId) {
    return _userMedications[userId] ?? [];
  }

  /// Add health condition
  Future<void> addHealthCondition(String userId, UserHealthCondition condition) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('health_conditions')
        .doc(condition.id)
        .set(condition.toJson());

    debugPrint('🏥 Health condition added: ${condition.condition}');
  }
}
