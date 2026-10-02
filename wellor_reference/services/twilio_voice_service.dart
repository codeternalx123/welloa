// lib/services/twilio_voice_service.dart
// TWILIO VOICE SERVICE: Outbound clinical voice calls via Twilio Programmable Voice
//
// Production path:
//   Sentinel detects critical anomaly
//       ↓
//   VoiceAlertSentinel evaluates severity → builds spoken script
//       ↓
//   TwilioVoiceService.createCall() → Twilio Calls API with inline TwiML
//       ↓
//   Twilio places the call and reads the alert via text-to-speech

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/env_config.dart';

// ═══════════════════════════════════════════════════════════════════
// VOICE CALL RESULT
// ═══════════════════════════════════════════════════════════════════

class VoiceCallResult {
  final bool success;
  final String? callId;
  final String? callStatus;
  final String? agentId;
  final String? error;
  final DateTime timestamp;

  VoiceCallResult({
    required this.success,
    this.callId,
    this.callStatus,
    this.agentId,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'success': success,
    'callId': callId,
    'callStatus': callStatus,
    'agentId': agentId,
    'error': error,
    'timestamp': timestamp.toIso8601String(),
  };
}

// ═══════════════════════════════════════════════════════════════════
// VOICE CALL REQUEST — Describes what to say to the patient
// ═══════════════════════════════════════════════════════════════════

class VoiceCallRequest {
  final String userId;
  final String toNumber;           // Patient's phone (E.164)
  final String patientName;
  final String anomalyType;        // HYPOGLYCEMIA, HYPERGLYCEMIA, etc.
  final String severity;           // critical, urgent
  final double? glucoseLevel;
  final double? glucoseVelocity;
  final List<String> conditions;   // diabetes, hypertension, etc.
  final List<String> actionItems;  // Specific instructions
  final String? traceId;
  final Map<String, dynamic> extraContext; // HR, SpO2, temp, etc.

  VoiceCallRequest({
    required this.userId,
    required this.toNumber,
    required this.patientName,
    required this.anomalyType,
    required this.severity,
    this.glucoseLevel,
    this.glucoseVelocity,
    this.conditions = const [],
    this.actionItems = const [],
    this.traceId,
    this.extraContext = const {},
  });
}

// ═══════════════════════════════════════════════════════════════════
// TWILIO VOICE SERVICE — Singleton API client
// ═══════════════════════════════════════════════════════════════════

class TwilioVoiceService {
  static final TwilioVoiceService _instance = TwilioVoiceService._internal();
  factory TwilioVoiceService() => _instance;
  TwilioVoiceService._internal();

  String get _accountSid => EnvConfig.get('TWILIO_ACCOUNT_SID');
  String get _authToken => EnvConfig.get('TWILIO_AUTH_TOKEN');
  String get _fromNumber => EnvConfig.get('TWILIO_PHONE_NUMBER');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if Twilio voice calling is configured.
  bool get isConfigured =>
      _accountSid.isNotEmpty && _authToken.isNotEmpty && _fromNumber.isNotEmpty;

  String get _basicAuth =>
      'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}';

  // ═══════════════════════════════════════════════════════════════════
  // CREATE OUTBOUND CALL
  // ═══════════════════════════════════════════════════════════════════

