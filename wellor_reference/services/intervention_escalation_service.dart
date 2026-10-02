// lib/services/intervention_escalation_service.dart
// MEDICAL-GRADE: Tiered Intervention Escalation System
// Handles GlucoCoach messaging, voice calls, and emergency contact alerts
// Part of the Predictive Metabolic Twin system

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../models/glucose_context.dart';
import '../models/safety_state.dart';
import '../config/medical_safety_config.dart';
import 'deterministic_safety_engine.dart';
import 'gluco_coach_ai_service.dart';
import 'claude_medical_ai_service.dart';
import 'subscription_entitlement_resolver.dart';

/// ═══════════════════════════════════════════════════════════════════
/// INTERVENTION ESCALATION SERVICE
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Escalation Tiers:**
/// 1. **In-App Notification** (Cautionary)
/// 2. **GlucoCoach Message** (Preventative)
/// 3. **GlucoCoach + In-App Alarm** (Urgent)
/// 4. **Voice Call** (Critical)
/// 5. **Voice Call + Emergency Contact** (Imminent Crash)
/// 
/// **Failover Strategy:**
/// - GlucoCoach fails → SMS
/// - Internet unavailable → Native phone call
/// - User doesn't answer → Emergency contact
/// ═══════════════════════════════════════════════════════════════════

class InterventionEscalationService {
  static final InterventionEscalationService _instance = InterventionEscalationService._internal();
  factory InterventionEscalationService() => _instance;
  InterventionEscalationService._internal();
  
  final GlucoCoachAIService _glucoCoach = GlucoCoachAIService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  static const MethodChannel _platform = MethodChannel('com.bitelab.health/native');
  
  // Track recent interventions to avoid spam
  final Map<String, DateTime> _lastInterventionTime = {};
  final Duration _minInterventionGap = const Duration(minutes: 5);
  
  // ═══════════════════════════════════════════════════════════════════
  // MAIN INTERVENTION DISPATCHER
  // ═══════════════════════════════════════════════════════════════════
  
