// lib/services/gemini_agent_pipeline.dart
// AI Health Analysis Pipeline using Gemini
// Implements Sentinel → Reasoning → Execution 3-node architecture
// for real-time glucose monitoring and GlucoCoach alerting.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'gluco_coach_ai_service.dart';

// ═══════════════════════════════════════════════════════════════════
// PATIENT STATE — Typed state flowing through the graph
// ═══════════════════════════════════════════════════════════════════

/// State object that flows through the LangGraph pipeline.
/// Equivalent to Python's TypedDict PatientState.
class PatientState {
  final String patientId;
  final String? phoneNumber;
  final double glucoseLevel;
  final double? glucoseVelocity; // mg/dL per minute
  final String patientProfile;
  final Map<String, dynamic>? healthContext;
  
  // Mutable state updated by nodes
  bool anomalyDetected;
  String? anomalyType;
  String? interventionPlan;
  bool messageSent;
  String? error;

  PatientState({
    required this.patientId,
    this.phoneNumber,
    required this.glucoseLevel,
    this.glucoseVelocity,
    required this.patientProfile,
    this.healthContext,
    this.anomalyDetected = false,
    this.anomalyType,
    this.interventionPlan,
    this.messageSent = false,
    this.error,
  });

  PatientState copyWith({
    String? patientId,
    String? phoneNumber,
    double? glucoseLevel,
    double? glucoseVelocity,
    String? patientProfile,
    Map<String, dynamic>? healthContext,
    bool? anomalyDetected,
    String? anomalyType,
    String? interventionPlan,
    bool? messageSent,
    String? error,
  }) {
    return PatientState(
      patientId: patientId ?? this.patientId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      glucoseLevel: glucoseLevel ?? this.glucoseLevel,
      glucoseVelocity: glucoseVelocity ?? this.glucoseVelocity,
      patientProfile: patientProfile ?? this.patientProfile,
      healthContext: healthContext ?? this.healthContext,
      anomalyDetected: anomalyDetected ?? this.anomalyDetected,
      anomalyType: anomalyType ?? this.anomalyType,
      interventionPlan: interventionPlan ?? this.interventionPlan,
      messageSent: messageSent ?? this.messageSent,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
    'patientId': patientId,
    'phoneNumber': phoneNumber,
    'glucoseLevel': glucoseLevel,
    'glucoseVelocity': glucoseVelocity,
    'anomalyDetected': anomalyDetected,
    'anomalyType': anomalyType,
    'interventionPlan': interventionPlan,
    'messageSent': messageSent,
    'error': error,
  };
}

// ═══════════════════════════════════════════════════════════════════
// GRAPH NODE RESULTS
// ═══════════════════════════════════════════════════════════════════

enum GraphRoute { reasoning, execution, end }

// ═══════════════════════════════════════════════════════════════════
// GEMINI AGENT PIPELINE — The LangGraph Implementation
// ═══════════════════════════════════════════════════════════════════

/// LangGraph-style agent pipeline using Google Gemini models.
/// 
/// Architecture:
/// ```
/// [Sentinel Node]      gemini-2.5-flash   → Fast anomaly detection
///        ↓
/// [Routing Logic]      → END if normal, → reasoning if anomaly
///        ↓
/// [Reasoning Node]     gemini-2.5-flash   → Minimum effective intervention
///        ↓
/// [Execution Node]     gemini-2.5-flash   → GlucoCoach tool invocation
///        ↓
///      [END]
/// ```
class GeminiAgentPipeline {
  static final GeminiAgentPipeline _instance = GeminiAgentPipeline._internal();
  factory GeminiAgentPipeline() => _instance;
  GeminiAgentPipeline._internal();

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  // Model IDs optimized for their roles
  static const String _flashModel = 'gemini-2.5-flash'; // Sentinel: fast, cheap
  static const String _proModel = 'gemini-2.5-flash';   // Reasoning & Execution: accurate

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  
  final GlucoCoachAIService _glucoCoach = GlucoCoachAIService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Prompt caching for patient profiles (reduces latency & cost)
  final Map<String, _CachedContext> _contextCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  // ─────────────────────────────────────────────────────────────────
  // MAIN GRAPH EXECUTION
  // ─────────────────────────────────────────────────────────────────

