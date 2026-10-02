import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_profile.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gluco_coach_ai_service.dart';

/// ============================================================================
/// Wellor Hierarchical Multi-Agent System (MAS)
/// ============================================================================
/// 
/// Architecture:
/// ┌─────────────────────────────────────────────────────────────────────────┐
/// │                    CHIEF HEALTH OFFICER (Supervisor)                    │
/// │                         Gemini 1.5 Pro                                  │
/// │    • Holds master UserHealthProfile via Context Caching                 │
/// │    • Routes events to appropriate mini-agents                           │
/// │    • Resolves conflicts between competing recommendations               │
/// └─────────────────────────────────────────────────────────────────────────┘
///                                    │
///         ┌──────────────┬───────────┼───────────┬──────────────┐
///         ▼              ▼           ▼           ▼              ▼
/// ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
/// │ Sleep Agent │ │ Hydration   │ │ Exercise    │ │ Snack Agent │
/// │   (Flash)   │ │   Agent     │ │   Agent     │ │   (Flash)   │
/// │             │ │   (Flash)   │ │   (Flash)   │ │             │
/// │ Scheduled   │ │ Scheduled   │ │ Event-Driven│ │ Event-Driven│
/// │ 7:00 AM     │ │ Hourly      │ │ Glucose/Meal│ │ Glucose Drop│
/// └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
/// ============================================================================

/// Shared mutable state that all agents read from and write to
class AgentState {
  final String odId;
  final HealthProfile healthProfile;
  
  // Real-time biometric data
  double? currentGlucose;
  double? lastGlucose;
  DateTime? glucoseTimestamp;
  double? heartRate;
  double? restingHeartRate;
  double? heartRateVariability; // HRV SDNN (ms)
  int? stepsToday;
  double? sleepHours;
  int? sleepQualityScore; // 0-100
  double? hydrationLiters;
  double? caloriesBurnedToday;
  double? caloriesConsumedToday;
  double? bloodOxygen; // SpO2 percentage
  double? bodyTemperature; // °C
  double? bloodPressureSystolic;
  double? bloodPressureDiastolic;
  int? workoutMinutesToday;
  
  // Trend data for smarter agent decisions
  List<Map<String, dynamic>> glucoseHistory = [];
  List<Map<String, dynamic>> heartRateHistory = [];
  
  // Agent recommendations (pending resolution)
  final List<AgentRecommendation> pendingRecommendations = [];
  
  // Resolved actions to execute
  final List<ResolvedAction> resolvedActions = [];
  
  // Conflict flags
  bool hasConflict = false;
  String? conflictDescription;
  
  // Timestamps
  DateTime lastSleepAnalysis = DateTime.now().subtract(const Duration(days: 1));
  DateTime lastHydrationCheck = DateTime.now().subtract(const Duration(hours: 2));
  DateTime lastExerciseRecommendation = DateTime.now().subtract(const Duration(hours: 4));
  DateTime lastSnackRecommendation = DateTime.now().subtract(const Duration(hours: 2));
  
  // Device connection status
  bool glucoseMonitorConnected = false;
  bool wearableConnected = false;
  String? connectedDeviceName;
  
  // GlucoCoach number for direct alerting
  String? glucoCoachNumber;
  
  AgentState({
    required this.odId,
    required this.healthProfile,
    this.currentGlucose,
    this.heartRate,
    this.restingHeartRate,
    this.heartRateVariability,
    this.stepsToday,
    this.sleepHours,
    this.sleepQualityScore,
    this.hydrationLiters,
    this.caloriesBurnedToday,
    this.caloriesConsumedToday,
    this.bloodOxygen,
    this.bodyTemperature,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.workoutMinutesToday,
    this.glucoseMonitorConnected = false,
    this.wearableConnected = false,
    this.glucoCoachNumber,
    List<Map<String, dynamic>>? glucoseHistory,
    List<Map<String, dynamic>>? heartRateHistory,
  })  : glucoseHistory = glucoseHistory ?? [],
        heartRateHistory = heartRateHistory ?? [];
  
  /// Create state from Firestore snapshot
  factory AgentState.fromFirestore(
    DocumentSnapshot doc,
    HealthProfile profile,
  ) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AgentState(
      odId: doc.id,
      healthProfile: profile,
      currentGlucose: (data['currentGlucose'] as num?)?.toDouble() ?? (data['glucose'] as num?)?.toDouble(),
      heartRate: (data['heartRate'] as num?)?.toDouble(),
      restingHeartRate: (data['restingHeartRate'] as num?)?.toDouble(),
      heartRateVariability: (data['heartRateVariability'] as num?)?.toDouble(),
      stepsToday: data['stepsToday'] as int?,
      sleepHours: (data['sleepHours'] as num?)?.toDouble(),
      sleepQualityScore: data['sleepQualityScore'] as int? ?? data['sleepQuality'] as int?,
      hydrationLiters: (data['hydrationLiters'] as num?)?.toDouble(),
      caloriesBurnedToday: (data['caloriesBurnedToday'] as num?)?.toDouble() ?? (data['caloriesBurned'] as num?)?.toDouble(),
      caloriesConsumedToday: (data['caloriesConsumedToday'] as num?)?.toDouble() ?? (data['caloriesConsumed'] as num?)?.toDouble(),
      bloodOxygen: (data['bloodOxygen'] as num?)?.toDouble(),
      bodyTemperature: (data['bodyTemperature'] as num?)?.toDouble(),
      bloodPressureSystolic: (data['bloodPressureSystolic'] as num?)?.toDouble(),
      bloodPressureDiastolic: (data['bloodPressureDiastolic'] as num?)?.toDouble(),
      workoutMinutesToday: data['workoutMinutesToday'] as int?,
      glucoseMonitorConnected: data['glucoseMonitorConnected'] ?? false,
      wearableConnected: data['wearableConnected'] ?? false,
      glucoseHistory: List<Map<String, dynamic>>.from(data['glucoseHistory'] ?? []),
      heartRateHistory: List<Map<String, dynamic>>.from(data['heartRateHistory'] ?? []),
    );
  }
  
  /// Serialize state for Gemini context
  Map<String, dynamic> toContextMap() {
    return {
      'userId': odId,
      'healthProfile': {
        'conditions': healthProfile.medicalConditions,
        'allergies': healthProfile.allergies,
        'dietaryRestrictions': healthProfile.dietaryRestrictions,
        'medications': healthProfile.medications,
        'age': healthProfile.age,
        'weight': healthProfile.weight,
        'height': healthProfile.height,
        'activityLevel': healthProfile.activityLevel,
        'healthGoals': healthProfile.healthGoals,
      },
      'currentBiometrics': {
        'glucose': currentGlucose,
        'lastGlucose': lastGlucose,
        'glucoseTimestamp': glucoseTimestamp?.toIso8601String(),
        'heartRate': heartRate,
        'restingHeartRate': restingHeartRate,
        'heartRateVariability': heartRateVariability,
        'stepsToday': stepsToday,
        'sleepHours': sleepHours,
        'sleepQuality': sleepQualityScore,
        'hydrationLiters': hydrationLiters,
        'caloriesBurned': caloriesBurnedToday,
        'caloriesConsumed': caloriesConsumedToday,
        'bloodOxygen': bloodOxygen,
        'bodyTemperature': bodyTemperature,
        'bloodPressureSystolic': bloodPressureSystolic,
        'bloodPressureDiastolic': bloodPressureDiastolic,
        'workoutMinutesToday': workoutMinutesToday,
      },
      'trends': {
        'glucoseHistory': glucoseHistory.take(10).toList(),
        'heartRateHistory': heartRateHistory.take(10).toList(),
      },
      'deviceStatus': {
        'glucoseMonitor': glucoseMonitorConnected,
        'wearable': wearableConnected,
        'deviceName': connectedDeviceName,
      },
      'pendingRecommendations': pendingRecommendations.map((r) => r.toMap()).toList(),
    };
  }
  
  /// Update state from agent output
  void updateFromAgent(String agentName, Map<String, dynamic> updates) {
    if (updates.containsKey('caloriesBurnedEstimate')) {
      caloriesBurnedToday = (caloriesBurnedToday ?? 0) + 
          (updates['caloriesBurnedEstimate'] as num).toDouble();
    }
    if (updates.containsKey('hydrationTarget')) {
      // Hydration agent updated target
    }
    if (updates.containsKey('sleepScore')) {
      sleepQualityScore = updates['sleepScore'] as int;
    }
  }
}

