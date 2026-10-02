// lib/services/health_agent_service.dart
// AI Health Coaching Service
// Monitors glucose, meals, sleep, and activity streams from Firebase.
// Generates minimum-effective-dose (MED) interventions via Gemini LLM.
// GlucoCoach replies use Claude Sonnet 3.5 via GlucoCoachAIService.
// Pushes proactive GlucoCoach messages through the GlucoCoachAIService.

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'multi_ai_service.dart';
import 'gluco_coach_ai_service.dart';
import 'gluco_coach_ai_service.dart';
import 'gluco_coach_context_service.dart';
import 'subscription_entitlement_resolver.dart';
import '../models/health_metrics_models.dart';
import '../providers/user_profile_provider.dart';

// ============================================
// CLINICAL RULE ENGINE (Registry Pattern)
// ============================================

class ClinicalRule {
  final List<String> keywords;
  final String instruction;

  const ClinicalRule({required this.keywords, required this.instruction});

  bool matches(String condition) {
    final lowerCondition = condition.toLowerCase();
    return keywords.any((kw) => lowerCondition.contains(kw));
  }
}

class NutritionContextBuilder {
  // Registry for strict, non-negotiable medical overrides
  static const List<ClinicalRule> _clinicalRules = [
    ClinicalRule(
      keywords: ['diabetes'],
      instruction: 'DIABETES OVERRIDE: Clamped 1200-2400 kcal. Carbs at 28% (low-GI priority).',
    ),
    ClinicalRule(
      keywords: ['heart', 'cardiovascular'],
      instruction: 'HEART OVERRIDE: Clamped 1400-2200 kcal. Fat at 22% (unsaturated focus).',
    ),
    ClinicalRule(
      keywords: ['hypertension', 'blood pressure'],
      instruction: 'HYPERTENSION OVERRIDE: Sodium <1500mg/day. DASH-aligned meals.',
    ),
    ClinicalRule(
      keywords: ['kidney', 'renal'],
      instruction: 'KIDNEY OVERRIDE: Moderate protein. Monitor potassium and phosphorus.',
    ),
  ];

  // O(1) goal lookup instead of if/else chain
  static const Map<String, String> _goalRules = {
    'lose_weight': 'GOAL: Weight loss — 500 kcal deficit from TDEE. Prioritize protein for satiety.',
    'gain_muscle': 'GOAL: Muscle gain — 300 kcal surplus. Suggest 30-40g protein per meal.',
  };

  static String buildContext(UserProfile? userProfile) {
    if (userProfile == null) return '';

    final buffer = StringBuffer()
      ..writeln('Daily calorie target: ${userProfile.dailyCalorieTarget} kcal')
      ..writeln('Macros: Protein ${userProfile.dailyProteinTarget}g | Carbs ${userProfile.dailyCarbsTarget}g | Fat ${userProfile.dailyFatTarget}g');

    // Handle Medical Conditions via Registry + AI Catch-All
    final conditions = userProfile.diseases;
    if (conditions.isNotEmpty) {
      buffer.writeln('\n--- CLINICAL CONSTRAINTS ---');
      buffer.writeln('USER CONDITIONS: ${conditions.join(', ')}');

      // A) Apply strict hardcoded rules if they exist (deduplicated)
      final appliedRules = <String>{};
      for (final condition in conditions) {
        for (final rule in _clinicalRules) {
          if (rule.matches(condition) && appliedRules.add(rule.instruction)) {
            buffer.writeln(rule.instruction);
          }
        }
      }

      // B) AI Catch-All for ALL OTHER diseases (Celiac, Gout, Crohn's, etc.)
      buffer.writeln(
        'SYSTEM INSTRUCTION: Act as a certified clinical dietitian. For any conditions listed above '
        'that do not have a specific override, automatically adjust caloric recommendations, macronutrient '
        'distribution, and food choices strictly according to standard Medical Nutrition Therapy (MNT) guidelines.',
      );
    }

    // Handle Goals via O(1) Map lookup
    final goalRule = _goalRules[userProfile.primaryGoal];
    if (goalRule != null) {
      buffer.writeln('\n--- FITNESS GOAL ---');
      buffer.writeln(goalRule);
    }

    return buffer.toString();
  }
}

// ============================================
// INTERVENTION MODEL
// ============================================

