// lib/services/background_agent_service.dart
// 24/7 AI Health Monitoring Service
// Monitors glucose, sleep, hydration, activity, and provides proactive
// GlucoCoaching around the clock — all in pure Flutter/Dart.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'gluco_coach_ai_service.dart';
import 'gluco_coach_ai_service.dart';
import 'gemini_agent_pipeline.dart';
import 'multi_agent_system.dart';
import 'subscription_entitlement_resolver.dart';
import 'gluco_coach_context_service.dart';
import '../models/health_profile.dart';

Future<String> _glucoCoachCoachReply(
  String prompt, {
  double temperature = 0.7,
  int maxTokens = 400,
}) {
  return GlucoCoachAIService().generateReply(
    userPrompt: prompt,
    temperature: temperature,
    maxTokens: maxTokens,
  );
}

// ═══════════════════════════════════════════════════════════════════
// USER-FRIENDLY TASK NAMES & NOTIFICATION HELPERS
// ═══════════════════════════════════════════════════════════════════

/// Maps internal task identifiers to user-friendly display names.
const Map<String, String> _taskFriendlyNames = {
  taskGlucoseWatch: 'Glucose Monitor',
};

const Map<String, String> _taskEmojis = {
  taskGlucoseWatch: '\uD83D\uDCCA',      // 📊
};

/// Background tasks are GlucoCoach-only. Local completion notifications are disabled
/// to avoid noisy Workmanager/task metadata surfacing to the user.
Future<void> _showTaskNotification({
  required String taskName,
  required String summary,
  required Duration elapsed,
}) async {
  return;
}

// ═══════════════════════════════════════════════════════════════════
// TASK IDENTIFIERS — 8 background tasks for 24/7 coverage
// ═══════════════════════════════════════════════════════════════════

const String taskGlucoseWatch = 'health_agent_glucose_watch';

// ═══════════════════════════════════════════════════════════════════
// TOP-LEVEL CALLBACK DISPATCHER
// ═══════════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final stopwatch = Stopwatch()..start();
    final friendly = _taskFriendlyNames[taskName] ?? taskName;

    try {
      await Firebase.initializeApp();
      await Hive.initFlutter();

      String? resultSummary;

      switch (taskName) {
        case taskGlucoseWatch:
          resultSummary = await _executeGlucoseWatch();
          break;
        default:
          debugPrint('🤖 Background: Unknown task: $taskName');
      }

      stopwatch.stop();

      debugPrint('✅ $friendly completed in ${stopwatch.elapsedMilliseconds}ms'
          '${resultSummary != null ? ' — $resultSummary' : ' — no critical event'}');

      return true;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ $friendly failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      return false;
    }
  });
}

// ═══════════════════════════════════════════════════════════════════
// SINGLE-USER HELPER — Only monitors the authenticated device owner
// ═══════════════════════════════════════════════════════════════════

/// Fetches the currently authenticated user's profile from Firestore.
/// Returns null if not logged in or user document not found.
/// All background tasks use this instead of querying all users.
Future<({String userId, Map<String, dynamic> data})?> _getCurrentUser() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    debugPrint('🔒 Background: No authenticated user — skipping task');
    return null;
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  if (!doc.exists) {
    debugPrint('🔒 Background: User document not found for $uid');
    return null;
  }

  return (userId: uid, data: doc.data()!);
}

Future<bool> _requiresGlucoCoachCoach(String userId) async {
  final entitled =
      await SubscriptionEntitlementResolver.instance.hasGlucoCoach(userId);
  if (!entitled) {
    debugPrint('💬 Background: Skipping — Premium+ GlucoCoach required');
  }
  return entitled;
}