/// Represents a recommendation from a mini-agent
class AgentRecommendation {
  final String agentName;
  final String category; // 'nutrition', 'exercise', 'hydration', 'rest'
  final String recommendation;
  final int priority; // 1-10, higher = more urgent
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final bool requiresConflictCheck;
  
  AgentRecommendation({
    required this.agentName,
    required this.category,
    required this.recommendation,
    required this.priority,
    this.metadata = const {},
    DateTime? timestamp,
    this.requiresConflictCheck = false,
  }) : timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toMap() => {
    'agent': agentName,
    'category': category,
    'recommendation': recommendation,
    'priority': priority,
    'metadata': metadata,
    'timestamp': timestamp.toIso8601String(),
    'requiresConflictCheck': requiresConflictCheck,
  };
}

/// Represents a resolved action ready for execution
class ResolvedAction {
  final String type; // 'glucocoach_message', 'notification', 'ui_update'
  final String message;
  final int priority;
  final Map<String, dynamic> payload;
  final String resolvedBy; // 'supervisor' or agent name if no conflict
  
  ResolvedAction({
    required this.type,
    required this.message,
    required this.priority,
    this.payload = const {},
    required this.resolvedBy,
  });
}

/// Event types that trigger agent processing
enum AgentTriggerType {
  glucoseReading,    // Event-driven: New glucose data
  mealLogged,        // Event-driven: User logged a meal
  workoutCompleted,  // Event-driven: Exercise session ended
  sleepSync,         // Scheduled: Morning sleep data sync
  hydrationCheck,    // Scheduled: Hourly hydration reminder
  dailyPlanning,     // Scheduled: Morning planning session
  eveningReview,     // Scheduled: End of day summary
  manualRequest,     // User explicitly asked for advice
}

/// ============================================================================
/// CHIEF HEALTH OFFICER (Supervisor Agent)
/// ============================================================================
/// 
/// Powered by Gemini 1.5 Pro with Context Caching
/// Responsibilities:
/// 1. Hold the master UserHealthProfile in system prompt
/// 2. Route incoming events to appropriate mini-agents
/// 3. Resolve conflicts between competing recommendations
/// 4. Synthesize final safe instructions for the user
/// ============================================================================
class ChiefHealthOfficer {
  late final GenerativeModel _proModel;
  final FirebaseFirestore _firestore;
  
  // Mini-agents
  late final SleepAgent _sleepAgent;
  late final HydrationAgent _hydrationAgent;
  late final ExerciseAgent _exerciseAgent;
  late final SnackAgent _snackAgent;
  
  ChiefHealthOfficer({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    
    // Supervisor uses Gemini 3.0 Flash for advanced reasoning
    _proModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        topP: 0.8,
        maxOutputTokens: 2048,
      ),
    );
    