  /// Execute intervention based on safety evaluation
  Future<InterventionResult> executeIntervention({
    required String userId,
    required SafetyEvaluation evaluation,
    required GlucoseContext context,
    required InterventionTone tone,
  }) async {
    try {
      final state = evaluation.state;
      final channel = state.recommendedChannel;
      
      debugPrint('🚨 Intervention: ${state.label} → ${channel.label}');
      
      // Check rate limiting (except for critical states)
      if (!state.isCritical && _isRateLimited(userId, state)) {
        debugPrint('⏱️ Intervention: Rate limited');
        return InterventionResult(
          success: false,
          reason: 'Rate limited (too soon since last intervention)',
        );
      }
      
      // Generate message using Claude (AI for communication, not decision)
      final message = await _generateInterventionMessage(
        evaluation: evaluation,
        context: context,
        tone: tone,
      );
      
      // Execute channel-specific intervention
      InterventionResult result;
      
      switch (channel) {
        case InterventionChannel.voiceCall:
        case InterventionChannel.voiceCallWithEmergency:
          result = await _executeVoiceCallIntervention(
            userId: userId,
            evaluation: evaluation,
            context: context,
            message: message,
            alertEmergency: channel == InterventionChannel.voiceCallWithEmergency,
          );
          break;
        
        case InterventionChannel.glucoCoachAndInApp:
          result = await _executeGlucoCoachAndInAppIntervention(
            userId: userId,
            evaluation: evaluation,
            context: context,
            message: message,
          );
          break;
        
        case InterventionChannel.glucoCoach:
          result = await _executeGlucoCoachIntervention(
            userId: userId,
            evaluation: evaluation,
            context: context,
            message: message,
          );
          break;
        
        case InterventionChannel.inApp:
          result = await _executeInAppIntervention(
            userId: userId,
            evaluation: evaluation,
            context: context,
            message: message,
          );
          break;
        
        case InterventionChannel.none:
          return InterventionResult(success: true, reason: 'No intervention needed');
      }
      
      // Log intervention
      await _logIntervention(userId, evaluation, context, message, result);
      
      // Update rate limiting
      if (result.success) {
        _lastInterventionTime['${userId}_${state.name}'] = DateTime.now();
      }
      
      return result;
      
    } catch (e) {
      debugPrint('❌ Intervention: Error executing: $e');
      return InterventionResult(
        success: false,
        reason: 'Error: $e',
      );
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // CHANNEL-SPECIFIC INTERVENTIONS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Execute voice call intervention (CRITICAL)
  Future<InterventionResult> _executeVoiceCallIntervention({
    required String userId,
    required SafetyEvaluation evaluation,
    required GlucoseContext context,
    required String message,
    required bool alertEmergency,
  }) async {
    try {
      if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(userId)) {
        debugPrint('📞 Intervention: Voice requires Ultra — falling back to GlucoCoach');
        return _executeGlucoCoachIntervention(
          userId: userId,
          evaluation: evaluation,
          context: context,
          message: '📞 Voice escalation unavailable on your plan. $message',
        );
      }

      // Get user's phone number
      final userDoc = await _db.collection('users').doc(userId).get();
      final userPhone = userDoc.data()?['phoneNumber'] as String?;
      
      if (userPhone == null) {
        debugPrint('❌ Intervention: No phone number for user');
        return InterventionResult(success: false, reason: 'No phone number');
      }
      
      // Attempt to make native voice call
      debugPrint('📞 Intervention: Initiating voice call to $userPhone');
      
      final callResult = await _makeNativeVoiceCall(
        phoneNumber: userPhone,
        message: message,
        glucose: context.currentValue,
      );
      
      if (!callResult) {
        debugPrint('❌ Intervention: Voice call failed, trying URL launcher');
        
        // Fallback: Use tel: URL (opens dialer)
        final telUri = Uri.parse('tel:$userPhone');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
      }
      
      // If emergency contact alert required
      if (alertEmergency) {
        await _alertEmergencyContact(userId, context, message);
      }
      
      return InterventionResult(
        success: true,
        reason: 'Voice call initiated',
        channel: InterventionChannel.voiceCall,
      );
      
    } catch (e) {
      debugPrint('❌ Intervention: Voice call error: $e');
      
      // Ultimate fallback: GlucoCoach
      return await _executeGlucoCoachIntervention(
        userId: userId,
        evaluation: evaluation,
        context: context,
        message: '🚨 URGENT: $message',
      );
    }
  }
  
  /// Execute GlucoCoach + In-App intervention (URGENT)
  Future<InterventionResult> _executeGlucoCoachAndInAppIntervention({
    required String userId,
    required SafetyEvaluation evaluation,
    required GlucoseContext context,
    required String message,
  }) async {
    // Execute both channels in parallel
    final results = await Future.wait([
      _executeGlucoCoachIntervention(
        userId: userId,
        evaluation: evaluation,
        context: context,
        message: message,
      ),
      _executeInAppIntervention(
        userId: userId,
        evaluation: evaluation,
        context: context,
        message: message,
      ),
    ]);
    
    final glucoCoachSuccess = results[0].success;
    final inAppSuccess = results[1].success;
    
    return InterventionResult(
      success: glucoCoachSuccess || inAppSuccess,
      reason: 'GlucoCoach: $glucoCoachSuccess, In-App: $inAppSuccess',
      channel: InterventionChannel.glucoCoachAndInApp,
    );
  }
  
  /// Execute GlucoCoach intervention (PREVENTATIVE)
  Future<InterventionResult> _executeGlucoCoachIntervention({
    required String userId,
    required SafetyEvaluation evaluation,
    required GlucoseContext context,
    required String message,
  }) async {
    try {
      // Get user's GlucoCoach number
      final userDoc = await _db.collection('users').doc(userId).get();
      final glucoCoachNumber = userDoc.data()?['glucoCoachNumber'] as String?;
      
      if (glucoCoachNumber == null || glucoCoachNumber.isEmpty) {
        debugPrint('⚠️ Intervention: No GlucoCoach number configured');
        return InterventionResult(success: false, reason: 'No GlucoCoach number');
      }
      
      // Check GlucoCoach opt-in status
      final optedIn = userDoc.data()?['glucoCoachOptedIn'] as bool? ?? false;
      if (!optedIn) {
        debugPrint('⚠️ Intervention: User not opted into GlucoCoach');
        return InterventionResult(success: false, reason: 'Not opted in');
      }
      
      // Send GlucoCoach message
      debugPrint('📱 Intervention: Sending GlucoCoach to $glucoCoachNumber');
      
      try {
        await _glucoCoach.sendProactiveMessage(
          userId: userId,
          message: message,
        );
        return InterventionResult(
          success: true,
          reason: 'GlucoCoach message sent',
          channel: InterventionChannel.glucoCoach,
        );
      } catch (e) {
        // Fallback: Try SMS
        debugPrint('⚠️ Intervention: GlucoCoach failed, trying SMS: $e');
        return await _sendSMSFallback(glucoCoachNumber, message);
      }
      
    } catch (e) {
      debugPrint('❌ Intervention: GlucoCoach error: $e');
      return InterventionResult(success: false, reason: 'GlucoCoach error: $e');
    }
  }
  
  /// Execute in-app intervention (CAUTIONARY)
  Future<InterventionResult> _executeInAppIntervention({
    required String userId,
    required SafetyEvaluation evaluation,
    required GlucoseContext context,
    required String message,
  }) async {
    try {
      // Store notification in Firestore for app to display
      await _db.collection('users').doc(userId).collection('notifications').add({
        'type': 'glucose_alert',
        'title': evaluation.state.label,
        'message': message,
        'glucose': context.currentValue,
        'velocity': context.velocity,
        'safetyState': evaluation.state.name,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      // Trigger local notification via platform channel
      try {
        await _platform.invokeMethod('showNotification', {
          'title': '🩺 ${evaluation.state.label}',
          'body': message,
          'priority': evaluation.state.isCritical ? 'max' : 'high',
        });
      } catch (e) {
        debugPrint('⚠️ Intervention: Local notification failed: $e');
      }
      
      return InterventionResult(
        success: true,
        reason: 'In-app notification created',
        channel: InterventionChannel.inApp,
      );
      
    } catch (e) {
      debugPrint('❌ Intervention: In-app error: $e');
      return InterventionResult(success: false, reason: 'In-app error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MESSAGE GENERATION
  // ═══════════════════════════════════════════════════════════════════
  
  /// Generate intervention message using Claude (AI for communication)
  Future<String> _generateInterventionMessage({
    required SafetyEvaluation evaluation,
    required GlucoseContext context,
    required InterventionTone tone,
  }) async {
    try {
      // For critical states, use pre-written medical messages (no AI)
      if (evaluation.state.isCritical) {
        return _generateCriticalMessage(evaluation, context);
      }
      
      // For non-critical, use Claude to generate personalized message
      final prompt = '''
${MedicalSafetyConfig.getMedicalSystemPrompt()}

**TASK**: Generate a brief, actionable health intervention message.

**CONTEXT**:
- Current Glucose: ${context.currentValue.toStringAsFixed(0)} mg/dL ${context.arrow}
- Velocity: ${context.velocity.toStringAsFixed(1)} mg/dL/min
- Predicted (20min): ${context.predicted20min.toStringAsFixed(0)} mg/dL
- Safety State: ${evaluation.state.label}
- Confidence: ${(evaluation.confidence * 100).toStringAsFixed(0)}%

**REASONING**: ${evaluation.reasoning}

**RECOMMENDED ACTIONS**:
${evaluation.recommendedActions.map((a) => '- ${a.description}').join('\n')}

**TONE**: ${tone.promptModifier}

**REQUIREMENTS**:
1. Keep message under 200 characters
2. Be specific and actionable
3. Include the glucose value
4. Suggest ONE primary action
5. Sound encouraging, not alarming (unless critical)
6. ${tone == InterventionTone.humorous || tone == InterventionTone.casual ? 'Use 1-2 emojis' : 'No emojis'}

Generate the message:''';
      
      // Use Claude with medical safety parameters
      // Use generateHealthAwareMealPlan pattern but simpler - directly format prompt for Claude
      final claudeResponse = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': EnvConfig.anthropicApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': EnvConfig.anthropicModel,
          'max_tokens': 2048,
          'temperature': 0.3,
          'system': MedicalSafetyConfig.getMedicalSystemPrompt(),
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );
      
      if (claudeResponse.statusCode != 200) {
        throw Exception('Claude API error: ${claudeResponse.statusCode}');
      }
      
      final responseData = jsonDecode(claudeResponse.body);
      final response = responseData['content'][0]['text'] as String;
      
      return response.trim();
      
    } catch (e) {
      debugPrint('⚠️ Intervention: AI message generation failed: $e');
      
      // Fallback to template-based message
      return _generateTemplateMessage(evaluation, context);
    }
  }
  
  /// Generate critical message (no AI, pre-written medical text)
  String _generateCriticalMessage(SafetyEvaluation evaluation, GlucoseContext context) {
    final glucose = context.currentValue.toStringAsFixed(0);
    
    switch (evaluation.state) {
      case SafetyState.imminentCrash:
        return '🚨 URGENT: Your glucose is ${glucose} mg/dL and dropping fast. '
               'Consume 15g fast-acting carbs NOW (glucose tabs or juice). '
               'Do not ignore this alert.';
      
      case SafetyState.criticalHypoglycemia:
        return '🆘 CRITICAL LOW: Your glucose is ${glucose} mg/dL. '
               'Consume 15g fast-acting carbs immediately. '
               'Retest in 15 minutes. Call for help if needed.';
      
      case SafetyState.severeHyperglycemia:
        return '⚠️ SEVERE HIGH: Your glucose is ${glucose} mg/dL. '
               'Check ketones immediately. Drink water. '
               'Contact your doctor now.';
      
      case SafetyState.criticalHyperglycemia:
        return '⚠️ CRITICAL HIGH: Your glucose is ${glucose} mg/dL. '
               'Drink water and take a gentle 10-minute walk. '
               'Check ketones if you feel unwell.';
      
      default:
        return evaluation.reasoning;
    }
  }
  
  /// Generate template-based message (fallback)
  String _generateTemplateMessage(SafetyEvaluation evaluation, GlucoseContext context) {
    final glucose = context.currentValue.toStringAsFixed(0);
    final action = evaluation.recommendedActions.isNotEmpty
        ? evaluation.recommendedActions.first.description
        : 'Monitor closely';
    
    return '${evaluation.state.emoji} Glucose: ${glucose} mg/dL ${context.arrow}\n$action';
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // NATIVE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Make native voice call (Android/iOS)
  Future<bool> _makeNativeVoiceCall({
    required String phoneNumber,
    required String message,
    required double glucose,
  }) async {
    try {
      final result = await _platform.invokeMethod('makeVoiceCall', {
        'phoneNumber': phoneNumber,
        'message': message,
        'glucose': glucose,
        'isEmergency': true,
      });
      
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('❌ Intervention: Native call failed: $e');
      return false;
    }
  }
  
  /// Send SMS fallback
  Future<InterventionResult> _sendSMSFallback(String phoneNumber, String message) async {
    try {
      final smsUri = Uri.parse('sms:$phoneNumber?body=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return InterventionResult(success: true, reason: 'SMS launched');
      }
      
      return InterventionResult(success: false, reason: 'Cannot send SMS');
    } catch (e) {
      return InterventionResult(success: false, reason: 'SMS error: $e');
    }
  }
  
  /// Alert emergency contact
  Future<void> _alertEmergencyContact(String userId, GlucoseContext context, String message) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final emergencyContact = userDoc.data()?['emergencyContact'] as String?;
      final userName = userDoc.data()?['name'] as String? ?? 'User';
      
      if (emergencyContact == null || emergencyContact.isEmpty) {
        debugPrint('⚠️ Intervention: No emergency contact configured');
        return;
      }
      
      final alertMessage = '🚨 MEDICAL ALERT: $userName\'s glucose is ${context.currentValue.toStringAsFixed(0)} mg/dL '
                          'and requires immediate attention. Please check on them.\n\n'
                          'Details: $message';
      
      debugPrint('📞 Intervention: Alerting emergency contact: $emergencyContact');
      
      // Try GlucoCoach first
      await _glucoCoach.sendProactiveMessage(
      userId: userId,
      message: alertMessage,
    );
      
      // Also try SMS
      await _sendSMSFallback(emergencyContact, alertMessage);
      
    } catch (e) {
      debugPrint('❌ Intervention: Error alerting emergency contact: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // RATE LIMITING & LOGGING
  // ═══════════════════════════════════════════════════════════════════
  
  /// Check if intervention is rate limited
  bool _isRateLimited(String userId, SafetyState state) {
    final key = '${userId}_${state.name}';
    final lastTime = _lastInterventionTime[key];
    
    if (lastTime == null) return false;
    
    final timeSince = DateTime.now().difference(lastTime);
    return timeSince < _minInterventionGap;
  }
  
  /// Log intervention for audit trail
  Future<void> _logIntervention(
    String userId,
    SafetyEvaluation evaluation,
    GlucoseContext context,
    String message,
    InterventionResult result,
  ) async {
    try {
      await _db.collection('users').doc(userId).collection('interventions').add({
        'type': 'automated',
        'safetyState': evaluation.state.name,
        'channel': result.channel?.name,
        'glucose': context.currentValue,
        'velocity': context.velocity,
        'message': message,
        'success': result.success,
        'reason': result.reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Also use existing medical safety audit logging
      MedicalSafetyConfig.logMedicalRecommendation(
        userId: userId,
        operationType: 'intervention_escalation',
        inputData: context.toJson().toString(),
        outputData: message,
        confidence: evaluation.confidence,
        warnings: [],
      );
      
    } catch (e) {
      debugPrint('❌ Intervention: Error logging: $e');
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// INTERVENTION RESULT
/// ═══════════════════════════════════════════════════════════════════

class InterventionResult {
  final bool success;
  final String reason;
  final InterventionChannel? channel;
  
  const InterventionResult({
    required this.success,
    required this.reason,
    this.channel,
  });
}