enum InterventionUrgency { low, medium, high, critical }
enum InterventionChannel { inApp, glucoCoach, both }

class AgentIntervention {
  final String id;
  final String userId;
  final InterventionUrgency urgency;
  final InterventionChannel channel;
  final String title;
  final String message;
  final String? exerciseAction;   // e.g. "40 air squats right now"
  final String? mealAction;       // e.g. "eat a handful of almonds"
  final String? avoidAction;      // e.g. "skip the soda with lunch"
  final String trigger;           // what fired this intervention
  final DateTime createdAt;
  final bool delivered;
  final bool dismissed;

  AgentIntervention({
    required this.id,
    required this.userId,
    required this.urgency,
    required this.channel,
    required this.title,
    required this.message,
    this.exerciseAction,
    this.mealAction,
    this.avoidAction,
    required this.trigger,
    required this.createdAt,
    this.delivered = false,
    this.dismissed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'urgency': urgency.name,
    'channel': channel.name,
    'title': title,
    'message': message,
    'exerciseAction': exerciseAction,
    'mealAction': mealAction,
    'avoidAction': avoidAction,
    'trigger': trigger,
    'createdAt': Timestamp.fromDate(createdAt),
    'delivered': delivered,
    'dismissed': dismissed,
  };

  factory AgentIntervention.fromJson(Map<String, dynamic> json) {
    return AgentIntervention(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      urgency: InterventionUrgency.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => InterventionUrgency.medium,
      ),
      channel: InterventionChannel.values.firstWhere(
        (e) => e.name == json['channel'],
        orElse: () => InterventionChannel.inApp,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      exerciseAction: json['exerciseAction'],
      mealAction: json['mealAction'],
      avoidAction: json['avoidAction'],
      trigger: json['trigger'] ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      delivered: json['delivered'] ?? false,
      dismissed: json['dismissed'] ?? false,
    );
  }
}

// ============================================
// HEALTH CONTEXT SNAPSHOT (fed to LLM)
// ============================================

class _HealthContext {
  final double? currentGlucose;
  final double glucoseVelocity;       // mg/dL per minute
  final String glucoseTrend;
  final List<GlucoseReading> recentReadings;
  final Map<String, dynamic>? lastMeal;
  final Map<String, dynamic>? sleepData;
  final String? glucotype;            // Spiker / Stabilizer / Baseline
  final List<String> healthGoals;
  final List<String> conditions;
  final double? dailyCaloriesConsumed;
  final double? dailyCalorieTarget;

  _HealthContext({
    this.currentGlucose,
    this.glucoseVelocity = 0,
    this.glucoseTrend = 'stable',
    this.recentReadings = const [],
    this.lastMeal,
    this.sleepData,
    this.glucotype,
    this.healthGoals = const [],
    this.conditions = const [],
    this.dailyCaloriesConsumed,
    this.dailyCalorieTarget,
  });

  String toPromptContext() {
    final buf = StringBuffer();
    buf.writeln('=== CURRENT HEALTH SNAPSHOT ===');
    if (currentGlucose != null) {
      buf.writeln('Glucose: ${currentGlucose!.toStringAsFixed(0)} mg/dL (trend: $glucoseTrend, velocity: ${glucoseVelocity.toStringAsFixed(1)} mg/dL/min)');
    }
    if (glucotype != null) buf.writeln('Glucotype: $glucotype');
    if (conditions.isNotEmpty) buf.writeln('Conditions: ${conditions.join(", ")}');
    if (healthGoals.isNotEmpty) buf.writeln('Goals: ${healthGoals.join(", ")}');
    if (lastMeal != null) {
      buf.writeln('Last meal: ${lastMeal!['name'] ?? 'Unknown'} (${lastMeal!['calories'] ?? '?'} cal, ${lastMeal!['carbs'] ?? '?'}g carbs, ${lastMeal!['fiber'] ?? '?'}g fiber)');
    }
    if (sleepData != null) {
      buf.writeln('Last night sleep: ${sleepData!['totalHours'] ?? '?'}h (score: ${sleepData!['score'] ?? '?'}/100)');
    }
    if (dailyCaloriesConsumed != null && dailyCalorieTarget != null) {
      buf.writeln('Daily intake: ${dailyCaloriesConsumed!.toStringAsFixed(0)}/${dailyCalorieTarget!.toStringAsFixed(0)} cal');
    }
    if (recentReadings.length >= 2) {
      final recent = recentReadings.take(5).map((r) =>
          '${r.glucoseLevel.toStringAsFixed(0)} mg/dL (${r.timestamp.hour}:${r.timestamp.minute.toString().padLeft(2, '0')})');
      buf.writeln('Recent readings: ${recent.join(" → ")}');
    }
    return buf.toString();
  }
}

// ============================================
// HEALTH AGENT SERVICE — CORE ENGINE
// ============================================

class HealthAgentService {
  static final HealthAgentService _instance = HealthAgentService._internal();
  factory HealthAgentService() => _instance;
  HealthAgentService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MultiAIService _ai = MultiAIService();
  final GlucoCoachAIService _glucoCoach = GlucoCoachAIService();
  final GlucoCoachAIService _coachAi = GlucoCoachAIService();