    // Initialize mini-agents (all use Flash for speed)
    _sleepAgent = SleepAgent(apiKey: apiKey);
    _hydrationAgent = HydrationAgent(apiKey: apiKey);
    _exerciseAgent = ExerciseAgent(apiKey: apiKey);
    _snackAgent = SnackAgent(apiKey: apiKey);
  }
  
  /// Initialize context caching with user's health profile
  Future<void> initializeContext(AgentState state) async {
    // ignore: unused_local_variable
    final systemContext = '''
You are the Chief Health Officer AI for Wellor, overseeing a team of specialized health agents.
You have complete knowledge of the patient's medical history and current state.

=== PATIENT PROFILE ===
${jsonEncode(state.toContextMap())}

=== YOUR RESPONSIBILITIES ===
1. ROUTE incoming health events to the appropriate specialist agent(s)
2. MONITOR all agent recommendations for potential conflicts
3. RESOLVE conflicts by weighing medical priorities against the patient's specific conditions
4. SYNTHESIZE safe, actionable instructions that account for ALL health constraints
5. DETECT health anomalies based on the patient's specific conditions and goals
6. TRIGGER GlucoCoach alerts for urgent or time-sensitive findings

=== HEALTH GOAL MONITORING ===
The patient's health goals are: ${state.healthProfile.healthGoals.join(', ')}
For each goal, you must track relevant metrics:
- Weight Management: Track calories in/out balance, activity levels, glucose stability
- Blood Sugar Stability: Monitor glucose trends, time-in-range, spikes and crashes
- Cardiovascular Health: Track heart rate, blood pressure, HRV, SpO2, exercise
- Sleep Quality: Monitor sleep hours, sleep efficiency, resting HR trends
- Muscle Building: Track protein intake timing, workout recovery, rest days
- Energy Optimization: Monitor sleep quality, glucose stability, hydration

=== CONDITION-SPECIFIC ALERTS ===
${state.healthProfile.medicalConditions.isNotEmpty ? 'ACTIVE CONDITIONS requiring monitoring:' : 'No known conditions.'}
${state.healthProfile.medicalConditions.map((c) => '- $c').join('\n')}

Alert thresholds (GlucoCoach message required):
- Glucose > 180 mg/dL or < 70 mg/dL (URGENT for diabetic patients)
- Heart rate > 120 bpm at rest or < 50 bpm
- Blood oxygen < 92% (URGENT)
- Blood pressure systolic > 140 or diastolic > 90 (hypertension alert)
- Blood pressure systolic < 90 (hypotension alert)
- Sleep < 5 hours (recovery alert for next day)
- Body temperature > 38°C (fever alert)
- HRV drop > 30% from baseline (stress/overtraining alert)

=== CONFLICT RESOLUTION PROTOCOL ===
When agents disagree, always prioritize:
1. SAFETY: Never recommend anything that could harm the patient given their conditions
2. MEDICATION INTERACTIONS: Consider current medications and their effects
3. CONDITION-SPECIFIC NEEDS: Account for chronic conditions (diabetes, heart disease, etc.)
4. ENERGY BALANCE: Consider overall metabolic needs vs current state

=== OUTPUT FORMAT ===
Always respond with valid JSON in this structure:
{
  "decision": "route|resolve|alert",
  "targetAgents": ["sleep", "hydration", "exercise", "snack"],
  "resolvedMessage": "Final synthesized recommendation for user",
  "priority": 1-10,
  "alertLevel": "info|warning|urgent|emergency",
  "reasoning": "Brief explanation of your decision"
}
''';
    
    // In production, use actual context caching API
    // For now, we'll use the system instruction approach
    debugPrint('[CHO] Context initialized for user: ${state.odId}');
  }
  
  /// Main entry point: Process an incoming health event
  Future<List<ResolvedAction>> processEvent({
    required AgentTriggerType trigger,
    required AgentState state,
    Map<String, dynamic>? eventData,
  }) async {
    debugPrint('[CHO] Processing event: $trigger');
    
    // Step 0: Check vitals for immediate alerts (runs before agents)
    final vitalAlerts = await _checkVitalsThresholds(state);
    
    // Step 1: Route event to appropriate mini-agents
    final agentsToInvoke = _routeEvent(trigger, state);
    
    // Step 2: Collect recommendations from each invoked agent
    final recommendations = <AgentRecommendation>[];
    
    for (final agentName in agentsToInvoke) {
      final recommendation = await _invokeAgent(agentName, state, eventData);
      if (recommendation != null) {
        recommendations.add(recommendation);
        state.pendingRecommendations.add(recommendation);
      }
    }
    
    // Step 3: Check for conflicts
    final conflicts = _detectConflicts(recommendations);
    
    // Step 4: Resolve conflicts or pass through
    List<ResolvedAction> actions;
    if (conflicts.isNotEmpty) {
      state.hasConflict = true;
      state.conflictDescription = conflicts.map((c) => c['description']).join('; ');
      actions = await _resolveConflicts(state, conflicts);
    } else {
      // No conflicts - convert recommendations directly to actions
      actions = recommendations.map((r) => ResolvedAction(
        type: r.priority >= 7 ? 'glucocoach_message' : 'notification',
        message: r.recommendation,
        priority: r.priority,
        payload: r.metadata,
        resolvedBy: r.agentName,
      )).toList();
    }
    
    // Step 5: Prepend vital alerts (highest priority)
    actions = [...vitalAlerts, ...actions];
    
    // Step 6: Send GlucoCoach for urgent actions
    await _sendGlucoCoachAlerts(state, actions);
    
    // Step 7: Update state with resolved actions
    state.resolvedActions.addAll(actions);
    state.pendingRecommendations.clear();
    state.hasConflict = false;
    
    return actions;
  }
  
  /// Calls Gemini to generate a personalized intervention and corrective meal
  /// when a vital threshold is breached. This replaces hardcoded alert templates
  /// with dynamic, context-aware advice including specific meal recommendations.
  Future<ResolvedAction?> _generateDynamicIntervention(
    AgentState state,
    String vitalName,
    String vitalValue,
    String alertType,
  ) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final conditions = state.healthProfile.medicalConditions.join(', ');
    final allergies = state.healthProfile.allergies.join(', ');
    final restrictions = state.healthProfile.dietaryRestrictions.join(', ');
    final medications = state.healthProfile.medications.join(', ');
    final goals = state.healthProfile.healthGoals.join(', ');

    final prompt = '''
You are the Chief Health Officer AI for Wellor. A patient has triggered a vital anomaly.

Patient Profile:
- Medical Conditions: $conditions
- Allergies: $allergies
- Dietary Restrictions: $restrictions
- Medications: $medications
- Health Goals: $goals
- Age: ${state.healthProfile.age ?? 'unknown'}
- Weight: ${state.healthProfile.weight ?? 'unknown'}kg

Triggering Vital: $vitalName is at $vitalValue.

Current Context:
- Heart Rate: ${state.heartRate ?? 'unknown'} bpm
- Blood Glucose: ${state.currentGlucose ?? 'unknown'} mg/dL
- Blood Oxygen: ${state.bloodOxygen ?? 'unknown'}%
- Blood Pressure: ${state.bloodPressureSystolic ?? 'unknown'}/${state.bloodPressureDiastolic ?? 'unknown'} mmHg
- Body Temperature: ${state.bodyTemperature ?? 'unknown'}°C
- Hydration: ${state.hydrationLiters ?? 'unknown'}L today
- Steps: ${state.stepsToday ?? 0}
- Sleep: ${state.sleepHours ?? 'unknown'}h

Task:
1. Draft an urgent, empathetic, and actionable GlucoCoach message advising the patient on immediate steps.
2. Recommend a specific, fast-acting snack or meal to help stabilize this specific condition immediately (e.g., if low glucose, fast carbs; if high BP, low sodium/potassium rich).
3. STRICTLY avoid any allergens listed above.
4. Respect dietary restrictions (vegan, halal, kosher, gluten-free, etc.).
5. Consider medication interactions.

Return ONLY valid JSON in this exact structure:
{
  "message": "The full GlucoCoach message text, including the meal recommendation.",
  "meal_name": "Name of the corrective meal/snack",
  "ingredients": ["item 1", "item 2"],
  "priority": 9
}
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final data = jsonDecode(response.text!) as Map<String, dynamic>;

      return ResolvedAction(
        type: 'glucocoach_message',
        message: data['message'] as String? ?? 'Health alert: Please check your $vitalName.',
        priority: (data['priority'] as num?)?.toInt() ?? 8,
        resolvedBy: 'supervisor_vitals_gemini',
        payload: {
          'alertType': alertType,
          'vitalTrigger': vitalName,
          'vitalValue': vitalValue,
          'recommendedMeal': data['meal_name'],
          'ingredients': data['ingredients'],
        },
      );
    } catch (e) {
      debugPrint('[CHO] Failed to generate dynamic intervention for $alertType: $e');
      return null;
    }
  }

  /// Check vitals against medical thresholds and generate dynamic Gemini alerts.
  /// Uses a hybrid approach: local threshold math runs instantly, and only when
  /// a threshold is breached does it call Gemini for personalized intervention
  /// with a corrective meal recommendation.
  Future<List<ResolvedAction>> _checkVitalsThresholds(AgentState state) async {
    final alerts = <ResolvedAction>[];
    final anomalyFutures = <Future<ResolvedAction?>>[];

    final conditions = state.healthProfile.medicalConditions.map((c) => c.toLowerCase()).toList();
    final isDiabetic = conditions.any((c) => c.contains('diabetes'));

    // 1. Glucose Check
    final glucose = state.currentGlucose;
    if (glucose != null) {
      final highThreshold = isDiabetic ? 180.0 : 200.0;
      final lowThreshold = isDiabetic ? 70.0 : 60.0;

      if (glucose < lowThreshold) {
        anomalyFutures.add(_generateDynamicIntervention(
          state, 'Blood Glucose',
          '${glucose.toStringAsFixed(0)} mg/dL (Critically Low)', 'hypoglycemia',
        ));
      } else if (glucose > highThreshold) {
        anomalyFutures.add(_generateDynamicIntervention(
          state, 'Blood Glucose',
          '${glucose.toStringAsFixed(0)} mg/dL (High)', 'hyperglycemia',
        ));
      }
    }

    // 2. Heart Rate Check
    final hr = state.heartRate;
    if (hr != null) {
      if (hr > 120) {
        anomalyFutures.add(_generateDynamicIntervention(
          state, 'Heart Rate',
          '${hr.toStringAsFixed(0)} bpm (Elevated)', 'tachycardia',
        ));
      } else if (hr < 50) {
        anomalyFutures.add(_generateDynamicIntervention(
          state, 'Heart Rate',
          '${hr.toStringAsFixed(0)} bpm (Low)', 'bradycardia',
        ));
      }
    }

    // 3. Blood Oxygen Check
    final spo2 = state.bloodOxygen;
    if (spo2 != null && spo2 < 92) {
      anomalyFutures.add(_generateDynamicIntervention(
        state, 'Blood Oxygen (SpO2)',
        '${spo2.toStringAsFixed(0)}% (Low)', 'low_spo2',
      ));
    }

    // 4. Blood Pressure Check
    final sys = state.bloodPressureSystolic;
    final dia = state.bloodPressureDiastolic;
    if (sys != null && dia != null) {
      if (sys > 140 || dia > 90) {
        anomalyFutures.add(_generateDynamicIntervention(
          state, 'Blood Pressure',
          '${sys.toStringAsFixed(0)}/${dia.toStringAsFixed(0)} mmHg (High)', 'hypertension',
        ));
      } else if (sys < 90) {
        anomalyFutures.add(_generateDynamicIntervention(
          state, 'Blood Pressure',
          '${sys.toStringAsFixed(0)}/${dia.toStringAsFixed(0)} mmHg (Low)', 'hypotension',
        ));
      }
    }

    // 5. Body Temperature Check
    final temp = state.bodyTemperature;
    if (temp != null && temp > 38.0) {
      anomalyFutures.add(_generateDynamicIntervention(
        state, 'Body Temperature',
        '${temp.toStringAsFixed(1)}°C (Elevated)', 'fever',
      ));
    }

    // Await all triggered anomalies concurrently to minimize latency
    if (anomalyFutures.isNotEmpty) {
      final results = await Future.wait(anomalyFutures);
      for (final result in results) {
        if (result != null) {
          alerts.add(result);
        }
      }
    }

    return alerts;
  }
  
  /// Send GlucoCoach messages for actions flagged as glucocoach_message
  Future<void> _sendGlucoCoachAlerts(AgentState state, List<ResolvedAction> actions) async {
    final phone = state.glucoCoachNumber ?? state.healthProfile.glucoCoachNumber;
    if (phone == null || phone.isEmpty) return;
    
    final glucoCoach = GlucoCoachAIService();
    if (!glucoCoach.isConfigured) return;
    
    for (final action in actions) {
      if (action.type == 'glucocoach_message' && action.priority >= 6) {
        try {
          await glucoCoach.sendProactiveMessage(
            userId: state.odId,
            message: action.message,
          );
          
          // Log the alert
          await _firestore.collection('agent_interactions').add({
            'userId': state.odId,
            'type': 'health_alert',
            'agent': action.resolvedBy,
            'message': action.message,
            'priority': action.priority,
            'alertType': action.payload['alertType'],
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          debugPrint('[CHO] GlucoCoach alert sent to $phone (priority: ${action.priority})');
        } catch (e) {
          debugPrint('[CHO] GlucoCoach send error: $e');
        }
      }
    }
  }
  
  /// Route event to appropriate mini-agents based on trigger type
  List<String> _routeEvent(AgentTriggerType trigger, AgentState state) {
    switch (trigger) {
      case AgentTriggerType.glucoseReading:
        // Glucose spike/drop affects nutrition and exercise
        final agents = <String>['snack'];
        if (state.currentGlucose != null && state.currentGlucose! > 180) {
          agents.add('exercise'); // Recommend walk for high glucose
        }
        // If heart rate is also elevated, add hydration
        if (state.heartRate != null && state.heartRate! > 100) {
          agents.add('hydration');
        }
        return agents;
        
      case AgentTriggerType.mealLogged:
        // After meal: check hydration and potential exercise
        final agents = <String>['hydration', 'exercise'];
        // If glucose is high after meal, also engage snack agent for restriction advice
        if (state.currentGlucose != null && state.currentGlucose! > 160) {
          agents.add('snack');
        }
        return agents;
        
      case AgentTriggerType.workoutCompleted:
        // Post-workout: hydration, snack, and sleep if late evening
        final agents = <String>['hydration', 'snack'];
        final hour = DateTime.now().hour;
        if (hour >= 20) {
          agents.add('sleep'); // Late workout affects sleep
        }
        return agents;
        
      case AgentTriggerType.sleepSync:
        // Morning sync: sleep analysis + exercise intensity adjustment
        final agents = <String>['sleep'];
        if (state.sleepHours != null && state.sleepHours! < 6) {
          agents.add('exercise'); // Lower intensity recommendation
          agents.add('hydration'); // Extra hydration for poor sleep recovery
        }
        return agents;
        
      case AgentTriggerType.hydrationCheck:
        final agents = <String>['hydration'];
        // If body temperature is elevated, also check exercise status
        if (state.bodyTemperature != null && state.bodyTemperature! > 37.5) {
          agents.add('exercise'); // Reduce intensity
        }
        return agents;
        
      case AgentTriggerType.dailyPlanning:
        // Morning planning involves all agents
        return ['sleep', 'hydration', 'exercise', 'snack'];
        
      case AgentTriggerType.eveningReview:
        // Evening: sleep prep + nutrition review
        return ['sleep', 'snack'];
        
      case AgentTriggerType.manualRequest:
        // User asked directly - invoke all and let them compete
        return ['sleep', 'hydration', 'exercise', 'snack'];
    }
  }
  
  /// Invoke a specific mini-agent
  Future<AgentRecommendation?> _invokeAgent(
    String agentName,
    AgentState state,
    Map<String, dynamic>? eventData,
  ) async {
    switch (agentName) {
      case 'sleep':
        return await _sleepAgent.analyze(state, eventData);
      case 'hydration':
        return await _hydrationAgent.analyze(state, eventData);
      case 'exercise':
        return await _exerciseAgent.analyze(state, eventData);
      case 'snack':
        return await _snackAgent.analyze(state, eventData);
      default:
        return null;
    }
  }
  
  /// Detect conflicts between recommendations
  List<Map<String, dynamic>> _detectConflicts(List<AgentRecommendation> recommendations) {
    final conflicts = <Map<String, dynamic>>[];
    
    // Check for nutrition vs exercise conflicts
    final nutritionRecs = recommendations.where((r) => r.category == 'nutrition').toList();
    final exerciseRecs = recommendations.where((r) => r.category == 'exercise').toList();
    
    for (final nutrition in nutritionRecs) {
      for (final exercise in exerciseRecs) {
        // Conflict: High glucose (don't eat carbs) + post-workout (need carbs)
        if (nutrition.metadata['restrictCarbs'] == true && 
            exercise.metadata['recommendCarbs'] == true) {
          conflicts.add({
            'type': 'nutrition_exercise',
            'description': 'Glucose management conflicts with post-workout recovery',
            'agents': [nutrition.agentName, exercise.agentName],
            'recommendations': [nutrition, exercise],
          });
        }
      }
    }
    
    // Check for rest vs exercise conflicts
    final restRecs = recommendations.where((r) => r.category == 'rest').toList();
    for (final rest in restRecs) {
      for (final exercise in exerciseRecs) {
        if (rest.metadata['recommendRest'] == true && 
            exercise.priority >= 7) {
          conflicts.add({
            'type': 'rest_exercise',
            'description': 'Poor sleep recovery conflicts with exercise recommendation',
            'agents': [rest.agentName, exercise.agentName],
            'recommendations': [rest, exercise],
          });
        }
      }
    }
    
    return conflicts;
  }
  
  /// Resolve conflicts using Gemini 1.5 Pro reasoning
  Future<List<ResolvedAction>> _resolveConflicts(
    AgentState state,
    List<Map<String, dynamic>> conflicts,
  ) async {
    final prompt = '''
