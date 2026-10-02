// lib/services/claude_agent_pipeline.dart
// Clinical health agent pipeline using Claude Sonnet 3.5.
// Same Sentinel → Reasoning → Execution flow as GeminiAgentPipeline.

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import 'gemini_agent_pipeline.dart' show PatientState, GraphRoute;
import 'gluco_coach_ai_service.dart';

/// LangGraph-style agent pipeline using Claude Sonnet 3.5.
class ClaudeAgentPipeline {
  static final ClaudeAgentPipeline _instance = ClaudeAgentPipeline._internal();
  factory ClaudeAgentPipeline() => _instance;
  ClaudeAgentPipeline._internal();

  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  String get _apiKey => EnvConfig.anthropicApiKey;
  String get _modelId => EnvConfig.anthropicModel;
  bool get isAvailable => _apiKey.isNotEmpty;

  final GlucoCoachAIService _glucoCoach = GlucoCoachAIService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, _ClaudeCachedContext> _contextCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  Future<PatientState> invoke(PatientState initialState) async {
    debugPrint('🔄 Claude pipeline: Starting for ${initialState.patientId}');

    try {
      PatientState state = await _sentinelNode(initialState);
      debugPrint('🔄 Claude pipeline: Sentinel → anomaly=${state.anomalyDetected}');

      if (_routeAnomaly(state) == GraphRoute.end) {
        debugPrint('🔄 Claude pipeline: Normal glucose → END');
        return state;
      }

      state = await _reasoningNode(state);
      debugPrint(
        '🔄 Claude pipeline: Reasoning → plan=${state.interventionPlan?.substring(0, state.interventionPlan!.length.clamp(0, 50))}...',
      );

      state = await _executionNode(state);
      debugPrint('🔄 Claude pipeline: Execution → sent=${state.messageSent}');

      await _logInteraction(state);
      return state;
    } catch (e, stack) {
      debugPrint('🔄 Claude pipeline: Error → $e\n$stack');
      return initialState.copyWith(error: e.toString());
    }
  }

  void invokeAsync(PatientState initialState) {
    invoke(initialState).then((state) {
      if (state.error != null) {
        debugPrint(
          '🔄 Claude pipeline: Async error for ${state.patientId}: ${state.error}',
        );
      }
    });
  }