  // Real-time Firestore listeners
  StreamSubscription<QuerySnapshot>? _glucoseListener;
  StreamSubscription<QuerySnapshot>? _mealListener;

  // Throttle: prevent intervention fatigue
  static const _interventionCooldown = Duration(minutes: 30);
  DateTime? _lastInterventionTime;
  static const _maxDailyInterventions = 8;
  int _todayInterventionCount = 0;
  DateTime _todayDate = DateTime.now();

  // Hive cache for offline agent state
  static const String _hiveBoxName = 'health_agent_state';
  Box<String>? _stateBox;

  // Callbacks for in-app UI
  final List<void Function(AgentIntervention)> _interventionListeners = [];

  void addInterventionListener(void Function(AgentIntervention) listener) {
    _interventionListeners.add(listener);
  }

  void removeInterventionListener(void Function(AgentIntervention) listener) {
    _interventionListeners.remove(listener);
  }

  // ── INITIALIZATION ──────────────────────────────────────────────

  Future<void> initialize(UserProfileProvider profileProvider) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await Hive.initFlutter();
      _stateBox = await Hive.openBox<String>(_hiveBoxName);

      // Reset daily counter on new day
      _resetDailyCounterIfNeeded();

      // Load today's intervention count from Hive
      final savedCount = _stateBox?.get('intervention_count_${_dateKey()}');
      if (savedCount != null) {
        _todayInterventionCount = int.tryParse(savedCount) ?? 0;
      }

      // Start real-time Firebase listeners
      _startGlucoseMonitor(userId, profileProvider);
      _startMealMonitor(userId, profileProvider);