CONFLICT RESOLUTION REQUIRED

=== PATIENT CONTEXT ===
${jsonEncode(state.toContextMap())}

=== CONFLICTS TO RESOLVE ===
${jsonEncode(conflicts)}

Analyze these conflicting recommendations and synthesize a SAFE, UNIFIED instruction.
Consider the patient's specific medical conditions, medications, and current biometric state.

Respond with JSON:
{
  "resolvedActions": [
    {
      "message": "The unified recommendation text for the user",
      "priority": 8,
      "type": "glucocoach_message",
      "reasoning": "Why this resolution is safe and appropriate"
    }
  ]
}
''';

    try {
      final response = await _proModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      
      // Parse JSON response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        final data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final actionsData = data['resolvedActions'] as List<dynamic>? ?? [];
        
        return actionsData.map((a) => ResolvedAction(
          type: a['type'] ?? 'notification',
          message: a['message'] ?? 'Please consult with your healthcare provider.',
          priority: a['priority'] ?? 5,
          resolvedBy: 'supervisor',
          payload: {'reasoning': a['reasoning']},
        )).toList();
      }
    } catch (e) {
      debugPrint('[CHO] Conflict resolution error: $e');
    }
    
    // Fallback: Conservative recommendation
    return [
      ResolvedAction(
        type: 'notification',
        message: 'We detected conflicting health signals. Please check your current glucose level and consult your care plan before any strenuous activity or dietary changes.',
        priority: 7,
        resolvedBy: 'supervisor_fallback',
      ),
    ];
  }
  
  /// Send welcome message to new GlucoCoach user
  Future<String> sendWelcomeMessage(AgentState state, String glucoCoachNumber) async {
    final prompt = '''
