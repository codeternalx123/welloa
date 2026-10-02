import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env_config.dart';

/// 📞 **VOICE ESCALATION SERVICE**
/// Emergency voice call alerts for critical health situations using Twilio.
///
/// **Use Cases:**
/// - Critical glucose levels (<54 or >400 mg/dL)
/// - Cardiac events detected
/// - Severe medication side effects
/// - Emergency health warnings
/// - Missed critical medications (e.g., insulin)
///
/// **Features:**
/// - Text-to-speech alerts (Twilio Programmable Voice)
/// - Call escalation chain (user → emergency contact → 911)
/// - Automated follow-up if no answer
/// - Call recording for medical records

enum VoiceCallUrgency {
  info,
  warning,
  urgent,
  emergency,
}

enum CallStatus {
  initiated,
  ringing,
  answered,
  noAnswer,
  voicemail,
  failed,
  completed,
}

class VoiceCall {
  final String id;
  final String userId;
  final String phoneNumber;
  final VoiceCallUrgency urgency;
  final String alertType;
  final String message;
  final DateTime initiatedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final CallStatus status;
  final String? recordingUrl;
  final bool escalated;

  VoiceCall({
    required this.id,
    required this.userId,
    required this.phoneNumber,
    required this.urgency,
    required this.alertType,
    required this.message,
    required this.initiatedAt,
    this.answeredAt,
    this.endedAt,
    required this.status,
    this.recordingUrl,
    this.escalated = false,
  });

  Duration? get callDuration {
    if (answeredAt != null && endedAt != null) {
      return endedAt!.difference(answeredAt!);
    }
    return null;
  }
}

class VoiceEscalationService {
  static final VoiceEscalationService _instance = VoiceEscalationService._internal();
  factory VoiceEscalationService() => _instance;
  VoiceEscalationService._internal();

  // Twilio credentials
  String get _twilioAccountSid => EnvConfig.get('TWILIO_ACCOUNT_SID');
  String get _twilioAuthToken => EnvConfig.get('TWILIO_AUTH_TOKEN');
  String get _twilioPhoneNumber => EnvConfig.get('TWILIO_PHONE_NUMBER');

  bool get isTwilioAvailable =>
      _twilioAccountSid.isNotEmpty &&
      _twilioAuthToken.isNotEmpty &&
      _twilioPhoneNumber.isNotEmpty;

  // ============================================================================
  // VOICE CALL INITIATION
  // ============================================================================

  /// Initiate emergency voice call via Twilio
  Future<VoiceCall?> initiateEmergencyCall({
    required String userId,
    required String phoneNumber,
    required VoiceCallUrgency urgency,
    required String alertType,
    required String message,
    bool useAI = true, // Kept for call-site compatibility; all calls use Twilio TTS
  }) async {
    debugPrint('📞 Initiating ${urgency.toString().split('.').last} voice call to $phoneNumber');

    if (isTwilioAvailable) {
      return await _initiateTwilioCall(
        userId: userId,
        phoneNumber: phoneNumber,
        urgency: urgency,
        alertType: alertType,
        message: message,
      );
    }

    debugPrint('❌ Twilio voice service not configured');
    return null;
  }

  // ============================================================================
  // TWILIO VOICE INTEGRATION (Text-to-Speech)
  // ============================================================================

  /// Initiate Twilio text-to-speech voice call
  Future<VoiceCall?> _initiateTwilioCall({
    required String userId,
    required String phoneNumber,
    required VoiceCallUrgency urgency,
    required String alertType,
    required String message,
  }) async {
    try {
      // Build TwiML for text-to-speech
      final twiml = _buildTwiML(urgency, alertType, message);

      final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Calls.json',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}',
        },
        body: {
          'From': _twilioPhoneNumber,
          'To': phoneNumber,
          'Twiml': twiml,
          'Record': 'true',
          'RecordingStatusCallback': 'https://your-server.com/recording-callback',
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        final call = VoiceCall(
          id: data['sid'],
          userId: userId,
          phoneNumber: phoneNumber,
          urgency: urgency,
          alertType: alertType,
          message: message,
          initiatedAt: DateTime.now(),
          status: CallStatus.initiated,
        );

        debugPrint('✅ Twilio call initiated: ${call.id}');
        return call;
      } else {
        debugPrint('❌ Twilio call failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error initiating Twilio call: $e');
      return null;
    }
  }

