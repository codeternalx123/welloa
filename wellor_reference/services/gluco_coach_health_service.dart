import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env_config.dart';

/// 📱 **WHATSAPP HEALTH COACH SERVICE**
/// Premium/Ultra tier feature: 24/7 health alerts and coaching via GlucoCoach
///
/// Features:
/// - Medication reminders
/// - Drug-food interaction warnings
/// - Glucose alerts
/// - Health goal progress updates
/// - Emergency health warnings
/// - Two-way conversational coaching (Premium/Ultra only)
///
/// Integration: GlucoCoach Business API / Twilio

class GlucoCoachHealthService {
  static final GlucoCoachHealthService _instance = GlucoCoachHealthService._internal();
  factory GlucoCoachHealthService() => _instance;
  GlucoCoachHealthService._internal();

  // 🔐 API Configuration
  String get _twilioAccountSid => EnvConfig.get('TWILIO_ACCOUNT_SID');
  String get _twilioAuthToken => EnvConfig.get('TWILIO_AUTH_TOKEN');
  String get _twilioGlucoCoachNumber => EnvConfig.get('TWILIO_WHATSAPP_NUMBER', defaultValue: 'glucoCoach:+14155238886'); // Twilio Sandbox

  bool get isAvailable => _twilioAccountSid.isNotEmpty && _twilioAuthToken.isNotEmpty;

  // ============================================================================
  // MEDICATION ALERTS
  // ============================================================================