Generate a warm, personalized welcome message for a new Wellor user who just connected their GlucoCoach.

=== USER PROFILE ===
${jsonEncode(state.toContextMap())}

=== REQUIREMENTS ===
1. Welcome them by acknowledging their health goals
2. Summarize how the AI Health Agent will help them
3. Encourage connecting glucose monitoring devices for better accuracy
4. Keep it friendly and concise (under 300 words)
5. End with what they can expect (alerts, check-ins, etc.)

Write the message directly, no JSON wrapping.
''';

    try {
      final response = await _proModel.generateContent([Content.text(prompt)]);
      return response.text ?? _getDefaultWelcomeMessage(state);
    } catch (e) {
      debugPrint('[CHO] Welcome message generation error: $e');
      return _getDefaultWelcomeMessage(state);
    }
  }
  
  String _getDefaultWelcomeMessage(AgentState state) {
    final goals = state.healthProfile.healthGoals.take(2).join(' and ');
    return '''
👋 Welcome to Wellor Health Agent!

I'm your AI health companion, here to help you with $goals.

🤖 What I'll do for you:
• Monitor your health metrics 24/7
• Send personalized nutrition advice
• Alert you to important health changes
• Help you stay on track with your goals

📱 For the best experience, connect your devices:
• Glucose monitors (Freestyle Libre)
• Fitness trackers (Apple Watch, Fitbit, Garmin)

This allows me to provide real-time, accurate recommendations tailored to your body.

Ready to start? Just reply "status" anytime to check your daily progress!
''';
  }
}

/// ============================================================================
/// SLEEP AGENT (Mini-Agent)
/// ============================================================================
/// Trigger: Scheduled (7:00 AM morning sync)
/// Role: Analyze sleep quality and flag other agents if recovery is needed
/// ============================================================================
class SleepAgent {
  final GenerativeModel _flashModel;
  
  SleepAgent({required String apiKey}) : _flashModel = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.2,
      maxOutputTokens: 512,
    ),
  );
  
  Future<AgentRecommendation?> analyze(
    AgentState state,
    Map<String, dynamic>? eventData,
  ) async {
    final sleepHours = state.sleepHours ?? eventData?['sleepHours'];
    final sleepQuality = state.sleepQualityScore ?? eventData?['sleepQuality'];
    
    if (sleepHours == null) return null;
    
    final prompt = '''
SLEEP ANALYSIS for patient:
- Conditions: ${state.healthProfile.medicalConditions.join(', ')}
- Health goals: ${state.healthProfile.healthGoals.join(', ')}
- Medications: ${state.healthProfile.medications.join(', ')}
- Age: ${state.healthProfile.age ?? 'unknown'}

Sleep data from smartwatch:
- Hours slept: $sleepHours
- Quality score: ${sleepQuality ?? 'unknown'}/100
- Resting heart rate: ${state.restingHeartRate ?? 'unknown'} bpm
- Heart rate variability (HRV): ${state.heartRateVariability ?? 'unknown'} ms
- Current heart rate: ${state.heartRate ?? 'unknown'} bpm

Context:
- Steps yesterday: ${state.stepsToday ?? 'unknown'}
- Workout minutes: ${state.workoutMinutesToday ?? 0}
- Current glucose: ${state.currentGlucose ?? 'unknown'} mg/dL

ANALYSIS RULES:
1. If sleep < 6h OR quality < 50: Flag for reduced exercise intensity
2. If HRV is below 30ms: Suggest stress management, lighter day
3. If resting HR is elevated (>80 for non-athletes): Suggest recovery focus
4. Consider medications that affect sleep (beta-blockers, SSRIs, etc.)
5. For patients with diabetes: Poor sleep worsens insulin resistance — warn them
6. For patients with heart conditions: Sleep apnea screening if quality consistently low