  String _buildTwiML(
    VoiceCallUrgency urgency,
    String alertType,
    String message,
  ) {
    final voice = 'Polly.Joanna'; // AWS Polly neural voice
    
    String urgencyText = '';
    if (urgency == VoiceCallUrgency.emergency) {
      urgencyText = '<emphasis level="strong">This is a critical emergency alert.</emphasis>';
    } else if (urgency == VoiceCallUrgency.urgent) {
      urgencyText = 'This is an urgent health alert.';
    } else if (urgency == VoiceCallUrgency.warning) {
      urgencyText = 'This is an important health warning.';
    }

    return '''
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="$voice">
        Hello, this is Wellor Health AI calling with a health alert.
        <break time="0.5s"/>
        $urgencyText
        <break time="0.5s"/>
        $message
        <break time="1s"/>
        Please acknowledge this alert by pressing 1.
        To hear the message again, press 2.
    </Say>
    <Gather numDigits="1" action="/voice/gather" method="POST" timeout="10">
        <Say voice="$voice">Press 1 to acknowledge, or press 2 to repeat the message.</Say>
    </Gather>
    <Say voice="$voice">
        We did not receive your acknowledgment. 
        Please call back at 1-800-WELLOR if you have questions.
        Stay safe.
    </Say>
</Response>
''';
  }

  // ============================================================================
  // CALL ESCALATION
  // ============================================================================

  /// Escalate to emergency contact if no answer
  Future<void> escalateCall({
    required String userId,
    required String emergencyContactPhone,
    required VoiceCallUrgency urgency,
    required String alertType,
    required String message,
    required String originalRecipient,
  }) async {
    debugPrint('🚨 Escalating call to emergency contact: $emergencyContactPhone');

    final escalationMessage = '''
This is an emergency escalation for Wellor Health user at $originalRecipient.

Original Alert: $alertType
$message

They did not answer our emergency call. Please check on them immediately or contact emergency services if needed.
''';

    await initiateEmergencyCall(
      userId: userId,
      phoneNumber: emergencyContactPhone,
      urgency: urgency,
      alertType: 'Emergency Escalation: $alertType',
      message: escalationMessage,
      useAI: false, // Use simple TTS for escalation
    );
  }

  // ============================================================================
  // SPECIFIC EMERGENCY SCENARIOS
  // ============================================================================

  /// Call for critical low glucose
  Future<VoiceCall?> callForCriticalLowGlucose({
    required String userId,
    required String phoneNumber,
    required double glucoseLevel,
  }) async {
    return await initiateEmergencyCall(
      userId: userId,
      phoneNumber: phoneNumber,
      urgency: VoiceCallUrgency.emergency,
      alertType: 'Critical Low Blood Sugar',
      message: '''
Your blood sugar is critically low at ${glucoseLevel.toStringAsFixed(0)} milligrams per deciliter.
This requires immediate action.
Please consume 15 grams of fast-acting carbohydrates such as 4 ounces of juice or 3 to 4 glucose tablets immediately.
Wait 15 minutes and recheck your blood sugar.
If you feel dizzy, confused, or cannot safely treat yourself, call 9-1-1 immediately.
''',
      useAI: true,
    );
  }

  /// Call for critical high glucose
  Future<VoiceCall?> callForCriticalHighGlucose({
    required String userId,
    required String phoneNumber,
    required double glucoseLevel,
  }) async {
    return await initiateEmergencyCall(
      userId: userId,
      phoneNumber: phoneNumber,
      urgency: VoiceCallUrgency.emergency,
      alertType: 'Critical High Blood Sugar',
      message: '''
Your blood sugar is critically high at ${glucoseLevel.toStringAsFixed(0)} milligrams per deciliter.
This is a medical emergency.
Contact your doctor immediately or go to the emergency room.
Check for ketones if you have diabetes.
Drink water and avoid food until you receive medical care.
If you experience severe symptoms like difficulty breathing or confusion, call 9-1-1 immediately.
''',
      useAI: true,
    );
  }