// ═══════════════════════════════════════════════════════════════════
// 1. MORNING CHECK-IN (7 AM local)
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeMorningCheckin() async {
  debugPrint('☀️ Background: Morning check-in');

  final user = await _getCurrentUser();
  if (user == null) return null;
  if (!await _requiresGlucoCoachCoach(user.userId)) return null;

  final db = FirebaseFirestore.instance;
  final glucoCoach = GlucoCoachAIService();
  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  final name = data['name'] as String? ?? 'there';
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  final now = DateTime.now().toUtc();
  final utcOffset = (data['timezoneOffsetHours'] ?? 3) as int;
  final userHour = (now.hour + utcOffset + 24) % 24;
  if (userHour != 7) return null; // Not 7 AM yet

  try {
    final context = await _buildFullHealthContext(userId, data);

    final prompt = '''
You are the Wellor 24/7 Health Coach. Generate a personalized morning GlucoCoach message.

USER: $name
$context

TODAY'S SCHEDULE:
- Morning check-in (now)
- Hydration reminders every 2 hours
- Activity nudge at 2 PM
- Evening reflection at 8 PM
- Bedtime coaching at 10 PM

WRITE A MORNING MESSAGE THAT INCLUDES:
1. Personalized greeting based on yesterday's performance
2. Today's hydration goal (calculate: weight in kg × 35 = ml, or 8 glasses default)
3. One specific breakfast suggestion that will stabilize their glucose
4. One morning exercise recommendation (5-15 min)
5. What to watch out for today based on patterns
6. Motivational closing

RULES:
- 5-6 short lines max
- Be specific (exact portions, exact exercises)
- Use 2-3 emojis
- Sound like a supportive coach, not a doctor
- If they had poor sleep, suggest gentler exercise

Respond as plain text GlucoCoach message.''';

    final response = await _glucoCoachCoachReply(
      prompt,
      temperature: 0.7,
      maxTokens: 400,
    );

    await glucoCoach.sendProactiveMessage(
      userId: userId,
      message: '☀️ *Good Morning, $name!*\n\n$response',
    );

    await db.collection('agent_interactions').add({
      'userId': userId,
      'type': 'morning_checkin',
      'message': response,
      'timestamp': FieldValue.serverTimestamp(),
    });

    debugPrint('☀️ Background: Morning check-in sent');
    return 'Good morning sent to $name';
  } catch (e) {
    debugPrint('☀️ Background: Morning check-in error: $e');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. HYDRATION REMINDER (every 2 hours from 8 AM - 8 PM)
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeHydrationReminder() async {
  debugPrint('💧 Background: Hydration reminder');

  final user = await _getCurrentUser();
  if (user == null) return null;
  if (!await _requiresGlucoCoachCoach(user.userId)) return null;

  final db = FirebaseFirestore.instance;
  final glucoCoach = GlucoCoachAIService();

  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  final now = DateTime.now().toUtc();
  final utcOffset = (data['timezoneOffsetHours'] ?? 3) as int;
  final userHour = (now.hour + utcOffset + 24) % 24;

  // Only remind between 8 AM and 8 PM, every even hour
  if (userHour < 8 || userHour > 20 || userHour % 2 != 0) return null;

  // Check if we already sent a hydration reminder in the last 90 minutes
  final recentSnap = await db
      .collection('agent_interactions')
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'hydration')
      .orderBy('timestamp', descending: true)
      .limit(1)
      .get();

  if (recentSnap.docs.isNotEmpty) {
    final lastTime = (recentSnap.docs.first.data()['timestamp'] as Timestamp?)?.toDate();
    if (lastTime != null && DateTime.now().difference(lastTime).inMinutes < 90) {
      return null; // Already reminded recently
    }
  }

  try {
    final todayStart = DateTime(now.year, now.month, now.day);
    final waterSnap = await db
        .collection('users')
        .doc(userId)
        .collection('water_logs')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
        .get();

    int totalMl = 0;
    for (final doc in waterSnap.docs) {
      totalMl += (doc.data()['amount_ml'] ?? 0) as int;
    }

    final weightKg = (data['weight'] ?? 70) as num;
    final goalMl = (weightKg * 35).round();
    final remaining = goalMl - totalMl;
    final glasses = (remaining / 250).ceil();

    double? glucose;
    try {
      final glucoseSnap = await db
          .collection('glucose_readings')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (glucoseSnap.docs.isNotEmpty) {
        glucose = (glucoseSnap.docs.first.data()['glucose_level'] ?? 0).toDouble();
      }
    } catch (_) {}

    String message;
    if (remaining <= 0) {
      message = "💧 Amazing! You've hit your water goal for today ($totalMl ml). "
          "Keep sipping to maintain optimal hydration!";
    } else if (remaining < 500) {
      message = "💧 Almost there! Just ${glasses} more glass${glasses > 1 ? 'es' : ''} "
          "to hit your daily goal. You've got this! 🎯";
    } else {
      final tip = glucose != null && glucose > 140
          ? "Water helps flush excess glucose — drink up!"
          : "Staying hydrated improves focus and energy.";
      message = "💧 *Hydration Check*\n\n"
          "You've had ${(totalMl / 250).floor()} glasses today.\n"
          "$glasses more to go (${remaining}ml).\n\n"
          "$tip";
    }

    await glucoCoach.sendProactiveMessage(
      userId: userId,
      message: message,
    );

    await db.collection('agent_interactions').add({
      'userId': userId,
      'type': 'hydration',
      'waterToday': totalMl,
      'remaining': remaining,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return null; // Hydration reminders sent silently via GlucoCoach
  } catch (e) {
    debugPrint('💧 Background: Hydration error: $e');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. ACTIVITY NUDGE (2 PM local — when people get sluggish)
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeActivityNudge() async {
  debugPrint('🏃 Background: Activity nudge');

  final user = await _getCurrentUser();
  if (user == null) return null;
  if (!await _requiresGlucoCoachCoach(user.userId)) return null;

  final db = FirebaseFirestore.instance;
  final glucoCoach = GlucoCoachAIService();
  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  final now = DateTime.now().toUtc();
  final utcOffset = (data['timezoneOffsetHours'] ?? 3) as int;
  final userHour = (now.hour + utcOffset + 24) % 24;
  if (userHour != 14) return null; // Not 2 PM yet

  try {
    double? glucose;
    final glucoseSnap = await db
        .collection('glucose_readings')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(3)
        .get();

    if (glucoseSnap.docs.isNotEmpty) {
      glucose = (glucoseSnap.docs.first.data()['glucose_level'] ?? 0).toDouble();
    }

    final fitnessLevel = data['fitnessLevel'] as String? ?? 'moderate';
    final conditions = List<String>.from(data['diseases'] ?? []);
    final goals = List<String>.from(data['healthGoals'] ?? []);

    final prompt = '''
You are a personal fitness coach on GlucoCoach. The user needs an afternoon activity boost.

CURRENT STATUS:
- Time: 2 PM (post-lunch energy dip)
- Current glucose: ${glucose?.toStringAsFixed(0) ?? 'unknown'} mg/dL
- Fitness level: $fitnessLevel
- Conditions: ${conditions.join(', ').isEmpty ? 'None' : conditions.join(', ')}
- Goals: ${goals.join(', ').isEmpty ? 'General health' : goals.join(', ')}

GENERATE A QUICK ACTIVITY SUGGESTION:
1. If glucose > 140: Suggest 10-15 min moderate activity (walking, squats) to lower it
2. If glucose < 100: Suggest gentle movement with a small snack
3. If glucose normal: Suggest energizing desk exercises

RULES:
- One specific exercise with exact reps/duration
- Explain why this activity helps them right now
- Keep it under 4 lines
- Consider their conditions (no jumping for joint issues, etc.)
- Use 1-2 emojis

Respond as plain GlucoCoach message.''';

    final response = await _glucoCoachCoachReply(
      prompt,
      temperature: 0.7,
      maxTokens: 250,
    );

    await glucoCoach.sendProactiveMessage(
      userId: userId,
      message: '🏃 *Afternoon Energy Boost*\n\n$response',
    );

    await db.collection('agent_interactions').add({
      'userId': userId,
      'type': 'activity_nudge',
      'glucose': glucose,
      'message': response,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return null; // Activity nudge sent via GlucoCoach
  } catch (e) {
    debugPrint('🏃 Background: Activity nudge error: $e');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4. BEDTIME COACH (10 PM local — sleep preparation)
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeBedtimeCoach() async {
  debugPrint('🌙 Background: Bedtime coach');

  final user = await _getCurrentUser();
  if (user == null) return null;
  if (!await _requiresGlucoCoachCoach(user.userId)) return null;

  final db = FirebaseFirestore.instance;
  final glucoCoach = GlucoCoachAIService();
  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  final name = data['name'] as String? ?? 'there';
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  final now = DateTime.now().toUtc();
  final utcOffset = (data['timezoneOffsetHours'] ?? 3) as int;
  final userHour = (now.hour + utcOffset + 24) % 24;

  final preferredBedtime = data['preferredBedtimeHour'] as int? ?? 22;
  if (userHour != preferredBedtime) return null;

  try {
    double? glucose;
    final glucoseSnap = await db
        .collection('glucose_readings')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (glucoseSnap.docs.isNotEmpty) {
      glucose = (glucoseSnap.docs.first.data()['glucose_level'] ?? 0).toDouble();
    }

    DateTime? lastMealTime;
    final mealSnap = await db
        .collection('users')
        .doc(userId)
        .collection('meal_logs')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (mealSnap.docs.isNotEmpty) {
      lastMealTime = (mealSnap.docs.first.data()['timestamp'] as Timestamp?)?.toDate();
    }

    final hoursSinceMeal = lastMealTime != null
        ? DateTime.now().difference(lastMealTime).inHours
        : null;

    final preferredWakeHour = data['preferredWakeHour'] as int? ?? 7;
    final sleepDuration = (preferredWakeHour - preferredBedtime + 24) % 24;

    final prompt = '''
You are a sleep coach on GlucoCoach helping the user prepare for bed.

USER: $name
CURRENT TIME: ${preferredBedtime}:00 (their local time)
WAKE TIME: ${preferredWakeHour}:00 (${sleepDuration} hours of sleep planned)
CURRENT GLUCOSE: ${glucose?.toStringAsFixed(0) ?? 'unknown'} mg/dL
HOURS SINCE LAST MEAL: ${hoursSinceMeal ?? 'unknown'}

GENERATE A BEDTIME MESSAGE:
1. Comment on their glucose for sleep quality
   - If > 150: "Your glucose is a bit high — this might affect sleep depth"
   - If < 80: "Your glucose is low — consider a small protein snack"
   - If 80-140: "Your glucose looks good for restful sleep"
2. Give ONE specific wind-down activity (stretching, breathing, etc.)
3. Remind about screen time / blue light
4. Set expectation for tomorrow morning

RULES:
- Warm, calming tone
- 4-5 short lines
- Include specific sleep hygiene tip
- Use 1-2 relaxing emojis (🌙 🛏️ 💤)

Respond as plain GlucoCoach message.''';

    final response = await _glucoCoachCoachReply(
      prompt,
      temperature: 0.6,
      maxTokens: 300,
    );

    await glucoCoach.sendProactiveMessage(
      userId: userId,
      message: '🌙 *Time to Wind Down*\n\n$response\n\nI\'ll check in at ${preferredWakeHour}:00 AM. Sleep well! 💤',
    );

    await db.collection('agent_interactions').add({
      'userId': userId,
      'type': 'bedtime_coach',
      'glucose': glucose,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return null; // Bedtime coaching sent via GlucoCoach
  } catch (e) {
    debugPrint('🌙 Background: Bedtime coach error: $e');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 5. GLUCOSE WATCH (every 30 min — 24/7 monitoring)
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeGlucoseWatch() async {
  debugPrint('📊 Background: Glucose watch (LangGraph Pipeline)');

  final user = await _getCurrentUser();
  if (user == null) return null;

  final db = FirebaseFirestore.instance;
  final pipeline = GeminiAgentPipeline();

  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  final entitled = await SubscriptionEntitlementResolver.instance
      .canUseBackgroundHealthAgent(userId);
  if (!entitled) {
    debugPrint('📊 Background: Glucose watch skipped — Premium+ required');
    return null;
  }

  try {
    // Get recent glucose readings
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    final readingsSnap = await db
        .collection('glucose_readings')
        .where('user_id', isEqualTo: userId)
        .where('timestamp', isGreaterThan: cutoff)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    if (readingsSnap.docs.isEmpty) return null;

    final readings = readingsSnap.docs.map((d) => d.data()).toList();
    final latest = (readings.first['glucose_level'] ?? 0).toDouble();

    // Calculate velocity (rate of change)
    double? velocity;
    if (readings.length >= 2) {
      final prev = (readings[1]['glucose_level'] ?? 0).toDouble();
      final t1 = (readings.first['timestamp'] as Timestamp).toDate();
      final t0 = (readings[1]['timestamp'] as Timestamp).toDate();
      final mins = t1.difference(t0).inMinutes;
      if (mins > 0) velocity = (latest - prev) / mins;
    }

    // Check cooldown (30 min since last alert)
    final alertSnap = await db
        .collection('agent_interactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'pipeline_alert')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (alertSnap.docs.isNotEmpty) {
      final lastTime = (alertSnap.docs.first.data()['timestamp'] as Timestamp?)?.toDate();
      if (lastTime != null && DateTime.now().difference(lastTime).inMinutes < 30) {
        return null; // Cooldown active
      }
    }

    // Build patient profile from user data
    final conditions = List<String>.from(data['diseases'] ?? []);
    final goals = List<String>.from(data['healthGoals'] ?? []);
    final glucotype = data['glucotype'] as String?;
    final name = data['name'] as String? ?? 'Patient';

    final profile = StringBuffer('$name. ');
    if (glucotype != null) profile.write('Glucotype: $glucotype. ');
    if (conditions.isNotEmpty) profile.write('Conditions: ${conditions.join(", ")}. ');
    if (goals.isNotEmpty) profile.write('Goals: ${goals.join(", ")}.');

    final patientState = PatientState(
      patientId: userId,
      phoneNumber: phone,
      glucoseLevel: latest,
      glucoseVelocity: velocity,
      patientProfile: profile.toString(),
    );

    debugPrint('📊 Background: Processing glucose via LangGraph pipeline');
    await pipeline.invokeParallel([patientState], concurrency: 1);

    return 'Glucose: ${latest.toStringAsFixed(0)} mg/dL';
  } catch (e) {
    debugPrint('📊 Background: Glucose watch error: $e');
    return null;
  }
}



/// Detect which agent should handle the message based on keywords
String _detectAgent(String message) {
  final lower = message.toLowerCase();
  
  if (lower.contains('sleep') || lower.contains('tired') || lower.contains('bed') || 
      lower.contains('wake') || lower.contains('nap') || lower.contains('rest')) {
    return 'sleep';
  }
  if (lower.contains('water') || lower.contains('drink') || lower.contains('thirsty') || 
      lower.contains('hydrat')) {
    return 'hydration';
  }
  if (lower.contains('exercise') || lower.contains('walk') || lower.contains('run') || 
      lower.contains('steps') || lower.contains('gym') || lower.contains('workout')) {
    return 'exercise';
  }
  if (lower.contains('eat') || lower.contains('food') || lower.contains('meal') || 
      lower.contains('snack') || lower.contains('hungry') || lower.contains('glucose') ||
      lower.contains('sugar') || lower.contains('calorie')) {
    return 'nutrition';
  }
  
  // Default based on time
  final hour = DateTime.now().hour;
  if (hour >= 21 || hour < 7) return 'sleep';
  if (hour >= 12 && hour < 14) return 'nutrition';
  return 'hydration';
}

/// Handle conversation for users without linked accounts
Future<String> _handleGenericConversation(String message) async {
  try {
    final prompt = '''
You are a friendly health coach from Wellor. The user has not linked their account yet.

User message: "$message"

Respond helpfully but encourage them to link their GlucoCoach in the Wellor app for personalized advice.
Keep it under 100 words. Be warm and supportive.
''';

    return await _glucoCoachCoachReply(
      prompt,
      temperature: 0.7,
      maxTokens: 200,
    );
  } catch (e) {
    return "Hi! I'd love to help you with that. For personalized health coaching, please link your GlucoCoach in the Wellor app. 💚";
  }
}

// ═══════════════════════════════════════════════════════════════════
// 7. EVENING REFLECTION (8 PM local)
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeEveningReflection() async {
  debugPrint('🌆 Background: Evening reflection');

  final user = await _getCurrentUser();
  if (user == null) return null;
  if (!await _requiresGlucoCoachCoach(user.userId)) return null;

  final db = FirebaseFirestore.instance;
  final glucoCoach = GlucoCoachAIService();
  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  final name = data['name'] as String? ?? 'there';
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  final now = DateTime.now().toUtc();
  final utcOffset = (data['timezoneOffsetHours'] ?? 3) as int;
  final userHour = (now.hour + utcOffset + 24) % 24;

  if (userHour != 20) return null; // Not 8 PM

  try {
    final context = await _buildFullHealthContext(userId, data);

    final prompt = '''
You are a supportive health coach doing an evening check-in.

USER: $name
$context

GENERATE AN EVENING REFLECTION MESSAGE:
1. Summarize their day (glucose performance, meals, activity)
2. Celebrate wins (even small ones)
3. If there were spikes, gently mention what caused them
4. Suggest what to eat for dinner to sleep well
5. Ask if they have anything planned for tomorrow to prepare

RULES:
- Conversational, warm tone
- 4-5 short lines
- End with an open question to encourage reply
- Use 2 emojis

Respond as plain GlucoCoach message.''';

    final response = await _glucoCoachCoachReply(
      prompt,
      temperature: 0.7,
      maxTokens: 350,
    );

    await glucoCoach.sendProactiveMessage(
      userId: userId,
      message: '🌆 *Evening Check-in*\n\n$response',
    );

    await db.collection('agent_interactions').add({
      'userId': userId,
      'type': 'evening_reflection',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return null; // Evening reflection sent via GlucoCoach
  } catch (e) {
    debugPrint('🌆 Background: Evening reflection error: $e');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 8. MEAL REMINDER (11:30 AM, 5:30 PM local — 30 min before meals)
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeMealReminder() async {
  debugPrint('🍽️ Background: Meal reminder');

  final user = await _getCurrentUser();
  if (user == null) return null;
  if (!await _requiresGlucoCoachCoach(user.userId)) return null;

  final db = FirebaseFirestore.instance;
  final glucoCoach = GlucoCoachAIService();
  final now = DateTime.now().toUtc();
  final currentMinute = now.minute;

  // Only run at :30 mark (11:30 and 17:30)
  if (currentMinute < 25 || currentMinute > 35) return null;

  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  final utcOffset = (data['timezoneOffsetHours'] ?? 3) as int;
  final userHour = (now.hour + utcOffset + 24) % 24;

  // 11:30 AM (lunch prep) or 5:30 PM (dinner prep)
  if (userHour != 11 && userHour != 17) return null;

  final mealType = userHour == 11 ? 'lunch' : 'dinner';

  try {
    // Check cooldown
    final recentSnap = await db
        .collection('agent_interactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'meal_reminder')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (recentSnap.docs.isNotEmpty) {
      final lastTime = (recentSnap.docs.first.data()['timestamp'] as Timestamp?)?.toDate();
      if (lastTime != null && DateTime.now().difference(lastTime).inHours < 4) {
        return null;
      }
    }

    // Get user context
    final goals = List<String>.from(data['healthGoals'] ?? []);
    final conditions = List<String>.from(data['diseases'] ?? []);
    final glucotype = data['glucotype'] as String?;

    // Get current glucose
    double? glucose;
    final glucoseSnap = await db
        .collection('glucose_readings')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (glucoseSnap.docs.isNotEmpty) {
      glucose = (glucoseSnap.docs.first.data()['glucose_level'] ?? 0).toDouble();
    }

    final prompt = '''
You are a meal planning coach. The user is about to have $mealType in 30 minutes.

CURRENT GLUCOSE: ${glucose?.toStringAsFixed(0) ?? 'unknown'} mg/dL
GLUCOTYPE: ${glucotype ?? 'unknown'}
GOALS: ${goals.join(', ').isEmpty ? 'General health' : goals.join(', ')}
CONDITIONS: ${conditions.join(', ').isEmpty ? 'None' : conditions.join(', ')}

GENERATE A PRE-MEAL TIP:
1. Based on current glucose, suggest meal timing (wait if high, eat soon if low)
2. Give ONE specific food pairing tip for stable glucose
3. Remind about food order (vegetables first, then protein, carbs last)
4. Quick pre-meal prep tip

RULES:
- 3-4 lines
- Specific foods, not general advice
- Actionable in 30 minutes
- Use 1-2 emojis

Respond as plain GlucoCoach message.''';

    final response = await _glucoCoachCoachReply(
      prompt,
      temperature: 0.6,
      maxTokens: 200,
    );

    await glucoCoach.sendProactiveMessage(
      userId: userId,
      message: '🍽️ *${mealType.substring(0, 1,
    ).toUpperCase()}${mealType.substring(1)} in 30 min*\n\n$response',
    );

    await db.collection('agent_interactions').add({
      'userId': userId,
      'type': 'meal_reminder',
      'mealType': mealType,
      'glucose': glucose,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return null; // Meal reminder sent via GlucoCoach
  } catch (e) {
    debugPrint('🍽️ Background: Meal reminder error: $e');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// Build comprehensive health context for LLM prompts.
Future<String> _buildFullHealthContext(String userId, Map<String, dynamic> userData) async {
  return (await GlucoCoachContextService()
          .buildForUser(userId, profileOverride: userData))
      .toPromptBlock();
}

/// Handle conversational AI with full context and agent routing (Claude Sonnet).
Future<String> _handleConversation(
  String userId,
  String message,
  Map<String, dynamic> userData, {
  String? agentId,
}) async {
  final context = await _buildFullHealthContext(userId, userData);
  final agent = agentId ?? 'hydration';
  
  // Agent-specific system prompts
  final agentPrompts = {
    'sleep': '''You are the 😴 Sleep Agent, Wellor's sleep health specialist on GlucoCoach.
Your role: Help users optimize sleep quality, establish bedtime routines, and wake refreshed.
Personality: Calm, soothing, knowledgeable about circadian rhythms and sleep science.
Focus on: bedtime routines, sleep quality, wake-up strategies, naps, insomnia help.''',
    'hydration': '''You are the 💧 Hydration Agent, Wellor's hydration coach on GlucoCoach.
Your role: Help users stay properly hydrated throughout the day.
Personality: Refreshing, encouraging, science-backed advice.
Focus on: water intake, hydration timing, signs of dehydration, fluid balance.''',
    'exercise': '''You are the 🏃 Exercise Agent, Wellor's fitness coach on GlucoCoach.
Your role: Help users stay active, reach step goals, and maintain fitness.
Personality: Energetic, motivating, practical with suggestions.
Focus on: steps, workouts, stretching, movement breaks, activity nudges.''',
    'nutrition': '''You are the 🍎 Nutrition Agent, Wellor's dietitian on GlucoCoach.
Your role: Help users make healthy food choices, manage glucose, and enjoy balanced meals.
Personality: Warm, non-judgmental, practical meal suggestions.
Focus on: meal planning, glucose management, snack ideas, portion control.''',
  };

  final agentPrompt = agentPrompts[agent] ?? agentPrompts['hydration']!;

  final prompt = '''
$agentPrompt

You have access to this user's real-time health data:

$context

USER MESSAGE: "$message"

RULES:
- Under 200 words
- Be SPECIFIC: exact foods, exact portions, exact exercises, exact times
- Consider their current glucose, conditions, and goals
- Natural conversational tone
- Use 1-2 emojis relevant to your agent type
- If user needs help from a different agent, mention they can ask about sleep, hydration, exercise, or nutrition

Respond as plain GlucoCoach message.''';

  try {
    return await _glucoCoachCoachReply(
      prompt,
      temperature: 0.7,
      maxTokens: 400,
    );
  } catch (e) {
    debugPrint('💬 Conversation error: $e');
    return "I'm having a brief hiccup. Your health data is safe — try again in a moment! 💚";
  }
}

/// Generate a quick status report.
Future<String> _generateStatusReport(String userId, Map<String, dynamic> userData) async {
  final context = await _buildFullHealthContext(userId, userData);
  return '📊 *Your Status Right Now*\n\n$context\n\nReply anytime with questions!';
}

/// Handle water logging commands.
Future<String> _handleWaterCommand(String userId, String message, Map<String, dynamic> userData) async {
  final db = FirebaseFirestore.instance;

  // Parse amount (e.g., "water 500ml", "water 2 glasses", "logged water")
  int amountMl = 250; // default 1 glass
  final numbers = RegExp(r'(\d+)').allMatches(message.toLowerCase());
  if (numbers.isNotEmpty) {
    final num = int.tryParse(numbers.first.group(1)!) ?? 250;
    amountMl = message.toLowerCase().contains('glass') ? num * 250 : num;
  }

  // Cap at reasonable amount
  amountMl = amountMl.clamp(50, 2000);

  await db.collection('users').doc(userId).collection('water_logs').add({
    'amount_ml': amountMl,
    'timestamp': FieldValue.serverTimestamp(),
    'source': 'glucoCoach',
  });

  // Get today's total
  final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final waterSnap = await db
      .collection('users')
      .doc(userId)
      .collection('water_logs')
      .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
      .get();

  int totalMl = 0;
  for (final doc in waterSnap.docs) {
    totalMl += (doc.data()['amount_ml'] ?? 0) as int;
  }

  final goalMl = ((userData['weight'] ?? 70) * 35).round();
  final remaining = goalMl - totalMl;
  final glasses = (remaining / 250).ceil();

  if (remaining <= 0) {
    return '💧 Logged ${amountMl}ml!\n\n'
        '🎉 You\'ve hit your ${goalMl}ml goal! '
        'Total today: ${totalMl}ml. Keep it up!';
  } else {
    return '💧 Logged ${amountMl}ml!\n\n'
        'Total today: ${totalMl}ml / ${goalMl}ml\n'
        '$glasses more glasses to go! 💪';
  }
}

/// Return help menu.
String _getHelpMenu() {
  return '''
🤖 *Wellor Health Agent*

Here's what I can help with:

📊 *STATUS* — Get your current health snapshot
💧 *WATER 250ml* — Log water intake
🏃 *"What exercise should I do?"* — Personalized workout
🍽️ *"What should I eat?"* — Meal suggestions
😴 *"When should I sleep?"* — Bedtime advice
⚡ *"My glucose is high"* — Instant help

Just chat naturally — I understand context!

*Commands:*
STOP — Pause notifications
START — Resume notifications
HELP — Show this menu

Reply anytime, 24/7! 💚''';
}

// ═══════════════════════════════════════════════════════════════════
// 9. MULTI-AGENT SYNC (every 30 min)
// Runs the full Hierarchical Multi-Agent System for each opted-in user.
// The Supervisor routes events to Sleep, Hydration, Exercise, and
// Snack mini-agents, resolves conflicts, and delivers unified advice.
// ═══════════════════════════════════════════════════════════════════

Future<String?> _executeMultiAgentSync() async {
  debugPrint('🤖 Background: Multi-Agent System sync');

  final user = await _getCurrentUser();
  if (user == null) return null;
  if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(user.userId)) {
    debugPrint('🤖 Background: MAS sync skipped — Ultra required');
    return null;
  }

  final db = FirebaseFirestore.instance;
  final mas = MultiAgentSystem.instance;

  final data = user.data;
  final userId = user.userId;
  final phone = data['glucoCoachNumber'] as String?;
  if (phone == null || phone.isEmpty) return null;
  if (data['glucoCoachOptedIn'] != true) return null;

  try {
    // Build health profile from Firestore
    final healthProfileDoc = await db
        .collection('users')
        .doc(userId)
        .collection('agent_data')
        .doc('health_profile')
        .get();

    final profile = healthProfileDoc.exists
        ? HealthProfile.fromJson(healthProfileDoc.data()!)
        : HealthProfile.fromUserProfileJson(data);

    // Read full biometric data from Firestore (synced from wearable)
    final biometricDoc = await db
        .collection('users')
        .doc(userId)
        .collection('biometrics')
        .doc('current')
        .get();

    final bio = biometricDoc.data() ?? {};

    // Also fetch recent glucose readings for trend analysis
    final glucoseCutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 4)),
    );
    final glucoseSnap = await db
        .collection('glucose_readings')
        .where('user_id', isEqualTo: userId)
        .where('timestamp', isGreaterThan: glucoseCutoff)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    final glucoseHistory = glucoseSnap.docs.map((d) {
      final gData = d.data();
      return {
        'value': (gData['glucose_level'] as num?)?.toDouble() ?? 0.0,
        'timestamp': (gData['timestamp'] as Timestamp?)?.toDate().toIso8601String() ?? '',
      };
    }).toList();

    // Build agent state with ALL available biometric data
    final state = AgentState(
      odId: userId,
      healthProfile: profile,
      currentGlucose: (bio['glucose'] as num?)?.toDouble(),
      heartRate: (bio['heartRate'] as num?)?.toDouble(),
      restingHeartRate: (bio['restingHeartRate'] as num?)?.toDouble(),
      heartRateVariability: (bio['heartRateVariability'] as num?)?.toDouble(),
      stepsToday: bio['stepsToday'] as int?,
      sleepHours: (bio['sleepHours'] as num?)?.toDouble(),
      sleepQualityScore: bio['sleepQuality'] as int?,
      hydrationLiters: (bio['hydrationLiters'] as num?)?.toDouble(),
      caloriesBurnedToday: (bio['caloriesBurned'] as num?)?.toDouble(),
      caloriesConsumedToday: (bio['caloriesConsumed'] as num?)?.toDouble(),
      bloodOxygen: (bio['bloodOxygen'] as num?)?.toDouble(),
      bodyTemperature: (bio['bodyTemperature'] as num?)?.toDouble(),
      bloodPressureSystolic: (bio['bloodPressureSystolic'] as num?)?.toDouble(),
      bloodPressureDiastolic: (bio['bloodPressureDiastolic'] as num?)?.toDouble(),
      workoutMinutesToday: bio['workoutMinutesToday'] as int?,
      glucoseMonitorConnected: profile.glucoseMonitorConnected,
      wearableConnected: profile.wearableConnected,
      glucoCoachNumber: phone,
      glucoseHistory: glucoseHistory.cast<Map<String, dynamic>>(),
      heartRateHistory: List<Map<String, dynamic>>.from(bio['heartRateHistory'] ?? []),
    );

    // Initialize MAS with full state
    await mas.initialize(state);

    // Determine trigger based on time of day and available data
    final hour = DateTime.now().hour;
    AgentTriggerType trigger;
    if (hour >= 6 && hour < 8) {
      trigger = AgentTriggerType.dailyPlanning;
    } else if (hour >= 20 && hour < 22) {
      trigger = AgentTriggerType.eveningReview;
    } else if (state.currentGlucose != null) {
      trigger = AgentTriggerType.glucoseReading;
    } else {
      trigger = AgentTriggerType.hydrationCheck;
    }

    // Process event through the full MAS pipeline
    final actions = await mas.currentState != null
        ? await ChiefHealthOfficer().processEvent(
            trigger: trigger,
            state: state,
          )
        : <ResolvedAction>[];

    // Log all actions for analytics
    for (final action in actions) {
      await db.collection('agent_interactions').add({
        'userId': userId,
        'type': 'multi_agent_action',
        'agent': action.resolvedBy,
        'message': action.message,
        'priority': action.priority,
        'actionType': action.type,
        'trigger': trigger.name,
        'biometrics': {
          'glucose': state.currentGlucose,
          'heartRate': state.heartRate,
          'bloodOxygen': state.bloodOxygen,
          'bloodPressure': state.bloodPressureSystolic != null 
              ? '${state.bloodPressureSystolic}/${state.bloodPressureDiastolic}'
              : null,
          'steps': state.stepsToday,
          'sleepHours': state.sleepHours,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    debugPrint('🤖 Background: MAS processed ${actions.length} actions');
    if (actions.isEmpty) return null;
    return '${actions.length} health action${actions.length > 1 ? 's' : ''} processed';
  } catch (e) {
    debugPrint('🤖 Background: MAS error: $e');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// BACKGROUND AGENT SERVICE — Initialization & Control
// ═══════════════════════════════════════════════════════════════════

class BackgroundAgentService {
  static final BackgroundAgentService _instance = BackgroundAgentService._internal();
  factory BackgroundAgentService() => _instance;
  BackgroundAgentService._internal();

  bool _initialized = false;

  /// Initialize the Workmanager and register only critical monitoring tasks.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Workmanager().initialize(
        backgroundCallbackDispatcher,
        // Debug mode disabled to prevent Workmanager task metadata notifications.
        isInDebugMode: false,
      );

      await _cancelLegacyTasks();
      await _registerAllTasks();

      _initialized = true;
      debugPrint('🤖 BackgroundAgentService: Initialized with critical-only tasks');
    } catch (e) {
      debugPrint('🤖 BackgroundAgentService: Init error: $e');
    }
  }

  Future<void> _cancelLegacyTasks() async {
    await Workmanager().cancelByUniqueName('morning_checkin_v1');
    await Workmanager().cancelByUniqueName('hydration_v1');
    await Workmanager().cancelByUniqueName('activity_nudge_v1');
    await Workmanager().cancelByUniqueName('bedtime_coach_v1');
    await Workmanager().cancelByUniqueName('glucoCoach_poll_v1');
    await Workmanager().cancelByUniqueName('evening_reflection_v1');
    await Workmanager().cancelByUniqueName('meal_reminder_v1');
    await Workmanager().cancelByUniqueName('multi_agent_sync_v1');
  }

  Future<void> _registerAllTasks() async {
    // Critical glucose watch (every 30 minutes — critical monitoring only)
    await Workmanager().registerPeriodicTask(
      'glucose_watch_v1',
      taskGlucoseWatch,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    debugPrint('🤖 BackgroundAgentService: Critical glucose watch registered');
  }

  /// Manually trigger any task for testing.
  Future<void> runTaskNow(String taskName) async {
    await Workmanager().registerOneOffTask(
      '${taskName}_manual_${DateTime.now().millisecondsSinceEpoch}',
      taskName,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Cancel all background tasks.
  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    debugPrint('🤖 BackgroundAgentService: All tasks cancelled');
  }
}