Respond with JSON:
{
  "recommendation": "Brief personalized message addressing their specific conditions and goals",
  "priority": 1-10,
  "recommendRest": true/false,
  "exerciseIntensityModifier": 0.5-1.0,
  "alertExerciseAgent": true/false,
  "glucoCoachAlert": true/false (true if sleep was dangerously poor or HRV critical)
}
''';

    try {
      final response = await _flashModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      
      if (jsonMatch != null) {
        final data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        
        // Update state
        state.lastSleepAnalysis = DateTime.now();
        
        return AgentRecommendation(
          agentName: 'sleep',
          category: 'rest',
          recommendation: data['recommendation'] ?? 'Get adequate rest today.',
          priority: data['glucoCoachAlert'] == true ? 8 : (data['priority'] ?? 5),
          requiresConflictCheck: data['alertExerciseAgent'] == true,
          metadata: {
            'recommendRest': data['recommendRest'] ?? false,
            'exerciseModifier': data['exerciseIntensityModifier'] ?? 1.0,
            'sleepHours': sleepHours,
            'sleepQuality': sleepQuality,
            'hrv': state.heartRateVariability,
            'restingHR': state.restingHeartRate,
            'glucoCoachAlert': data['glucoCoachAlert'] ?? false,
          },
        );
      }
    } catch (e) {
      debugPrint('[SleepAgent] Error: $e');
    }
    
    return null;
  }
}

/// ============================================================================
/// HYDRATION AGENT (Mini-Agent)
/// ============================================================================
/// Trigger: Scheduled (hourly) + Event-driven (post-workout, high heat)
/// Role: Calculate fluid needs based on activity, weather, and health conditions
/// ============================================================================
class HydrationAgent {
  final GenerativeModel _flashModel;
  
  HydrationAgent({required String apiKey}) : _flashModel = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.2,
      maxOutputTokens: 512,
    ),
  );
  
  Future<AgentRecommendation?> analyze(
    AgentState state,
    Map<String, dynamic>? eventData,
  ) async {
    final currentHydration = state.hydrationLiters ?? 0;
    final caloriesBurned = state.caloriesBurnedToday ?? 0;
    final externalTemp = eventData?['temperatureCelsius'] ?? 25;
    
    final prompt = '''
HYDRATION ANALYSIS for patient:
- Conditions: ${state.healthProfile.medicalConditions.join(', ')}
- Health goals: ${state.healthProfile.healthGoals.join(', ')}
- Medications: ${state.healthProfile.medications.join(', ')}
- Weight: ${state.healthProfile.weight ?? 'unknown'}kg
- Age: ${state.healthProfile.age ?? 'unknown'}

Current biometrics from smartwatch:
- Water consumed today: ${currentHydration}L
- Heart rate: ${state.heartRate ?? 'unknown'} bpm
- Body temperature: ${state.bodyTemperature ?? 'unknown'}°C
- Blood oxygen (SpO2): ${state.bloodOxygen ?? 'unknown'}%
- Calories burned: $caloriesBurned kcal
- Steps today: ${state.stepsToday ?? 0}
- Workout minutes: ${state.workoutMinutesToday ?? 0} min
- Current glucose: ${state.currentGlucose ?? 'unknown'} mg/dL
- External temperature: ${externalTemp}°C

Condition-specific considerations:
- Kidney conditions: ${state.healthProfile.medicalConditions.where((c) => c.toLowerCase().contains('kidney')).join(', ')}
- Heart conditions: ${state.healthProfile.medicalConditions.where((c) => c.toLowerCase().contains('heart')).join(', ')}
- Diabetes: ${state.healthProfile.medicalConditions.any((c) => c.toLowerCase().contains('diabetes')) ? 'YES — hydration affects glucose' : 'No'}

ANALYSIS RULES:
1. Base: ~30mL per kg body weight per day
2. Add 500mL per 30min exercise or per 500 kcal burned
3. Add 250mL per degree above 30°C external temp
4. If body temperature > 37.5°C: Increase urgency (possible fever)
5. For kidney patients: Cap at doctor-recommended limit, flag if exceeding
6. For diabetic patients: Dehydration worsens glucose — increase priority
7. If SpO2 < 95%: Hydration supports oxygen transport — increase urgency
8. Post-workout: Electrolyte-enhanced water recommended

Respond with JSON:
{
  "recommendation": "Brief personalized hydration advice based on their conditions",
  "priority": 1-10,
  "targetLiters": 2.5,
  "remainingLiters": 1.5,
  "urgencyReason": "reason or null",
  "glucoCoachAlert": true/false (true if severely dehydrated or medical risk)
}
''';

    try {
      final response = await _flashModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      
      if (jsonMatch != null) {
        final data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        
        state.lastHydrationCheck = DateTime.now();
        
        return AgentRecommendation(
          agentName: 'hydration',
          category: 'hydration',
          recommendation: data['recommendation'] ?? 'Remember to stay hydrated.',
          priority: data['glucoCoachAlert'] == true ? 8 : (data['priority'] ?? 4),
          metadata: {
            'targetLiters': data['targetLiters'] ?? 2.5,
            'remainingLiters': data['remainingLiters'],
            'currentIntake': currentHydration,
            'glucoCoachAlert': data['glucoCoachAlert'] ?? false,
          },
        );
      }
    } catch (e) {
      debugPrint('[HydrationAgent] Error: $e');
    }
    
    return null;
  }
}

/// ============================================================================
/// EXERCISE AGENT (Mini-Agent)
/// ============================================================================
/// Trigger: Event-driven (glucose spike, meal logged, sleep sync)
/// Role: Calculate "Minimum Effective Dose" of movement for the day
/// ============================================================================
class ExerciseAgent {
  final GenerativeModel _flashModel;
  
  ExerciseAgent({required String apiKey}) : _flashModel = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.3,
      maxOutputTokens: 512,
    ),
  );
  
  Future<AgentRecommendation?> analyze(
    AgentState state,
    Map<String, dynamic>? eventData,
  ) async {
    final glucose = state.currentGlucose;
    final sleepModifier = eventData?['exerciseModifier'] ?? 1.0;
    final steps = state.stepsToday ?? 0;
    
    final prompt = '''
EXERCISE ANALYSIS for patient:
- Conditions: ${state.healthProfile.medicalConditions.join(', ')}
- Health goals: ${state.healthProfile.healthGoals.join(', ')}
- Medications: ${state.healthProfile.medications.join(', ')}
- Activity level: ${state.healthProfile.activityLevel ?? 'unknown'}
- Age: ${state.healthProfile.age ?? 'unknown'}
- Weight: ${state.healthProfile.weight ?? 'unknown'}kg

Real-time biometrics from smartwatch:
- Glucose: ${glucose ?? 'unknown'} mg/dL
- Heart rate: ${state.heartRate ?? 'unknown'} bpm
- Resting heart rate: ${state.restingHeartRate ?? 'unknown'} bpm
- HRV: ${state.heartRateVariability ?? 'unknown'} ms
- Blood oxygen (SpO2): ${state.bloodOxygen ?? 'unknown'}%
- Blood pressure: ${state.bloodPressureSystolic ?? 'unknown'}/${state.bloodPressureDiastolic ?? 'unknown'} mmHg
- Body temperature: ${state.bodyTemperature ?? 'unknown'}°C
- Steps today: $steps
- Workout minutes today: ${state.workoutMinutesToday ?? 0} min
- Calories burned: ${state.caloriesBurnedToday ?? 0} kcal
- Sleep last night: ${state.sleepHours ?? 'unknown'}h (quality: ${state.sleepQualityScore ?? 'unknown'}/100)
- Sleep-based intensity modifier: $sleepModifier