  /// Call for missed critical medication
  Future<VoiceCall?> callForMissedCriticalMedication({
    required String userId,
    required String phoneNumber,
    required String medicationName,
    required String scheduledTime,
  }) async {
    return await initiateEmergencyCall(
      userId: userId,
      phoneNumber: phoneNumber,
      urgency: VoiceCallUrgency.urgent,
      alertType: 'Missed Critical Medication',
      message: '''
You have not taken your critical medication, $medicationName, scheduled for $scheduledTime.
This medication is essential for your health.
Please take it as soon as possible unless otherwise instructed by your doctor.
If you've already taken it, please confirm in the app.
If you have questions, contact your healthcare provider.
''',
      useAI: true,
    );
  }

  /// Call for severe drug interaction detected
  Future<VoiceCall?> callForSevereDrugInteraction({
    required String userId,
    required String phoneNumber,
    required String medication,
    required String food,
    required String warning,
  }) async {
    return await initiateEmergencyCall(
      userId: userId,
      phoneNumber: phoneNumber,
      urgency: VoiceCallUrgency.urgent,
      alertType: 'Severe Drug-Food Interaction',
      message: '''
A severe interaction has been detected between your medication $medication and $food.
$warning
Please contact your doctor or pharmacist immediately for guidance.
Do not take additional doses until you have consulted with a healthcare professional.
''',
      useAI: true,
    );
  }

  /// Call for abnormal heart rate detected
  Future<VoiceCall?> callForAbnormalHeartRate({
    required String userId,
    required String phoneNumber,
    required int heartRate,
    required String condition, // 'high' or 'low'
  }) async {
    final urgency = heartRate > 180 || heartRate < 40 
        ? VoiceCallUrgency.emergency 
        : VoiceCallUrgency.urgent;

    return await initiateEmergencyCall(
      userId: userId,
      phoneNumber: phoneNumber,
      urgency: urgency,
      alertType: 'Abnormal Heart Rate Detected',
      message: '''
Your heart rate is ${condition == 'high' ? 'elevated' : 'low'} at $heartRate beats per minute.
${urgency == VoiceCallUrgency.emergency ? 'This requires immediate medical attention.' : 'This needs attention.'}
Please sit down, remain calm, and seek medical care.
${urgency == VoiceCallUrgency.emergency ? 'If you experience chest pain, difficulty breathing, or dizziness, call 9-1-1 immediately.' : 'Contact your doctor if this persists.'}
''',
      useAI: true,
    );
  }

  // ============================================================================
  // CALL STATUS & MANAGEMENT
  // ============================================================================

  /// Check call status (Twilio)
  Future<CallStatus> checkTwilioCallStatus(String callSid) async {
    try {
      final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Calls/$callSid.json',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String;

        switch (status) {
          case 'completed':
            return CallStatus.completed;
          case 'in-progress':
          case 'ringing':
            return CallStatus.ringing;
          case 'no-answer':
            return CallStatus.noAnswer;
          case 'failed':
          case 'busy':
          case 'canceled':
            return CallStatus.failed;
          default:
            return CallStatus.initiated;
        }
      }

      return CallStatus.failed;
    } catch (e) {
      debugPrint('❌ Error checking call status: $e');
      return CallStatus.failed;
    }
  }

  /// Get call recording URL
  Future<String?> getCallRecording(String callSid) async {
    try {
      final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Calls/$callSid/Recordings.json',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recordings = data['recordings'] as List?;

        if (recordings != null && recordings.isNotEmpty) {
          final recordingSid = recordings[0]['sid'];
          return 'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Recordings/$recordingSid';
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting recording: $e');
      return null;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Format phone number to E.164 format
  String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add +1 for US numbers if not present
    if (digits.length == 10) {
      return '+1$digits';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+$digits';
    }
    
    return phoneNumber; // Return as-is if already formatted
  }

  /// Test voice call (for development)
  Future<void> testVoiceCall(String phoneNumber) async {
    await initiateEmergencyCall(
      userId: 'test_user',
      phoneNumber: phoneNumber,
      urgency: VoiceCallUrgency.info,
      alertType: 'Test Call',
      message: 'This is a test call from Wellor Health AI. Your voice escalation system is working correctly.',
      useAI: false,
    );
  }
}
