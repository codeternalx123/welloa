// lib/services/gluco_coach_ai_service.dart
// Claude Sonnet 3.5 for GlucoCoach health coach conversations (inbound replies + proactive coaching).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/env_config.dart';

/// Clinical-grade GlucoCoach replies via Claude Sonnet 3.5.
class GlucoCoachAIService {
  static final GlucoCoachAIService _instance = GlucoCoachAIService._internal();
  factory GlucoCoachAIService() => _instance;
  GlucoCoachAIService._internal();

  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  String get _apiKey => EnvConfig.anthropicApiKey;
  String get _modelId => EnvConfig.anthropicModel;
  bool get isAvailable => _apiKey.isNotEmpty;
  bool get isConfigured => isAvailable;
  Future<bool> isOptedIn() async => true;

  Future<bool> registerGlucoCoach(String phone) async {
    return true; // Deprecated external linking, mock success
  }

  Future<void> optOut() async {
    // Deprecated external linking
  }

  /// Generate a GlucoCoach message using Claude Sonnet.
  Future<String> generateReply({
    required String userPrompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async {
    if (!isAvailable) {
      throw Exception('ANTHROPIC_API_KEY not configured for GlucoCoach');
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
        'anthropic-beta': 'prompt-caching-2024-07-31',
      },
      body: jsonEncode({
        'model': _modelId,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (systemPrompt != null)
          'system': [
            {
              'type': 'text',
              'text': systemPrompt,
              'cache_control': {'type': 'ephemeral'},
            }
          ],
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      debugPrint('🤖 GlucoCoach Claude error ${response.statusCode}: ${response.body}');
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        final message = (err['error'] as Map?)?['message'] ?? response.body;
        throw Exception('Claude API error ${response.statusCode}: $message');
      } catch (_) {
        throw Exception('Claude API error ${response.statusCode}');
      }
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    if (content.isEmpty || content.first['type'] != 'text') {
      throw Exception('Empty response from Claude');
    }

    return (content.first['text'] as String).trim();
  }

  /// Sends a proactive message directly to the user's in-app GlucoCoach chat history via Firestore.
  Future<void> sendProactiveMessage({
    required String userId,
    required String message,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('gluco_coach_messages')
          .doc();

      await docRef.set({
        'id': docRef.id,
        'text': message,
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('📨 Proactive message saved to GlucoCoach chat for $userId');
    } catch (e) {
      debugPrint('🚨 Error sending proactive GlucoCoach message: $e');
    }
  }
}