  /// Send medication reminder via GlucoCoach
  Future<bool> sendMedicationReminder({
    required String userPhoneNumber,
    required String medicationName,
    required String dosage,
    required String time,
    bool takeWithFood = false,
  }) async {
    if (!isAvailable) {
      debugPrint('❌ GlucoCoach service not configured');
      return false;
    }

    final message = '''
💊 *Medication Reminder*

Time to take your medication:
📋 ${medicationName}
💉 Dosage: ${dosage}
⏰ Scheduled: ${time}
${takeWithFood ? '🍽️ Take with food' : ''}

Reply "TAKEN" when you've taken your medication.
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  /// Send drug-food interaction warning
  Future<bool> sendDrugFoodInteractionWarning({
    required String userPhoneNumber,
    required String medicationName,
    required String foodIngredient,
    required String severity,
    required String warning,
    required String recommendation,
  }) async {
    if (!isAvailable) {
      debugPrint('❌ GlucoCoach service not configured');
      return false;
    }

    final emoji = severity == 'critical' ? '🚨' : severity == 'major' ? '⚠️' : '⚡';

    final message = '''
$emoji *DRUG-FOOD INTERACTION ALERT*

Medication: *${medicationName}*
Food Detected: *${foodIngredient}*
Severity: *${severity.toUpperCase()}*

⚠️ Warning:
${warning}

✅ Recommendation:
${recommendation}

Your health and safety is our priority. Please follow the recommendation above.
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  /// Send missed medication alert
  Future<bool> sendMissedMedicationAlert({
    required String userPhoneNumber,
    required String medicationName,
    required String missedTime,
  }) async {
    if (!isAvailable) return false;

    final message = '''
⏰ *Missed Medication Alert*

You missed your scheduled dose:
💊 ${medicationName}
🕐 Scheduled time: ${missedTime}

If you haven't taken it yet, please take it now (unless instructed otherwise by your doctor).

Reply "TAKEN" if you've already taken it, or "SKIP" if you're skipping this dose.
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  // ============================================================================
  // GLUCOSE ALERTS
  // ============================================================================

  /// Send low blood sugar alert
  Future<bool> sendLowGlucoseAlert({
    required String userPhoneNumber,
    required double glucoseLevel,
  }) async {
    if (!isAvailable) return false;

    final message = '''
🚨 *LOW BLOOD SUGAR ALERT*

Your glucose level is critically low:
📊 ${glucoseLevel.toStringAsFixed(0)} mg/dL

⚡ IMMEDIATE ACTION REQUIRED:
1. Consume 15g fast-acting carbs (4oz juice, 3-4 glucose tablets)
2. Wait 15 minutes
3. Recheck glucose level
4. If still below 70, repeat step 1

Reply "OK" when you've taken action.
Call emergency services if you feel faint or confused.
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  /// Send high blood sugar alert
  Future<bool> sendHighGlucoseAlert({
    required String userPhoneNumber,
    required double glucoseLevel,
    bool isCritical = false,
  }) async {
    if (!isAvailable) return false;

    final emoji = isCritical ? '🚨' : '⚠️';
    final urgency = isCritical ? 'CRITICAL' : 'WARNING';

    final message = '''
$emoji *HIGH BLOOD SUGAR $urgency*

Your glucose level is elevated:
📊 ${glucoseLevel.toStringAsFixed(0)} mg/dL

${isCritical ? '🚨 This is a medical emergency. Contact your doctor immediately.\n' : ''}
✅ Recommended Actions:
• Avoid additional carbohydrates
• Drink plenty of water
• Check ketones if over 250 mg/dL
• Contact doctor if over 300 mg/dL for 2+ hours
${isCritical ? '• Go to ER if over 400 mg/dL or experiencing symptoms' : ''}

Reply "OK" to acknowledge.
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  // ============================================================================
  // HEALTH GOALS & COACHING
  // ============================================================================

  /// Send goal milestone celebration
  Future<bool> sendGoalMilestone({
    required String userPhoneNumber,
    required String goalTitle,
    required int milestone,
    required int totalMilestones,
  }) async {
    if (!isAvailable) return false;

    final message = '''
🎉 *Milestone Achieved!*

Congratulations on reaching milestone ${milestone}/${totalMilestones}!

Goal: *${goalTitle}*

Keep up the amazing work! You're making incredible progress toward your health goals. 💪

Your AI Health Team is here to support you every step of the way.
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  /// Send daily health summary (Ultra tier)
  Future<bool> sendDailyHealthSummary({
    required String userPhoneNumber,
    required Map<String, dynamic> summary,
  }) async {
    if (!isAvailable) return false;

    final message = '''
🌅 *Daily Health Summary*

${DateTime.now().toString().split(' ')[0]}

📊 Today's Stats:
• Scans: ${summary['scans'] ?? 0}
• Calories: ${summary['calories'] ?? 0} kcal
• Steps: ${summary['steps'] ?? 0}
• Sleep: ${summary['sleep'] ?? '—'} hours

💊 Medications:
• Adherence: ${summary['medicationAdherence'] ?? 100}%
${summary['missedMeds'] ?? 0 > 0 ? '• Missed: ${summary['missedMeds']} doses' : '✅ All medications taken'}

🎯 Active Goals:
${summary['activeGoals'] ?? 'No active goals'}

${summary['aiInsight'] ?? ''}

Have a healthy day! 🌟
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  /// Send personalized health coaching message
  Future<bool> sendHealthCoachingMessage({
    required String userPhoneNumber,
    required String coachingMessage,
    String? actionItems,
  }) async {
    if (!isAvailable) return false;

    final message = '''
🤖 *Your AI Health Coach*

${coachingMessage}

${actionItems != null ? '\n📋 Action Items:\n${actionItems}' : ''}

Reply with questions anytime - I'm here 24/7! 💙
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );
  }

  // ============================================================================
  // GENERAL HEALTH ALERTS
  // ============================================================================

  /// Send general health alert
  Future<bool> sendHealthAlert({
    required String userPhoneNumber,
    required String title,
    required String message,
    required String severity, // info, warning, urgent, critical
  }) async {
    if (!isAvailable) return false;

    final emoji = severity == 'critical'
        ? '🚨'
        : severity == 'urgent'
            ? '⚠️'
            : severity == 'warning'
                ? '⚡'
                : 'ℹ️';

    final formattedMessage = '''
$emoji *${title}*

${message}

—
Your AI Health Team
Wellor Premium
''';

    return await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: formattedMessage,
    );
  }

  // ============================================================================
  // EMERGENCY ALERTS
  // ============================================================================

  /// Send emergency health warning (with doctor/emergency contact notification)
  Future<bool> sendEmergencyAlert({
    required String userPhoneNumber,
    required String emergencyType,
    required String details,
    String? emergencyContactPhone,
  }) async {
    if (!isAvailable) return false;

    final message = '''
🚨 *EMERGENCY HEALTH ALERT*

Type: *${emergencyType}*

${details}

⚠️ IMMEDIATE ACTION REQUIRED ⚠️

This is a medical emergency. Please:
1. Call emergency services (911) immediately
2. Do NOT ignore this alert
3. Inform someone nearby

${emergencyContactPhone != null ? 'Your emergency contact has been notified.' : ''}

Your location and health data have been prepared for emergency responders.
''';

    // Send to user
    final userNotified = await _sendGlucoCoachMessage(
      to: userPhoneNumber,
      message: message,
    );

    // Notify emergency contact if available
    if (emergencyContactPhone != null && userNotified) {
      await _sendGlucoCoachMessage(
        to: emergencyContactPhone,
        message: '''
🚨 *EMERGENCY CONTACT ALERT*

${userPhoneNumber.replaceAll('glucoCoach:', '')} (Wellor user) has triggered an emergency health alert.

Type: ${emergencyType}
Time: ${DateTime.now().toString()}

Please check on them immediately or contact emergency services if you cannot reach them.

This is an automated alert from the Wellor AI Health Team.
''',
      );
    }

    return userNotified;
  }

  // ============================================================================
  // CORE MESSAGING
  // ============================================================================

  /// Send GlucoCoach message via Twilio API
  Future<bool> _sendGlucoCoachMessage({
    required String to,
    required String message,
  }) async {
    try {
      // Ensure phone number has glucoCoach: prefix
      final formattedTo = to.startsWith('glucoCoach:') ? to : 'glucoCoach:$to';

      final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': _twilioGlucoCoachNumber,
          'To': formattedTo,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        debugPrint('✅ GlucoCoach message sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send GlucoCoach message: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending GlucoCoach message: $e');
      return false;
    }
  }

  // ============================================================================
  // USER PREFERENCES
  // ============================================================================

  /// Check if user has GlucoCoach notifications enabled
  Future<bool> isGlucoCoachEnabledForUser(String userId) async {
    // TODO: Check Firestore user preferences
    return true; // Default to enabled for Premium/Ultra users
  }

  /// Get user's GlucoCoach number from profile
  Future<String?> getUserGlucoCoachNumber(String userId) async {
    // TODO: Fetch from Firestore user profile
    return null; // Return stored GlucoCoach number
  }
}