  Future<PatientState> _sentinelNode(PatientState state) async {
    if (state.glucoseLevel >= 70 &&
        state.glucoseLevel <= 140 &&
        (state.glucoseVelocity == null || state.glucoseVelocity!.abs() < 1.0)) {
      return state.copyWith(anomalyDetected: false);
    }

    if (state.glucoseLevel < 70) {
      return state.copyWith(
        anomalyDetected: true,
        anomalyType: 'HYPOGLYCEMIA',
      );
    }

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
      final response = await _callClaude(
        userPrompt: prompt,
        temperature: 0.0,
        maxTokens: 50,
      );
      final normalized = response.trim().toUpperCase();

      if (normalized.startsWith('YES:')) {
        return state.copyWith(
          anomalyDetected: true,
          anomalyType: normalized.substring(4).trim(),
        );
      }
      return state.copyWith(anomalyDetected: false);
    } catch (e) {
      debugPrint('⚠️ Claude sentinel: API error, using heuristics: $e');
      return _heuristicAnomalyDetection(state);
    }
  }

  PatientState _heuristicAnomalyDetection(PatientState state) {
    final g = state.glucoseLevel;
    final v = state.glucoseVelocity ?? 0.0;

    if (g < 70) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'HYPOGLYCEMIA');
    }
    if (g > 250) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'HYPERGLYCEMIA');
    }
    if (g > 180 && v > 0.5) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'ACTIVE_SPIKE');
    }
    if (g > 120 && g <= 180 && v > 1.2) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'IMPENDING_SPIKE');
    }
    if (g < 100 && v < -1.5) {
      return state.copyWith(anomalyDetected: true, anomalyType: 'RAPID_DROP');
    }
    return state.copyWith(anomalyDetected: false);
  }

  GraphRoute _routeAnomaly(PatientState state) {
    return state.anomalyDetected ? GraphRoute.reasoning : GraphRoute.end;
  }

  Future<PatientState> _reasoningNode(PatientState state) async {
    final context = await _getPatientContext(state.patientId);

    final systemPrompt = '''
You are a specialized clinical AI for Wellor. Your role is to determine the minimum effective dose of intervention based on the patient's condition.

PRINCIPLES:
1. Minimum effective dose — recommend the smallest intervention that will safely stabilize glucose
2. Patient-specific — consider their conditions, medications, and history
3. Actionable — give specific quantities, durations, and timing
4. Safe — never recommend interventions that could harm the patient given their profile
5. Wellness and education only — not a substitute for emergency medical care

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

Generate a direct, actionable message for the patient. The message should:
1. Acknowledge what's happening without causing panic
2. Give ONE specific intervention with exact amounts/duration
3. State when to re-check
4. Be supportive but brief (under 100 words)

Respond with ONLY the message text (no explanation, no JSON).
''';

    try {
      final response = await _callClaude(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        maxTokens: 300,
      );
      return state.copyWith(interventionPlan: response.trim());
    } catch (e) {
      debugPrint('⚠️ Claude reasoning: API error, using fallback: $e');
      return state.copyWith(interventionPlan: _getFallbackIntervention(state));
    }
  }

  String _getFallbackIntervention(PatientState state) {
    switch (state.anomalyType) {
      case 'HYPOGLYCEMIA':
        return 'Your blood sugar is ${state.glucoseLevel.toStringAsFixed(0)} mg/dL, which is low. '
            'Have 15g of fast carbs now (4 glucose tablets, half a cup of juice, or 1 tbsp honey) '
            'and recheck in 15 minutes.';
      case 'ACTIVE_SPIKE':
        return 'Your blood sugar is ${state.glucoseLevel.toStringAsFixed(0)} mg/dL and rising. '
            'Take a 15-minute walk, drink a glass of water, and recheck in 30 minutes.';
      case 'IMPENDING_SPIKE':
        return 'Your blood sugar is ${state.glucoseLevel.toStringAsFixed(0)} mg/dL and climbing. '
            'A quick 10-minute walk or 30 air squats can help prevent a bigger spike.';
      case 'RAPID_DROP':
        return 'Your blood sugar is ${state.glucoseLevel.toStringAsFixed(0)} mg/dL and falling. '
            'Have a small snack like apple slices with peanut butter and recheck in 15 minutes.';
      case 'HYPERGLYCEMIA':
        return 'Your blood sugar is ${state.glucoseLevel.toStringAsFixed(0)} mg/dL, which is high. '
            'Drink water, take a short walk if you can, avoid extra carbs, and contact your doctor if it stays high.';
      default:
        return 'Your blood sugar needs attention. Open Wellor for more guidance.';
    }
  }

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

    final header = _getAlertHeader(state.anomalyType);
    final fullMessage = '$header\n\n${state.interventionPlan}';
    await _glucoCoach.sendProactiveMessage(
      userId: state.patientId,
      message: fullMessage,
    );
    return state.copyWith(messageSent: true);
  }

  String _getAlertHeader(String? anomalyType) {
    switch (anomalyType) {
      case 'HYPOGLYCEMIA':
        return '⚠️ *LOW BLOOD SUGAR ALERT*';
      case 'HYPERGLYCEMIA':
        return '🚨 *HIGH BLOOD SUGAR ALERT*';
      case 'ACTIVE_SPIKE':
        return '📈 *Blood Sugar Spike*';
      case 'IMPENDING_SPIKE':
        return '⚡ *Blood Sugar Rising*';
      case 'RAPID_DROP':
        return '📉 *Blood Sugar Dropping*';
      default:
        return '🔔 *Health Alert*';
    }
  }

  Future<String> _callClaude({
    String? systemPrompt,
    required String userPrompt,
    double temperature = 0.3,
    int maxTokens = 500,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('ANTHROPIC_API_KEY not configured');
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode({
        'model': _modelId,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (systemPrompt != null) 'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Claude API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    if (content.isEmpty || content.first['type'] != 'text') {
      throw Exception('Empty response from Claude');
    }
    return content.first['text'] as String;
  }

  Future<String?> _getPatientContext(String patientId) async {
    final cached = _contextCache[patientId];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      return cached.context;
    }

    try {
      final userDoc = await _db.collection('users').doc(patientId).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data()!;
      final buffer = StringBuffer();
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
      _contextCache[patientId] = _ClaudeCachedContext(
        context: context,
        expiry: DateTime.now().add(_cacheExpiry),
      );
      return context;
    } catch (e) {
      debugPrint('⚠️ Claude context fetch error: $e');
      return null;
    }
  }

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
        'pipeline': 'claude_sonnet_langgraph',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Claude log error: $e');
    }
  }
}

class _ClaudeCachedContext {
  final String context;
  final DateTime expiry;

  _ClaudeCachedContext({required this.context, required this.expiry});
}