Condition-specific rules:
- Heart conditions: ${state.healthProfile.medicalConditions.where((c) => c.toLowerCase().contains('heart') || c.toLowerCase().contains('cardiac')).join(', ')}
- Diabetes: ${state.healthProfile.medicalConditions.any((c) => c.toLowerCase().contains('diabetes')) ? 'YES' : 'No'}
- Arthritis: ${state.healthProfile.medicalConditions.any((c) => c.toLowerCase().contains('arthritis')) ? 'YES — joint-friendly exercises only' : 'No'}
- Asthma: ${state.healthProfile.medicalConditions.any((c) => c.toLowerCase().contains('asthma')) ? 'YES — avoid triggers, moderate intensity' : 'No'}

ANALYSIS RULES:
1. If glucose > 180: Recommend immediate 15-min light walking (lowers glucose)
2. If glucose < 70: NO exercise — eating first priority
3. If heart rate > 100 at rest: Gentle activity only, check for overtraining
4. If blood pressure systolic > 140: Avoid heavy lifting, recommend gentle cardio
5. If SpO2 < 95%: Reduce intensity, focus on breathing exercises
6. If body temperature > 37.5°C: NO exercise (possible fever)
7. If HRV < 30ms: Recovery day, suggest yoga/stretching only
8. If sleep < 5h: Cap at light intensity
9. Heart condition patients: Cap heart rate at (220 - age) × 0.6
10. For weight management goal: Calculate Minimum Effective Dose to protect joints

Respond with JSON:
{
  "recommendation": "Specific exercise recommendation considering their conditions and current vitals",
  "priority": 1-10,
  "exerciseType": "walking|light|moderate|vigorous|yoga|breathing|none",
  "durationMinutes": 15,
  "caloriesBurnEstimate": 100,
  "targetHeartRate": 120,
  "recommendCarbs": true/false,
  "glucoseAlert": true/false,
  "glucoCoachAlert": true/false (true if vitals make exercise dangerous)
}
''';

    try {
      final response = await _flashModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      
      if (jsonMatch != null) {
        final data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        
        state.lastExerciseRecommendation = DateTime.now();
        
        // Determine if this requires conflict check (post-workout carb needs)
        final requiresCheck = data['recommendCarbs'] == true && 
                              glucose != null && glucose > 150;
        
        return AgentRecommendation(
          agentName: 'exercise',
          category: 'exercise',
          recommendation: data['recommendation'] ?? 'Stay active today.',
          priority: data['glucoseAlert'] == true ? 9 : (data['glucoCoachAlert'] == true ? 8 : (data['priority'] ?? 5)),
          requiresConflictCheck: requiresCheck,
          metadata: {
            'exerciseType': data['exerciseType'],
            'durationMinutes': data['durationMinutes'],
            'caloriesBurnEstimate': data['caloriesBurnEstimate'],
            'targetHeartRate': data['targetHeartRate'],
            'recommendCarbs': data['recommendCarbs'] ?? false,
            'glucoseAlert': data['glucoseAlert'] ?? false,
            'glucoCoachAlert': data['glucoCoachAlert'] ?? false,
            'currentHeartRate': state.heartRate,
            'currentGlucose': glucose,
          },
        );
      }
    } catch (e) {
      debugPrint('[ExerciseAgent] Error: $e');
    }
    
    return null;
  }
}

/// ============================================================================
/// SNACK AGENT (Mini-Agent)
/// ============================================================================
/// Trigger: Event-driven (glucose drop, post-workout, meal timing)
/// Role: Generate quick, safe snack recommendations within dietary constraints
/// ============================================================================
class SnackAgent {
  final GenerativeModel _flashModel;
  
  SnackAgent({required String apiKey}) : _flashModel = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.4,
      maxOutputTokens: 512,
    ),
  );
  
  Future<AgentRecommendation?> analyze(
    AgentState state,
    Map<String, dynamic>? eventData,
  ) async {
    final glucose = state.currentGlucose;
    final caloriesBurned = state.caloriesBurnedToday ?? 0;
    final caloriesConsumed = state.caloriesConsumedToday ?? 0;
    
    final prompt = '''
NUTRITION/SNACK ANALYSIS for patient:
- Conditions: ${state.healthProfile.medicalConditions.join(', ')}
- Allergies: ${state.healthProfile.allergies.join(', ')}
- Dietary restrictions: ${state.healthProfile.dietaryRestrictions.join(', ')}
- Health goals: ${state.healthProfile.healthGoals.join(', ')}
- Medications: ${state.healthProfile.medications.join(', ')}
- Weight: ${state.healthProfile.weight ?? 'unknown'}kg
- Age: ${state.healthProfile.age ?? 'unknown'}

Real-time biometrics from smartwatch:
- Glucose: ${glucose ?? 'unknown'} mg/dL
- Glucose trend: ${state.glucoseHistory.length >= 2 ? 'Recent readings: ${state.glucoseHistory.take(5).map((g) => g['value']).join(', ')} mg/dL' : 'No trend data'}
- Heart rate: ${state.heartRate ?? 'unknown'} bpm
- Calories burned: $caloriesBurned kcal
- Calories consumed: $caloriesConsumed kcal
- Steps today: ${state.stepsToday ?? 0}
- Hydration: ${state.hydrationLiters ?? 'unknown'}L
- Sleep last night: ${state.sleepHours ?? 'unknown'}h
- Post-workout recovery needed: ${eventData?['postWorkout'] ?? false}
- Workout minutes today: ${state.workoutMinutesToday ?? 0}

ANALYSIS RULES:
1. If glucose < 70: EMERGENCY — fast-acting carbs needed immediately (juice, glucose tabs)
2. If glucose > 200: RESTRICT carbs, suggest protein or fiber-rich options only
3. If glucose trending DOWN (3+ readings declining): Pre-emptive light snack
4. STRICTLY adhere to allergies — NEVER suggest foods with listed allergens
5. Respect dietary restrictions (vegan, halal, kosher, gluten-free, etc.)
6. For weight management goal: Focus on low-calorie, high-satiety options
7. For muscle building goal: Time protein intake around workouts
8. For diabetic patients: Low glycemic index options, count carbs
9. If calories burned >> consumed: Suggest energy-dense recovery snack
10. Medication interactions: Some medications require food, some restrict certain foods