      debugPrint('🤖 HealthAgent: Initialized for user $userId');
    } catch (e) {
      debugPrint('🤖 HealthAgent: Init error: $e');
    }
  }

  void dispose() {
    _glucoseListener?.cancel();
    _mealListener?.cancel();
  }

  // ── FIREBASE STREAM MONITORS ────────────────────────────────────

  /// Watches glucose_readings collection for new readings in real-time.
  void _startGlucoseMonitor(String userId, UserProfileProvider profile) {
    _glucoseListener?.cancel();
    _glucoseListener = _db
        .collection('glucose_readings')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(10) // last 10 readings for velocity + trend
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isEmpty) return;

      // Only react to NEW readings (not initial load)
      final newDocs = snapshot.docChanges.where((c) => c.type == DocumentChangeType.added);
      if (newDocs.isEmpty) return;

      final readings = snapshot.docs
          .map((doc) => GlucoseReading.fromJson(doc.data()))
          .toList();

      if (readings.isNotEmpty) {
        _evaluateGlucoseState(readings, profile);
      }
    }, onError: (e) {
      debugPrint('🤖 HealthAgent: Glucose stream error: $e');
    });
  }

  /// Watches meal logs for new meals — predicts glucose impact pre-emptively.
  void _startMealMonitor(String userId, UserProfileProvider profile) {
    _mealListener?.cancel();
    _mealListener = _db
        .collection('users')
        .doc(userId)
        .collection('meal_logs')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isEmpty) return;
      final newDocs = snapshot.docChanges.where((c) => c.type == DocumentChangeType.added);
      if (newDocs.isEmpty) return;

      final mealData = snapshot.docs.first.data();
      _evaluateMealImpact(mealData, profile);
    }, onError: (e) {
      debugPrint('🤖 HealthAgent: Meal stream error: $e');
    });
  }

  // ── DECISION TREES ──────────────────────────────────────────────

  /// Evaluates glucose state and triggers interventions if needed.
  Future<void> _evaluateGlucoseState(
    List<GlucoseReading> readings,
    UserProfileProvider profile,
  ) async {
    final latest = readings.first;
    final level = latest.glucoseLevel;

    // Calculate velocity from last 2 readings
    double velocity = 0;
    if (readings.length >= 2) {
      final prev = readings[1];
      final timeDiff = latest.timestamp.difference(prev.timestamp).inMinutes;
      if (timeDiff > 0) {
        velocity = (level - prev.glucoseLevel) / timeDiff;
      }
    }

    // Determine trend
    String trend = 'stable';
    if (velocity > 1.5) trend = 'rising_fast';
    else if (velocity > 0.5) trend = 'rising';
    else if (velocity < -1.5) trend = 'falling_fast';
    else if (velocity < -0.5) trend = 'falling';

    // ── DECISION TREE: LOCAL RULES (no LLM needed for clear-cut cases) ──

    // CRITICAL: Hypoglycemia (<70)
    if (level < 70) {
      await _fireIntervention(
        profile: profile,
        urgency: InterventionUrgency.critical,
        trigger: 'hypoglycemia',
        title: '⚠️ Low Glucose Alert',
        message: 'Your glucose is ${level.toStringAsFixed(0)} mg/dL. '
            'Eat 15g fast-acting carbs now: 4 glucose tablets, ½ cup juice, or 1 tbsp honey. '
            'Recheck in 15 minutes.',
        mealAction: '15g fast-acting carbs immediately (juice, glucose tabs, or honey)',
      );
      return;
    }

    // SPIKE IN PROGRESS (>180 and still rising)
    if (level > 180 && velocity > 0.5) {
      await _generateAndFireLLMIntervention(
        profile: profile,
        readings: readings,
        triggerType: 'active_spike',
        urgency: InterventionUrgency.high,
      );
      return;
    }

    // IMPENDING SPIKE (120-180 and rising fast)
    if (level > 120 && level <= 180 && velocity > 1.2) {
      await _generateAndFireLLMIntervention(
        profile: profile,
        readings: readings,
        triggerType: 'impending_spike',
        urgency: InterventionUrgency.high,
      );
      return;
    }

    // RAPID DROP (falling fast, not yet hypo)
    if (velocity < -1.5 && level < 110) {
      await _generateAndFireLLMIntervention(
        profile: profile,
        readings: readings,
        triggerType: 'rapid_drop',
        urgency: InterventionUrgency.medium,
      );
      return;
    }

    // POST-MEAL ELEVATED (>140, 1-2h after meal)
    if (level > 140 && velocity.abs() < 0.5) {
      // Only intervene if we haven't recently
      if (_canIntervene()) {
        await _generateAndFireLLMIntervention(
          profile: profile,
          readings: readings,
          triggerType: 'post_meal_elevated',
          urgency: InterventionUrgency.medium,
        );
      }
    }
  }

  /// Pre-emptive meal impact evaluation — fires BEFORE the spike happens.
  Future<void> _evaluateMealImpact(
    Map<String, dynamic> mealData,
    UserProfileProvider profile,
  ) async {
    final carbs = (mealData['carbs'] ?? mealData['carbs_g'] ?? 0).toDouble();
    final fiber = (mealData['fiber'] ?? mealData['fiber_g'] ?? 0).toDouble();
    final gi = (mealData['glycemicIndex'] ?? mealData['gi'] ?? 55).toInt();

    // Glycemic load = (GI × available carbs) / 100
    final availableCarbs = (carbs - fiber).clamp(0, double.infinity);
    final glycemicLoad = (gi * availableCarbs) / 100;

    // Only intervene for high-GL meals (GL > 20 is high)
    if (glycemicLoad > 20) {
      final userProfile = profile.userProfile;
      final ctx = _HealthContext(
        lastMeal: mealData,
        glucotype: userProfile?.glucotype,
        healthGoals: userProfile?.healthGoals ?? [],
        conditions: userProfile?.diseases ?? [],
      );

      await _fireLLMIntervention(
        profile: profile,
        context: ctx,
        triggerType: 'high_gl_meal',
        urgency: InterventionUrgency.medium,
      );
    }
  }

  // ── LLM-POWERED INTERVENTION GENERATOR ──────────────────────────

  /// Builds a health context, queries Gemini for the minimum-effective-dose
  /// intervention, and dispatches it.
  Future<void> _generateAndFireLLMIntervention({
    required UserProfileProvider profile,
    required List<GlucoseReading> readings,
    required String triggerType,
    required InterventionUrgency urgency,
  }) async {
    if (!_canIntervene()) return;

    final userProfile = profile.userProfile;
    final latest = readings.first;

    double velocity = 0;
    if (readings.length >= 2) {
      final prev = readings[1];
      final timeDiff = latest.timestamp.difference(prev.timestamp).inMinutes;
      if (timeDiff > 0) velocity = (latest.glucoseLevel - prev.glucoseLevel) / timeDiff;
    }

    final ctx = _HealthContext(
      currentGlucose: latest.glucoseLevel,
      glucoseVelocity: velocity,
      glucoseTrend: latest.trend.name,
      recentReadings: readings,
      glucotype: userProfile?.glucotype,
      healthGoals: userProfile?.healthGoals ?? [],
      conditions: userProfile?.diseases ?? [],
      dailyCalorieTarget: userProfile?.dailyCalorieTarget?.toDouble(),
    );

    await _fireLLMIntervention(
      profile: profile,
      context: ctx,
      triggerType: triggerType,
      urgency: urgency,
    );
  }

  Future<void> _fireLLMIntervention({
    required UserProfileProvider profile,
    required _HealthContext context,
    required String triggerType,
    required InterventionUrgency urgency,
  }) async {
    if (!_canIntervene()) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final sub = await SubscriptionEntitlementResolver.instance.getSubscription(userId);
    if (sub == null || sub.isFree) {
      debugPrint('🤖 HealthAgent: LLM intervention skipped — paid tier required');
      return;
    }

    try {
      final prompt = '''
You are a concise health coach AI for the Wellor app. The user needs an immediate, actionable micro-intervention.

TRIGGER: $triggerType
${context.toPromptContext()}

RULES:
1. Be EXTREMELY brief (2-3 sentences max for the message)
2. Give the MINIMUM EFFECTIVE DOSE — the smallest action that makes the biggest difference
3. Be specific: exact exercise reps, exact food portions, exact times
4. Never say "consult your doctor" — that's not actionable right now
5. Sound like a supportive friend, not a medical textbook
6. If glucose is spiking: suggest a specific physical movement (air squats, walking, etc.)
7. If poor sleep detected: reduce workout intensity automatically
8. Match advice to their conditions and goals

Return ONLY valid JSON:
{
  "title": "Short attention-grabbing title (5 words max)",
  "message": "The 2-3 sentence intervention message",
  "exerciseAction": "Specific exercise with reps/duration or null",
  "mealAction": "Specific food to eat with portion or null",
  "avoidAction": "Specific thing to avoid right now or null"
}''';

      final response = await _ai.executeStructuredTask(
        prompt: prompt,
        temperature: 0.3,
        maxTokens: 512,
      );

      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final intervention = AgentIntervention(
        id: _db.collection('agent_interventions').doc().id,
        userId: userId,
        urgency: urgency,
        channel: urgency == InterventionUrgency.critical ||
                urgency == InterventionUrgency.high
            ? InterventionChannel.both
            : InterventionChannel.inApp,
        title: response['title'] ?? 'Health Alert',
        message: response['message'] ?? '',
        exerciseAction: response['exerciseAction'],
        mealAction: response['mealAction'],
        avoidAction: response['avoidAction'],
        trigger: triggerType,
        createdAt: DateTime.now(),
      );

      await _dispatchIntervention(intervention);
    } catch (e) {
      debugPrint('🤖 HealthAgent: LLM intervention error: $e');
    }
  }

  // ── INTERVENTION DISPATCH ───────────────────────────────────────

  Future<void> _fireIntervention({
    required UserProfileProvider profile,
    required InterventionUrgency urgency,
    required String trigger,
    required String title,
    required String message,
    String? exerciseAction,
    String? mealAction,
    String? avoidAction,
  }) async {
    if (!_canIntervene()) return;

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final intervention = AgentIntervention(
      id: _db.collection('agent_interventions').doc().id,
      userId: userId,
      urgency: urgency,
      channel: urgency == InterventionUrgency.critical
          ? InterventionChannel.both
          : InterventionChannel.inApp,
      title: title,
      message: message,
      exerciseAction: exerciseAction,
      mealAction: mealAction,
      avoidAction: avoidAction,
      trigger: trigger,
      createdAt: DateTime.now(),
    );

    await _dispatchIntervention(intervention);
  }

  Future<void> _dispatchIntervention(AgentIntervention intervention) async {
    // 1. Save to Firestore (audit trail + Cloud Function trigger)
    try {
      await _db
          .collection('agent_interventions')
          .doc(intervention.id)
          .set(intervention.toJson());
    } catch (e) {
      debugPrint('🤖 HealthAgent: Firestore save error: $e');
    }

    // 2. Cache locally in Hive
    try {
      _stateBox?.put(
        'last_intervention',
        jsonEncode(intervention.toJson()..['createdAt'] = intervention.createdAt.toIso8601String()),
      );
    } catch (_) {}

    // 3. Notify in-app listeners
    for (final listener in _interventionListeners) {
      listener(intervention);
    }

    // 4. Send GlucoCoach if channel requires it
    if (intervention.channel == InterventionChannel.glucoCoach ||
        intervention.channel == InterventionChannel.both) {
      await _sendGlucoCoachIntervention(intervention);
    }

    // 5. Update throttle counter
    _lastInterventionTime = DateTime.now();
    _todayInterventionCount++;
    _stateBox?.put('intervention_count_${_dateKey()}',
        _todayInterventionCount.toString());

    debugPrint(
      '🤖 HealthAgent: Dispatched [${intervention.urgency.name}] '
      '"${intervention.title}" via ${intervention.channel.name}',
    );
  }

  Future<void> _sendGlucoCoachIntervention(AgentIntervention intervention) async {
    try {
      // Fetch user's GlucoCoach number from Firestore
      final userId = intervention.userId;
      if (userId.isEmpty) return;

      final userDoc = await _db.collection('users').doc(userId).get();
      final phone = userDoc.data()?['glucoCoachNumber'] as String?;
      if (phone == null || phone.isEmpty) return;

      final body = StringBuffer();
      body.writeln('🤖 *Wellor Health Agent*');
      body.writeln('');
      body.writeln('*${intervention.title}*');
      body.writeln(intervention.message);
      if (intervention.exerciseAction != null) {
        body.writeln('');
        body.writeln('🏃 *Do now:* ${intervention.exerciseAction}');
      }
      if (intervention.mealAction != null) {
        body.writeln('🍎 *Eat:* ${intervention.mealAction}');
      }
      if (intervention.avoidAction != null) {
        body.writeln('🚫 *Avoid:* ${intervention.avoidAction}');
      }

      await _glucoCoach.sendProactiveMessage(
        userId: userId,
        message: body.toString(),
      );
    } catch (e) {
      debugPrint('🤖 HealthAgent: GlucoCoach send error: $e');
    }
  }

  // ── CONVERSATIONAL AGENT (GlucoCoach 2-way chat) ──────────────────

  /// Process an incoming GlucoCoach message from a user and generate a
  /// contextual health coaching response.
  Future<String> handleIncomingMessage({
    required String userId,
    required String message,
  }) async {
    final coachCtx = await GlucoCoachContextService().buildForUser(userId);
    final healthBlock = coachCtx.toPromptBlock();

    final prompt = '''
You are the Wellor Health Agent chatting with a user on GlucoCoach. Be warm, concise, and actionable.

$healthBlock

USER MESSAGE: "$message"

RULES:
- Keep response under 200 words
- ALWAYS reference their current glucose, conditions, goals, and medications when relevant
- Be specific with portions, reps, durations
- If they ask about food: consider their glucose trend and conditions
- If they ask about exercise: match to their current metabolic state
- If glucose data is missing, coach from profile and ask them to log or sync CGM
- Use emojis sparingly (1-2 max)
- Never say "consult your doctor" unless it's genuinely urgent
- Sound like a knowledgeable friend, not a bot

Respond in plain text (not JSON).''';

    try {
      final response = await _coachAi.generateReply(
        userPrompt: prompt,
        temperature: 0.7,
        maxTokens: 512,
      );
      return response;
    } catch (e) {
      return "I'm having trouble connecting right now. Your health data is safe — I'll check back shortly! 💚";
    }
  }

  // ── SCHEDULED HEALTH CHECK-IN ───────────────────────────────────

  /// Runs a comprehensive daily health evaluation and sends a summary.
  /// Called by Firebase Cloud Function on schedule or manually from app.
  Future<void> runDailyCheckIn(UserProfileProvider profile) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userProfile = profile.userProfile;
    final coachCtx = await GlucoCoachContextService().buildForUser(userId);
    final healthBlock = coachCtx.toPromptBlock();
    final tir = coachCtx.timeInRangePercent24h ?? 0;
    final readingsCount = coachCtx.readingsCount24h;

    // Build condition-specific nutrition context via Registry Pattern + AI Catch-All
    final nutritionContext = NutritionContextBuilder.buildContext(userProfile);

    final prompt = '''
You are the Wellor daily health coach. Generate a brief morning check-in for GlucoCoach.

$healthBlock
$nutritionContext

RULES:
- 4-6 short lines max
- Start with a greeting based on their TIR (${tir}% from $readingsCount readings — good if >70%, needs work if <50%)
- Factor in current glucose (${coachCtx.currentGlucoseMgDl?.toStringAsFixed(0) ?? 'no recent reading'} mg/dL, trend: ${coachCtx.trend})
- State their daily calorie target and briefly explain WHY (e.g. "Your target is 1800 kcal — adjusted for diabetes management")
- Give ONE specific meal suggestion tailored to their conditions (e.g. low-GI for diabetes, low-sodium for hypertension)
- Give ONE specific exercise suggestion for today
- If they had spikes yesterday, mention what to change
- End with encouragement
- Use 1-2 emojis
- Never say "consult your doctor" — keep it actionable

Respond as plain text GlucoCoach message (not JSON).''';

    try {
      final response = await _coachAi.generateReply(
        userPrompt: prompt,
        temperature: 0.7,
        maxTokens: 300,
      );

      // Send via GlucoCoach
      final userDoc = await _db.collection('users').doc(userId).get();
      final phone = userDoc.data()?['glucoCoachNumber'] as String?;
      if (phone != null && phone.isNotEmpty) {
        await _glucoCoach.sendProactiveMessage(
      userId: userId,
      message: response,
    );
      }

      // Also save as intervention for in-app display
      final intervention = AgentIntervention(
        id: _db.collection('agent_interventions').doc().id,
        userId: userId,
        urgency: InterventionUrgency.low,
        channel: InterventionChannel.both,
        title: '☀️ Daily Check-in',
        message: response,
        trigger: 'daily_checkin',
        createdAt: DateTime.now(),
        delivered: true,
      );
      await _db
          .collection('agent_interventions')
          .doc(intervention.id)
          .set(intervention.toJson());
    } catch (e) {
      debugPrint('🤖 HealthAgent: Daily check-in error: $e');
    }
  }

  // ── UTILITY ─────────────────────────────────────────────────────

  bool _canIntervene() {
    _resetDailyCounterIfNeeded();

    // Max daily cap to prevent fatigue
    if (_todayInterventionCount >= _maxDailyInterventions) {
      debugPrint('🤖 HealthAgent: Daily intervention cap reached');
      return false;
    }

    // Cooldown between interventions
    if (_lastInterventionTime != null &&
        DateTime.now().difference(_lastInterventionTime!) < _interventionCooldown) {
      debugPrint('🤖 HealthAgent: Cooldown active');
      return false;
    }

    return true;
  }

  void _resetDailyCounterIfNeeded() {
    final now = DateTime.now();
    if (now.day != _todayDate.day ||
        now.month != _todayDate.month ||
        now.year != _todayDate.year) {
      _todayInterventionCount = 0;
      _todayDate = now;
    }
  }

  String _dateKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Get intervention history for display in-app.
  Future<List<AgentIntervention>> getInterventionHistory({int limit = 20}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _db
          .collection('agent_interventions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AgentIntervention.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('🤖 HealthAgent: History fetch error: $e');
      return [];
    }
  }

  /// Dismiss an intervention (user acknowledged it).
  Future<void> dismissIntervention(String interventionId) async {
    try {
      await _db
          .collection('agent_interventions')
          .doc(interventionId)
          .update({'dismissed': true});
    } catch (e) {
      debugPrint('🤖 HealthAgent: Dismiss error: $e');
    }
  }
}