  /// Run the full LangGraph pipeline for a patient.
  /// This is the main entry point called by the background agent.
  Future<PatientState> invoke(PatientState initialState) async {
    debugPrint('🔄 Pipeline: Starting for ${initialState.patientId}');

    try {
      // Node 1: Sentinel
      PatientState state = await _sentinelNode(initialState);
      debugPrint('🔄 Pipeline: Sentinel → anomaly=${state.anomalyDetected}');

      // Routing
      final route = _routeAnomaly(state);
      if (route == GraphRoute.end) {
        debugPrint('🔄 Pipeline: Normal glucose → END');
        return state;
      }

      // Node 2: Reasoning
      state = await _reasoningNode(state);
      debugPrint('🔄 Pipeline: Reasoning → plan=${state.interventionPlan?.substring(0, 50)}...');

      // Node 3: Execution
      state = await _executionNode(state);
      debugPrint('🔄 Pipeline: Execution → sent=${state.messageSent}');

      // Log to Firestore
      await _logInteraction(state);

      return state;
    } catch (e, stack) {
      debugPrint('🔄 Pipeline: Error → $e\n$stack');
      return initialState.copyWith(error: e.toString());
    }
  }

  /// Invoke the pipeline asynchronously (fire-and-forget for batch processing).
  void invokeAsync(PatientState initialState) {
    invoke(initialState).then((state) {
      if (state.error != null) {
        debugPrint('🔄 Pipeline: Async error for ${state.patientId}: ${state.error}');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // NODE 1: SENTINEL (gemini-2.5-flash)
  // High-speed anomaly detection
  // ─────────────────────────────────────────────────────────────────

  Future<PatientState> _sentinelNode(PatientState state) async {
    // Fast heuristic pre-check to avoid API calls for obviously normal readings
    if (state.glucoseLevel >= 70 && state.glucoseLevel <= 140 &&
        (state.glucoseVelocity == null || state.glucoseVelocity!.abs() < 1.0)) {
      return state.copyWith(anomalyDetected: false);
    }

    // Critical conditions that bypass LLM for immediate response
    if (state.glucoseLevel < 70) {
      return state.copyWith(
        anomalyDetected: true,
        anomalyType: 'HYPOGLYCEMIA',
      );
    }

    // Build the sentinel prompt
    final prompt = '''
Analyze this glucose reading and determine if immediate intervention is needed.

PATIENT DATA:
- Current glucose: ${state.glucoseLevel.toStringAsFixed(0)} mg/dL
- Rate of change: ${state.glucoseVelocity?.toStringAsFixed(2) ?? 'unknown'} mg/dL/min
- Patient context: ${state.patientProfile}

ANOMALY CRITERIA:
- HYPOGLYCEMIA: glucose < 70 mg/dL → YES
- ACTIVE_SPIKE: glucose > 180 AND rising (velocity > 0.5) → YES  
- IMPENDING_SPIKE: glucose 120-180 AND rising fast (velocity > 1.2) → YES
- RAPID_DROP: glucose < 100 AND falling fast (velocity < -1.5) → YES
- HYPERGLYCEMIA: glucose > 250 → YES
- NORMAL: otherwise → NO

Respond with ONLY one of these exact formats:
YES:HYPOGLYCEMIA
YES:ACTIVE_SPIKE
YES:IMPENDING_SPIKE
YES:RAPID_DROP
YES:HYPERGLYCEMIA
NO:NORMAL
''';

    try {
      final response = await _callGemini(
        model: _flashModel,
        prompt: prompt,
        temperature: 0.0, // Deterministic for classification
        maxTokens: 50,
      );

      final normalized = response.trim().toUpperCase();
      
      if (normalized.startsWith('YES:')) {
        final anomalyType = normalized.substring(4).trim();
        return state.copyWith(
          anomalyDetected: true,
          anomalyType: anomalyType,
        );
      } else {
        return state.copyWith(anomalyDetected: false);
      }
    } catch (e) {
      // Fallback to heuristic if API fails
      debugPrint('⚠️ Sentinel: API error, using heuristics: $e');
      return _heuristicAnomalyDetection(state);
    }
  }

  /// Fallback heuristic when Gemini API is unavailable.
  PatientState _heuristicAnomalyDetection(PatientState state) {
    final g = state.glucoseLevel;
    final v = state.glucoseVelocity ?? 0.0;

    if (g < 70) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'HYPOGLYCEMIA');
    } else if (g > 250) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'HYPERGLYCEMIA');
    } else if (g > 180 && v > 0.5) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'ACTIVE_SPIKE');
    } else if (g > 120 && g <= 180 && v > 1.2) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'IMPENDING_SPIKE');
    } else if (g < 100 && v < -1.5) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'RAPID_DROP');
    } else {
      return state.copyWith(anomalyDetected: false);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // ROUTING LOGIC
  // ─────────────────────────────────────────────────────────────────

  GraphRoute _routeAnomaly(PatientState state) {
    return state.anomalyDetected ? GraphRoute.reasoning : GraphRoute.end;
  }

  // ─────────────────────────────────────────────────────────────────
  // NODE 2: REASONING (gemini-2.5-flash)
  // Minimum effective dose intervention planning
  // ─────────────────────────────────────────────────────────────────

  Future<PatientState> _reasoningNode(PatientState state) async {
    // Fetch or use cached patient context
    final context = await _getPatientContext(state.patientId);

    final systemPrompt = '''
You are a specialized clinical AI for Wellor. Your role is to determine the minimum effective dose of intervention based on the patient's condition.

PRINCIPLES:
1. Minimum effective dose — recommend the smallest intervention that will safely stabilize glucose
2. Patient-specific — consider their conditions, medications, and history
3. Actionable — give specific quantities, durations, and timing
4. Safe — never recommend interventions that could harm the patient given their profile

PATIENT PROFILE:
${state.patientProfile}

ADDITIONAL CONTEXT:
${context ?? 'No additional context available'}
''';

    final userPrompt = '''
CURRENT SITUATION:
- Glucose: ${state.glucoseLevel.toStringAsFixed(0)} mg/dL
- Anomaly Type: ${state.anomalyType}
- Rate of Change: ${state.glucoseVelocity?.toStringAsFixed(2) ?? 'unknown'} mg/dL/min

Generate a direct, actionable GlucoCoach message to send to the patient. The message should:

1. Acknowledge what's happening without causing panic
2. Give ONE specific intervention with exact amounts/duration:
   - For HYPOGLYCEMIA: Fast-acting carbs (specific amount)
   - For ACTIVE_SPIKE/IMPENDING_SPIKE: Light exercise or delay next meal (specific type and duration)
   - For HYPERGLYCEMIA: Hydration + movement (specific amounts)
   - For RAPID_DROP: Slow-digesting snack (specific food and portion)
3. State when to re-check
4. Be supportive but brief (under 100 words)

Respond with ONLY the GlucoCoach message text (no explanation, no JSON).
''';

    try {
      final response = await _callGemini(
        model: _proModel,
        prompt: userPrompt,
        systemInstruction: systemPrompt,
        temperature: 0.3, // Low temperature for medical advice
        maxTokens: 300,
      );

      return state.copyWith(interventionPlan: response.trim());
    } catch (e) {
      // Fallback to pre-written interventions if API fails
      debugPrint('⚠️ Reasoning: API error, using fallback: $e');
      return state.copyWith(
        interventionPlan: _getFallbackIntervention(state),
      );
    }
  }

  /// Fallback interventions when Gemini API is unavailable.
  String _getFallbackIntervention(PatientState state) {
    switch (state.anomalyType) {
      case 'HYPOGLYCEMIA':
        return '⚠️ *LOW GLUCOSE ALERT*\n\n'
            'Your glucose is ${state.glucoseLevel.toStringAsFixed(0)} mg/dL.\n\n'
            '*Action NOW:* Eat 15g fast carbs:\n'
            '• 4 glucose tablets\n'
            '• ½ cup juice\n'
            '• 1 tbsp honey\n\n'
            'Recheck in 15 minutes.';
      case 'ACTIVE_SPIKE':
        return '📈 *Glucose Spike Detected*\n\n'
            'You\'re at ${state.glucoseLevel.toStringAsFixed(0)} mg/dL and rising.\n\n'
            '*Action:* Take a 15-minute walk now, or do 30 air squats.\n'
            'Drink a full glass of water.\n\n'
            'Recheck in 30 minutes.';
      case 'IMPENDING_SPIKE':
        return '⚡ *Rising Glucose*\n\n'
            'You\'re at ${state.glucoseLevel.toStringAsFixed(0)} mg/dL and climbing.\n\n'
            '*Quick action:* Do 30 air squats or a 10-minute walk now.\n'
            'This can prevent a full spike.';
      case 'RAPID_DROP':
        return '📉 *Glucose Dropping Fast*\n\n'
            'You\'re at ${state.glucoseLevel.toStringAsFixed(0)} mg/dL and falling.\n\n'
            '*Have a small snack:* Apple slices with peanut butter or a handful of nuts.\n'
            'Recheck in 15 minutes.';
      case 'HYPERGLYCEMIA':
        return '🚨 *High Glucose Alert*\n\n'
            'Your glucose is ${state.glucoseLevel.toStringAsFixed(0)} mg/dL.\n\n'
            '*Actions:*\n'
            '• Drink 2 large glasses of water\n'
            '• Take a 20-minute walk if possible\n'
            '• Avoid carbs until levels drop\n\n'
            'Contact your healthcare provider if this persists.';
      default:
        return 'Your glucose needs attention. Please check the Wellor app for guidance.';
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // NODE 3: EXECUTION (gemini-2.5-flash with tools)
  // GlucoCoach tool invocation
  // ─────────────────────────────────────────────────────────────────

  Future<PatientState> _executionNode(PatientState state) async {
    if (state.interventionPlan == null || state.interventionPlan!.isEmpty) {
      return state.copyWith(
        messageSent: false,
        error: 'No intervention plan to execute',
      );
    }

    if (state.phoneNumber == null || state.phoneNumber!.isEmpty) {
      return state.copyWith(
        messageSent: false,
        error: 'No phone number for patient',
      );
    }

    // Build alert header based on anomaly type
    final header = _getAlertHeader(state.anomalyType);
    final fullMessage = '$header\n\n${state.interventionPlan}';

    // Execute the GlucoCoach tool
    final success = await _sendGlucoCoachAlert(
      patientId: state.patientId,
      phoneNumber: state.phoneNumber!,
      message: fullMessage,
    );

    return state.copyWith(messageSent: success);
  }

  String _getAlertHeader(String? anomalyType) {
    switch (anomalyType) {
      case 'HYPOGLYCEMIA':
        return '⚠️ *LOW GLUCOSE ALERT*';
      case 'HYPERGLYCEMIA':
        return '🚨 *HIGH GLUCOSE ALERT*';
      case 'ACTIVE_SPIKE':
        return '📈 *Glucose Spike Detected*';
      case 'IMPENDING_SPIKE':
        return '⚡ *Rising Glucose*';
      case 'RAPID_DROP':
        return '📉 *Glucose Dropping*';
      default:
        return '🔔 *Health Alert*';
    }
  }

  /// The GlucoCoach tool that gets invoked by the execution node.
  /// Equivalent to the @tool decorated function in LangChain.
  Future<bool> _sendGlucoCoachAlert({
    required String patientId,
    required String phoneNumber,
    required String message,
  }) async {
    debugPrint('🚨 Tool: send_glucoCoach_alert → $patientId');

    try {
      await _glucoCoach.sendProactiveMessage(
        userId: patientId,
        message: message,
      );
      debugPrint('🚨 Tool: GlucoCoach sent successfully to $phoneNumber');
      return true;
    } catch (e) {
      debugPrint('🚨 Tool: GlucoCoach send failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // GEMINI API CALLS
  // ─────────────────────────────────────────────────────────────────

  Future<String> _callGemini({
    required String model,
    required String prompt,
    String? systemInstruction,
    double temperature = 0.3,
    int maxTokens = 500,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured');
    }

    final url = Uri.parse('$_baseUrl/$model:generateContent?key=$_apiKey');

    final payload = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': 0.8,
        'topK': 40,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_ONLY_HIGH'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_ONLY_HIGH'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_ONLY_HIGH'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_ONLY_HIGH'},
      ],
    };

    if (systemInstruction != null) {
      payload['systemInstruction'] = {
        'parts': [{'text': systemInstruction}]
      };
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null) return text as String;
      throw Exception('Empty response from Gemini');
    } else {
      throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // CONTEXT CACHING
  // Reduces latency and token costs for repeated patient queries
  // ─────────────────────────────────────────────────────────────────

  Future<String?> _getPatientContext(String patientId) async {
    // Check cache
    final cached = _contextCache[patientId];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      return cached.context;
    }

    // Fetch fresh context from Firestore
    try {
      final userDoc = await _db.collection('users').doc(patientId).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data()!;
      final buffer = StringBuffer();

      // Build comprehensive context
      final conditions = List<String>.from(data['diseases'] ?? []);
      final goals = List<String>.from(data['healthGoals'] ?? []);
      final medications = List<String>.from(data['medications'] ?? []);
      final glucotype = data['glucotype'];
      final fitnessLevel = data['fitnessLevel'];

      if (conditions.isNotEmpty) {
        buffer.writeln('Medical Conditions: ${conditions.join(", ")}');
      }
      if (medications.isNotEmpty) {
        buffer.writeln('Medications: ${medications.join(", ")}');
      }
      if (goals.isNotEmpty) {
        buffer.writeln('Health Goals: ${goals.join(", ")}');
      }
      if (glucotype != null) {
        buffer.writeln('Glucotype: $glucotype');
      }
      if (fitnessLevel != null) {
        buffer.writeln('Fitness Level: $fitnessLevel');
      }

      final context = buffer.toString();

      // Cache it
      _contextCache[patientId] = _CachedContext(
        context: context,
        expiry: DateTime.now().add(_cacheExpiry),
      );

      return context;
    } catch (e) {
      debugPrint('⚠️ Context fetch error: $e');
      return null;
    }
  }

  /// Clear cached context for a patient (call when profile updates).
  void invalidateCache(String patientId) {
    _contextCache.remove(patientId);
  }

  // ─────────────────────────────────────────────────────────────────
  // LOGGING
  // ─────────────────────────────────────────────────────────────────

  Future<void> _logInteraction(PatientState state) async {
    try {
      await _db.collection('agent_interactions').add({
        'userId': state.patientId,
        'type': 'pipeline_alert',
        'anomalyType': state.anomalyType,
        'glucoseLevel': state.glucoseLevel,
        'glucoseVelocity': state.glucoseVelocity,
        'interventionPlan': state.interventionPlan,
        'messageSent': state.messageSent,
        'error': state.error,
        'pipeline': 'gemini_langgraph',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Log error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// HELPER CLASS
// ═══════════════════════════════════════════════════════════════════

class _CachedContext {
  final String context;
  final DateTime expiry;

  _CachedContext({required this.context, required this.expiry});
}

// ═══════════════════════════════════════════════════════════════════
// CONVENIENCE EXTENSION FOR BATCH PROCESSING
// ═══════════════════════════════════════════════════════════════════

extension GeminiPipelineBatch on GeminiAgentPipeline {
  /// Process multiple patients in parallel with rate limiting.
  Future<List<PatientState>> invokeParallel(
    List<PatientState> states, {
    int concurrency = 5,
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    final results = <PatientState>[];
    
    for (var i = 0; i < states.length; i += concurrency) {
      final batch = states.skip(i).take(concurrency).toList();
      final batchResults = await Future.wait(
        batch.map((s) => invoke(s)),
      );
      results.addAll(batchResults);
      
      // Rate limiting between batches
      if (i + concurrency < states.length) {
        await Future.delayed(delay);
      }
    }
    
    return results;
  }
}