Respond with JSON:
{
  "recommendation": "Specific snack recommendation with portion sizes, considering allergies and conditions",
  "priority": 1-10,
  "snackType": "carbs|protein|fat|balanced|none",
  "calories": 150,
  "restrictCarbs": true/false,
  "emergencyCarbs": true/false,
  "glucoCoachAlert": true/false (true for emergency glucose or critical nutrition need)
}
''';

    try {
      final response = await _flashModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      
      if (jsonMatch != null) {
        final data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        
        state.lastSnackRecommendation = DateTime.now();
        
        // Emergency carbs for low glucose is highest priority
        final isEmergency = data['emergencyCarbs'] == true;
        
        // Check if this conflicts with exercise recovery
        final requiresCheck = data['restrictCarbs'] == true && 
                              (eventData?['postWorkout'] == true);
        
        return AgentRecommendation(
          agentName: 'snack',
          category: 'nutrition',
          recommendation: data['recommendation'] ?? 'Have a balanced snack.',
          priority: isEmergency ? 10 : (data['glucoCoachAlert'] == true ? 8 : (data['priority'] ?? 5)),
          requiresConflictCheck: requiresCheck,
          metadata: {
            'snackType': data['snackType'],
            'calories': data['calories'],
            'restrictCarbs': data['restrictCarbs'] ?? false,
            'emergencyCarbs': isEmergency,
            'glucoCoachAlert': data['glucoCoachAlert'] ?? false,
            'currentGlucose': glucose,
          },
        );
      }
    } catch (e) {
      debugPrint('[SnackAgent] Error: $e');
    }
    
    return null;
  }
}

/// ============================================================================
/// MULTI-AGENT SYSTEM ORCHESTRATOR
/// ============================================================================
/// Singleton that manages the entire agent ecosystem
/// ============================================================================
class MultiAgentSystem {
  static MultiAgentSystem? _instance;
  
  final ChiefHealthOfficer _supervisor;
  AgentState? _currentState;
  
  // Scheduled task timers
  Timer? _hydrationTimer;
  Timer? _sleepTimer;
  
  // Stream controllers for reactive updates
  final _actionController = StreamController<ResolvedAction>.broadcast();
  Stream<ResolvedAction> get actionStream => _actionController.stream;
  
  MultiAgentSystem._() : _supervisor = ChiefHealthOfficer();
  
  static MultiAgentSystem get instance {
    _instance ??= MultiAgentSystem._();
    return _instance!;
  }
  
  /// Initialize the system with user's health profile
  Future<void> initialize(AgentState state) async {
    _currentState = state;
    await _supervisor.initializeContext(state);
    
    // Start scheduled tasks
    _startScheduledTasks();
    
    debugPrint('[MAS] Multi-Agent System initialized for user: ${state.odId}');
  }
  
  /// Start scheduled agent tasks (hydration hourly, sleep at 7 AM)
  void _startScheduledTasks() {
    // Hydration check every hour
    _hydrationTimer?.cancel();
    _hydrationTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _triggerHydrationCheck(),
    );
    
    // Sleep analysis would be triggered by workmanager at 7 AM
    // For real-time demo, we don't set a timer here
  }
  
  /// Trigger hydration check (scheduled)
  Future<void> _triggerHydrationCheck() async {
    if (_currentState == null) return;
    
    final actions = await _supervisor.processEvent(
      trigger: AgentTriggerType.hydrationCheck,
      state: _currentState!,
    );
    
    for (final action in actions) {
      _actionController.add(action);
    }
  }
  
  /// Process incoming glucose reading (event-driven)
  Future<List<ResolvedAction>> onGlucoseReading(double glucose) async {
    if (_currentState == null) return [];
    
    _currentState!.lastGlucose = _currentState!.currentGlucose;
    _currentState!.currentGlucose = glucose;
    _currentState!.glucoseTimestamp = DateTime.now();
    
    final actions = await _supervisor.processEvent(
      trigger: AgentTriggerType.glucoseReading,
      state: _currentState!,
      eventData: {'glucose': glucose},
    );
    
    for (final action in actions) {
      _actionController.add(action);
    }
    
    return actions;
  }
  
  /// Process meal logged event (event-driven)
  Future<List<ResolvedAction>> onMealLogged(Map<String, dynamic> mealData) async {
    if (_currentState == null) return [];
    
    _currentState!.caloriesConsumedToday = 
        (_currentState!.caloriesConsumedToday ?? 0) + 
        (mealData['calories'] as num? ?? 0).toDouble();
    
    return await _supervisor.processEvent(
      trigger: AgentTriggerType.mealLogged,
      state: _currentState!,
      eventData: mealData,
    );
  }
  
  /// Process workout completed event (event-driven)
  Future<List<ResolvedAction>> onWorkoutCompleted(Map<String, dynamic> workoutData) async {
    if (_currentState == null) return [];
    
    _currentState!.caloriesBurnedToday = 
        (_currentState!.caloriesBurnedToday ?? 0) + 
        (workoutData['caloriesBurned'] as num? ?? 0).toDouble();
    
    return await _supervisor.processEvent(
      trigger: AgentTriggerType.workoutCompleted,
      state: _currentState!,
      eventData: {...workoutData, 'postWorkout': true},
    );
  }
  
  /// Process morning sleep sync (scheduled via workmanager)
  Future<List<ResolvedAction>> onSleepSync(double sleepHours, int? quality) async {
    if (_currentState == null) return [];
    
    _currentState!.sleepHours = sleepHours;
    _currentState!.sleepQualityScore = quality;
    
    return await _supervisor.processEvent(
      trigger: AgentTriggerType.sleepSync,
      state: _currentState!,
      eventData: {'sleepHours': sleepHours, 'sleepQuality': quality},
    );
  }
  
  /// Manual request for advice (user-initiated)
  Future<List<ResolvedAction>> onManualRequest(String? query) async {
    if (_currentState == null) return [];
    
    return await _supervisor.processEvent(
      trigger: AgentTriggerType.manualRequest,
      state: _currentState!,
      eventData: query != null ? {'query': query} : null,
    );
  }
  
  /// Send GlucoCoach welcome message when user connects
  Future<String> sendWelcomeMessage(String glucoCoachNumber) async {
    if (_currentState == null) {
      return 'Please complete your health profile first.';
    }
    
    return await _supervisor.sendWelcomeMessage(_currentState!, glucoCoachNumber);
  }
  
  /// Run a trigger directly against the current state (e.g. initial health briefing)
  Future<List<ResolvedAction>> processEventDirect({
    required AgentTriggerType trigger,
    Map<String, dynamic>? eventData,
  }) async {
    if (_currentState == null) return [];

    final actions = await _supervisor.processEvent(
      trigger: trigger,
      state: _currentState!,
      eventData: eventData,
    );

    for (final action in actions) {
      _actionController.add(action);
    }

    return actions;
  }

  /// Get current agent state
  AgentState? get currentState => _currentState;
  
  /// Update device connection status
  void updateDeviceStatus({bool? glucoseMonitor, bool? wearable, String? deviceName}) {
    if (_currentState == null) return;
    
    if (glucoseMonitor != null) {
      _currentState!.glucoseMonitorConnected = glucoseMonitor;
    }
    if (wearable != null) {
      _currentState!.wearableConnected = wearable;
    }
    if (deviceName != null) {
      _currentState!.connectedDeviceName = deviceName;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _hydrationTimer?.cancel();
    _sleepTimer?.cancel();
    _actionController.close();
  }
}