  /// Initiate an outbound voice call via Twilio.
  /// The alert is spoken with Twilio text-to-speech (Amazon Polly neural voice).
  Future<VoiceCallResult> createCall(VoiceCallRequest request) async {
    if (!isConfigured) {
      debugPrint('📞 TwilioVoice: Not configured (missing Twilio credentials)');
      return VoiceCallResult(
        success: false,
        error: 'Twilio voice calling not configured',
      );
    }

    final cleanTo = _sanitizePhone(request.toNumber);
    if (cleanTo == null) {
      debugPrint('📞 TwilioVoice: Invalid phone number: ${request.toNumber}');
      return VoiceCallResult(success: false, error: 'Invalid phone number');
    }

    try {
      final twiml = _buildTwiml(request);

      debugPrint('📞 TwilioVoice: Initiating ${request.severity} call to '
          '${request.patientName} (${request.anomalyType}, '
          'glucose: ${request.glucoseLevel?.toStringAsFixed(0) ?? "N/A"})');

      final response = await http.post(
        Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Calls.json',
        ),
        headers: {'Authorization': _basicAuth},
        body: {
          'From': _fromNumber,
          'To': cleanTo,
          'Twiml': twiml,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final callId = data['sid'] as String?;
        final callStatus = data['status'] as String?;

        debugPrint('📞 TwilioVoice: Call initiated — callId=$callId, status=$callStatus');

        await _logCallInitiated(request, callId, callStatus);

        return VoiceCallResult(
          success: true,
          callId: callId,
          callStatus: callStatus,
        );
      } else {
        debugPrint('📞 TwilioVoice: API error ${response.statusCode}: ${response.body}');
        return VoiceCallResult(
          success: false,
          error: 'Twilio API ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('📞 TwilioVoice: Call creation error: $e');
      return VoiceCallResult(success: false, error: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // TWIML BUILDER — Turns the request into a spoken alert script
  // ═══════════════════════════════════════════════════════════════════

  String _buildTwiml(VoiceCallRequest request) {
    final callReason = _getCallReason(request.anomalyType, request.glucoseLevel);
    final actionScript = request.actionItems.isNotEmpty
        ? request.actionItems.asMap().entries
            .map((e) => 'Step ${e.key + 1}. ${e.value}')
            .join(' ')
        : _getDefaultActionItems(request.anomalyType);

    String glucoseContext = '';
    if (request.glucoseLevel != null) {
      final level = request.glucoseLevel!.toStringAsFixed(0);
      final velocityStr = request.glucoseVelocity != null
          ? ' and ${request.glucoseVelocity! > 0 ? "rising" : "falling"} at '
            '${request.glucoseVelocity!.abs().toStringAsFixed(1)} milligrams per deciliter per minute'
          : '';
      glucoseContext =
          'Your current glucose reading is $level milligrams per deciliter$velocityStr.';
    }

    final vitalsLines = <String>[];
    if (request.extraContext.containsKey('heartRate')) {
      vitalsLines.add('Your heart rate is ${request.extraContext['heartRate']} beats per minute.');
    }
    if (request.extraContext.containsKey('bloodOxygen')) {
      vitalsLines.add('Your blood oxygen is ${request.extraContext['bloodOxygen']} percent.');
    }
    if (request.extraContext.containsKey('bodyTemperature')) {
      vitalsLines.add('Your temperature is ${request.extraContext['bodyTemperature']} degrees Celsius.');
    }
    if (request.extraContext.containsKey('bloodPressure')) {
      vitalsLines.add('Your blood pressure is ${request.extraContext['bloodPressure']}.');
    }
    final vitalsContext = vitalsLines.join(' ');

    final urgencyIntro = request.severity == 'critical'
        ? 'This is a critical health alert that requires your immediate attention.'
        : 'This is an urgent health alert.';

    final script = _escapeXml(
      'Hello ${request.patientName}. This is Wellor Health calling. '
      '$urgencyIntro '
      '$callReason '
      '$glucoseContext '
      '$vitalsContext '
      'Here is what you should do. $actionScript '
      'If your symptoms worsen or you feel unsafe, call emergency services immediately.',
    );

    const voice = 'Polly.Joanna-Neural';

    return '''
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="$voice">$script</Say>
    <Pause length="1"/>
    <Say voice="$voice">I will now repeat the key instructions. ${_escapeXml(actionScript)}</Say>
    <Pause length="1"/>
    <Say voice="$voice">Please open the Wellor app for more details. Stay safe. Goodbye.</Say>
</Response>
''';
  }

  String _escapeXml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Build a clear, patient-facing explanation of why we're calling.
  String _getCallReason(String anomalyType, double? glucose) {
    switch (anomalyType) {
      case 'HYPOGLYCEMIA':
        return 'Your blood sugar has dropped to a dangerously low level of '
            '${glucose?.toStringAsFixed(0) ?? "below 70"} milligrams per deciliter. '
            'This requires immediate attention.';
      case 'HYPERGLYCEMIA':
        return 'Your blood sugar has risen to ${glucose?.toStringAsFixed(0) ?? "above 250"} '
            'milligrams per deciliter, which is dangerously high. We need to take action now.';
      case 'RAPID_DROP':
        return 'Your blood sugar is dropping rapidly. This could lead to a '
            'low blood sugar event if not addressed.';
      case 'ACTIVE_SPIKE':
        return 'Your blood sugar is spiking rapidly and is already elevated. '
            'Let us take steps to bring it under control.';
      case 'vitals_hr_high':
        return 'Your heart rate is elevated beyond safe thresholds. '
            'We want to make sure you are okay.';
      case 'vitals_spo2_low':
        return 'Your blood oxygen level has dropped below 92 percent. '
            'This needs immediate attention.';
      case 'vitals_temp_elevated':
        return 'Your body temperature is elevated, indicating a possible fever. '
            'Combined with your conditions, this needs monitoring.';
      case 'vitals_bp_high':
        return 'Your blood pressure reading is concerning. '
            'Let us discuss what you should do.';
      default:
        return 'We have detected a health reading that needs your attention.';
    }
  }

  /// Default action items when none are explicitly provided.
  String _getDefaultActionItems(String anomalyType) {
    switch (anomalyType) {
      case 'HYPOGLYCEMIA':
        return 'Step 1. Eat or drink 15 grams of fast-acting carbohydrates immediately, '
            'like 4 glucose tablets, half a cup of juice, or a tablespoon of honey. '
            'Step 2. Wait 15 minutes and check your blood sugar again. '
            'Step 3. If still below 70, repeat step 1. '
            'Step 4. Once stable, eat a small snack with protein. '
            'Step 5. If you feel dizzy or confused, call emergency services.';
      case 'HYPERGLYCEMIA':
        return 'Step 1. Check for ketones if you have test strips. '
            'Step 2. Drink plenty of water to stay hydrated. '
            'Step 3. Follow your sick-day insulin protocol if you have one. '
            'Step 4. Avoid eating high-carb foods. '
            'Step 5. If ketones are moderate to large, or you feel nauseous, seek medical help.';
      case 'RAPID_DROP':
        return 'Step 1. Stop any physical activity immediately. '
            'Step 2. Have a fast-acting sugar source ready. '
            'Step 3. Sit or lie down in a safe place. '
            'Step 4. Check your blood sugar again in 10 minutes. '
            'Step 5. If it drops below 70, follow the low blood sugar protocol.';
      case 'ACTIVE_SPIKE':
        return 'Step 1. Avoid eating anything sugary or high-carb right now. '
            'Step 2. If safe, take a 10 to 15 minute walk to help lower it. '
            'Step 3. Drink a glass of water. '
            'Step 4. Check your blood sugar in 30 minutes. '
            'Step 5. Follow your prescribed correction dose if applicable.';
      case 'vitals_spo2_low':
        return 'Step 1. Sit upright and take slow, deep breaths. '
            'Step 2. If you have a prescribed inhaler, use it now. '
            'Step 3. Open a window for fresh air. '
            'Step 4. If oxygen stays below 90 percent, call emergency services immediately.';
      default:
        return 'Step 1. Stay calm and monitor how you feel. '
            'Step 2. Check your readings again in 15 minutes. '
            'Step 3. If symptoms worsen, contact your healthcare provider.';
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // CALL STATUS
  // ═══════════════════════════════════════════════════════════════════

  /// Retrieve call details from the local Firestore log.
  Future<Map<String, dynamic>?> getCallDetails(String callId) async {
    try {
      final snapshot = await _db
          .collection('voice_call_logs')
          .where('callId', isEqualTo: callId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('📞 TwilioVoice: Get call details error: $e');
      return null;
    }
  }

  /// Check live call status directly with the Twilio API.
  Future<String?> checkCallStatus(String callSid) async {
    if (!isConfigured) return null;

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Calls/$callSid.json',
        ),
        headers: {'Authorization': _basicAuth},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('📞 TwilioVoice: Status check error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // FIRESTORE LOGGING
  // ═══════════════════════════════════════════════════════════════════

  /// Log call initiation to Firestore for history and analytics.
  Future<void> _logCallInitiated(
      VoiceCallRequest request, String? callId, String? status) async {
    try {
      await _db.collection('voice_call_logs').add({
        'callId': callId,
        'userId': request.userId,
        'toNumber': request.toNumber,
        'patientName': request.patientName,
        'anomalyType': request.anomalyType,
        'severity': request.severity,
        'glucoseLevel': request.glucoseLevel,
        'glucoseVelocity': request.glucoseVelocity,
        'conditions': request.conditions,
        'actionItems': request.actionItems,
        'callStatus': status,
        'traceId': request.traceId,
        'extraContext': request.extraContext,
        'provider': 'twilio',
        'source': 'Wellor_sentinel',
        'initiatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('📞 TwilioVoice: Error logging call: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHONE SANITIZATION
  // ═══════════════════════════════════════════════════════════════════

  /// Sanitize phone to E.164 format for the Twilio API.
  String? _sanitizePhone(String phone) {
    var clean = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (!clean.startsWith('+')) {
      clean = '+$clean';
    }

    final digits = clean.replaceAll('+', '');
    if (digits.length < 10 || digits.length > 15) return null;

    return clean;
  }
}
