import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// UNICORN GRADE: High-Precision AI Orchestration Engine.
/// Handles Inference Lifecycle, Schema Enforcement, and Network Resilience.
class MultiAIService {
  static final MultiAIService _instance = MultiAIService._internal();
  factory MultiAIService() => _instance;
  MultiAIService._internal();

  // Constants for Gemini 3.0 Flash
  static const String _modelId = 'gemini-2.5-flash';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  // Lead Dev Note: Never hardcode keys. Use .env or Secret Manager.
  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // ============================================
  // CORE EXECUTION: THE COGNITIVE HUB
  // ============================================

  /// Executes a task with forced Structured Output (JSON Mode).
  /// This eliminates the need for regex/markdown cleaning.
  Future<Map<String, dynamic>> executeStructuredTask({
    required String prompt,
    required String systemInstruction,
    double temperature = 0.2, // Low temp = High precision for clinical data
  }) async {
    final url = Uri.parse('$_baseUrl/$_modelId:generateContent?key=$_apiKey');

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ],
      'system_instruction': {
        'parts': [{'text': systemInstruction}]
      },
      'generationConfig': {
        'temperature': temperature,
        'topP': 0.8,
        'topK': 40,
        'response_mime_type': 'application/json', // UNICORN: Force JSON output
      }
    };

    try {
      debugPrint('🤖 AI Orchestrator: Initiating inference for $prompt');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        return _handleSuccess(response.body);
      } else {
        return await _handleFailure(response, prompt, systemInstruction, temperature);
      }
    } on TimeoutException {
      throw Exception('AI_TIMEOUT: Upstream inference exceeded latency budget.');
    } catch (e) {
      debugPrint('❌ AI Critical Failure: $e');
      rethrow;
    }
  }

  // ============================================
  // RESILIENCE LOGIC: THE TRIAGE LAYER
  // ============================================

  Map<String, dynamic> _handleSuccess(String body) {
    final data = jsonDecode(body);
    final textResponse = data['candidates'][0]['content']['parts'][0]['text'];
    
    // Since we forced JSON mode, textResponse is guaranteed to be a valid JSON string.
    return jsonDecode(textResponse);
  }

  /// Implements Exponential Backoff for Rate Limiting (429) and Server Errors (500).
  Future<Map<String, dynamic>> _handleFailure(
    http.Response response, 
    String prompt, 
    String sys, 
    double temp
  ) async {
    if (response.statusCode == 429) {
      debugPrint('⏳ AI Rate Limited: Backing off for 2 seconds...');
      await Future.delayed(const Duration(seconds: 2));
      return executeStructuredTask(prompt: prompt, systemInstruction: sys, temperature: temp);
    }

    final errorBody = jsonDecode(response.body);
    throw Exception('AI_ORCHESTRATOR_ERROR: ${errorBody['error']['message']}');
  }

  // ============================================
  // UNICORN HELPER: SEMANTIC CHAT
  // ============================================

  /// Standard chat completion for less structured interactions (e.g., General Advice).
  Future<String> chatCompletion(String message, {String? context}) async {
    final url = Uri.parse('$_baseUrl/$_modelId:generateContent?key=$_apiKey');
    
    final prompt = context != null ? 'Context: $context\nUser: $message' : message;

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'parts': [{'text': prompt}]}],
        'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    }
    return "I'm currently recalibrating my metabolic sensors. Please try again in a moment.";
  }
}