import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './behavioral_psychology_service.dart';
import 'subscription_entitlement_resolver.dart';

/// 🎭 **PERSONALITY ADAPTATION SYSTEM**
/// Adapts app behavior, messaging, and interventions to user personality and routine.
///
/// **Adaptation Dimensions:**
/// - Coaching tone (encouraging vs direct vs analytical)
/// - Notification style (frequent vs minimal)
/// - Goal framing (gain vs loss)
/// - Complexity level (simple vs detailed)
/// - Social features (community vs private)
/// - Reward types (streaks vs insights vs badges)
///
/// **Routine Adaptation:**
/// - Meal timing patterns
/// - Exercise preferences
/// - Sleep schedule (morning person vs night owl)
/// - Work schedule integration
/// - Stress patterns
/// - Energy levels by time of day

enum CoachingTone {
  encouraging,   // "You're doing great! Keep it up!"
  direct,        // "Complete your daily scan now."
  analytical,    // "Your metabolic efficiency improved 12%"
  supportive,    // "It's okay to have tough days. Let's adjust."
  motivational,  // "You're stronger than your excuses!"
}

enum NotificationStyle {
  frequent,      // Multiple daily reminders
  moderate,      // 2-3 key notifications
  minimal,       // Only critical alerts
  adaptive,      // Changes based on engagement
}

enum ChronotypetPattern {
  earlyBird,     // 5-7 AM wake, 9-10 PM sleep
  normalSchedule, // 7-8 AM wake, 11 PM sleep
  nightOwl,      // 9-10 AM wake, 1-2 AM sleep
  irregular,     // No consistent pattern
}

class UserRoutineProfile {
  final String userId;
  final ChronotypetPattern chronotype;
  final Map<String, TimeOfDay> mealPatterns; // 'breakfast', 'lunch', 'dinner', 'snack'
  final Map<String, TimeOfDay> exercisePatterns; // 'morning', 'afternoon', 'evening'
  final Map<int, double> energyLevelsByHour; // Hour of day → energy level (0-100)
  final Map<int, double> stressLevelsByHour; // Hour of day → stress level (0-100)
  final List<int> peakProductivityHours;
  final List<int> lowEnergyHours;
  final Map<String, dynamic> workSchedule; // Start time, end time, days
  final bool hasRegularRoutine;
  final double routineConsistency; // 0-100

  UserRoutineProfile({
    required this.userId,
    required this.chronotype,
    required this.mealPatterns,
    required this.exercisePatterns,
    required this.energyLevelsByHour,
    required this.stressLevelsByHour,
    required this.peakProductivityHours,
    required this.lowEnergyHours,
    required this.workSchedule,
    required this.hasRegularRoutine,
    required this.routineConsistency,
  });

  /// Get optimal time for health check-ins
  List<int> get optimalCheckInHours {
    return peakProductivityHours.take(2).toList();
  }

  /// Get times to avoid notifications
  List<int> get avoidNotificationHours {
    return lowEnergyHours + [workSchedule['startHour'] as int? ?? 9];
  }
}

class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay(this.hour, this.minute);

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class PersonalityAdaptationService {
  static final PersonalityAdaptationService _instance = PersonalityAdaptationService._internal();
  factory PersonalityAdaptationService() => _instance;
  PersonalityAdaptationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BehavioralPsychologyService _psychService = BehavioralPsychologyService();

  Future<bool> _hasPersonalityAdaptation(String userId) =>
      SubscriptionEntitlementResolver.instance.isActiveUltra(userId);

  UserRoutineProfile _neutralRoutine(String userId) => UserRoutineProfile(
        userId: userId,
        chronotype: ChronotypetPattern.normalSchedule,
        mealPatterns: {},
        exercisePatterns: {},
        energyLevelsByHour: const {9: 50.0, 14: 50.0, 18: 50.0},
        stressLevelsByHour: {},
        peakProductivityHours: const [10, 15],
        lowEnergyHours: const [2, 3],
        workSchedule: const {'startHour': 9, 'endHour': 17},
        hasRegularRoutine: false,
        routineConsistency: 0,
      );

  // ============================================================================
  // PERSONALITY-BASED ADAPTATION
  // ============================================================================

  /// Get optimal coaching tone for user
  Future<CoachingTone> getCoachingTone(String userId) async {
    if (!await _hasPersonalityAdaptation(userId)) {
      return CoachingTone.encouraging;
    }
    final profile = await _psychService.getProfile(userId);
    if (profile == null) return CoachingTone.encouraging;

    // Adapt based on personality traits
    final neuroticism = profile.bigFiveTraits['neuroticism'] ?? 50;
    final conscientiousness = profile.bigFiveTraits['conscientiousness'] ?? 50;
    final extraversion = profile.bigFiveTraits['extraversion'] ?? 50;

    // High neuroticism → supportive tone
    if (neuroticism > 70) return CoachingTone.supportive;

    // High conscientiousness → analytical tone
    if (conscientiousness > 70) return CoachingTone.analytical;

    // Low engagement → motivational tone
    if (profile.engagementScore < 40) return CoachingTone.motivational;

    // Achiever archetype → direct tone
    if (profile.archetype == UserArchetype.achiever) return CoachingTone.direct;

    // Default: encouraging
    return CoachingTone.encouraging;
  }

  /// Get optimal notification style
  Future<NotificationStyle> getNotificationStyle(String userId) async {
    if (!await _hasPersonalityAdaptation(userId)) {
      return NotificationStyle.moderate;
    }
    final profile = await _psychService.getProfile(userId);
    if (profile == null) return NotificationStyle.moderate;

    // High burnout risk → minimal notifications
    if (profile.burnoutRisk > 70) return NotificationStyle.minimal;

    // Struggler archetype → frequent reminders
    if (profile.archetype == UserArchetype.struggler) return NotificationStyle.frequent;

    // Optimizer archetype → minimal notifications
    if (profile.archetype == UserArchetype.optimizer) return NotificationStyle.minimal;

    // Strong habit → minimal notifications
    if (profile.habitStrength > 70) return NotificationStyle.minimal;

    // Weak habit + low engagement → adaptive (start frequent, reduce over time)
    if (profile.habitStrength < 30 && profile.engagementScore < 50) {
      return NotificationStyle.adaptive;
    }

    return NotificationStyle.moderate;
  }

  /// Adapt message to user personality
  Future<String> adaptMessage({
    required String userId,
    required String baseMessage,
    required String context, // 'goal', 'reminder', 'achievement', 'warning'
  }) async {
    if (!await _hasPersonalityAdaptation(userId)) {
      return baseMessage;
    }
    final profile = await _psychService.getProfile(userId);
    if (profile == null) return baseMessage;

    final tone = await getCoachingTone(userId);

    // Apply tone transformation
    String adaptedMessage = baseMessage;

    switch (tone) {
      case CoachingTone.encouraging:
        adaptedMessage = _makeEncouraging(adaptedMessage, context);
        break;
      case CoachingTone.direct:
        adaptedMessage = _makeDirect(adaptedMessage);
        break;
      case CoachingTone.analytical:
        adaptedMessage = _makeAnalytical(adaptedMessage, context);
        break;
      case CoachingTone.supportive:
        adaptedMessage = _makeSupportive(adaptedMessage);
        break;
      case CoachingTone.motivational:
        adaptedMessage = _makeMotivational(adaptedMessage, context);
        break;
    }

    // Add personality-specific elements
    if (profile.archetype == UserArchetype.achiever) {
      adaptedMessage = _addCompetitiveElement(adaptedMessage);
    } else if (profile.archetype == UserArchetype.socializer) {
      adaptedMessage = _addSocialElement(adaptedMessage);
    } else if (profile.archetype == UserArchetype.explorer) {
      adaptedMessage = _addLearningElement(adaptedMessage);
    }

    return adaptedMessage;
  }

  String _makeEncouraging(String message, String context) {
    final prefixes = {
      'goal': '🎯 ',
      'reminder': '👋 ',
      'achievement': '🎉 ',
      'warning': '💙 ',
    };

    final encouragements = [
      'You\'ve got this! ',
      'Great work so far! ',
      'You\'re making progress! ',
    ];

    return '${prefixes[context] ?? ''}${encouragements[DateTime.now().millisecond % encouragements.length]}$message';
  }

  String _makeDirect(String message) {
    // Remove fluff, get straight to the point
    message = message.replaceAll('Please ', '');
    message = message.replaceAll('would you like to', '');
    return message;
  }

  String _makeAnalytical(String message, String context) {
    // Add data points and metrics
    if (context == 'achievement') {
      return '$message Your consistency score improved by 15%.';
    } else if (context == 'goal') {
      return '$message Based on your current trajectory, you\'re on track to achieve this 3 days early.';
    }
    return message;
  }

  String _makeSupportive(String message) {
    final supportivePrefixes = [
      'It\'s okay, ',
      'No pressure, ',
      'Remember to be kind to yourself. ',
    ];

    return '${supportivePrefixes[DateTime.now().millisecond % supportivePrefixes.length]}$message';
  }

  String _makeMotivational(String message, String context) {
    final motivationalSuffixes = {
      'goal': ' You\'re capable of more than you think!',
      'reminder': ' Every small step counts!',
      'achievement': ' You\'re unstoppable!',
    };

    return '$message${motivationalSuffixes[context] ?? ''}';
  }

  String _addCompetitiveElement(String message) {
    return '$message You\'re in the top 15% of users this week.';
  }

  String _addSocialElement(String message) {
    return '$message 237 people in your community achieved similar goals today.';
  }

  String _addLearningElement(String message) {
    return '$message Tap to learn why this matters for your health.';
  }

  // ============================================================================
  // ROUTINE DETECTION & ADAPTATION
  // ============================================================================

  /// Detect user routine patterns from behavioral data
  Future<UserRoutineProfile> detectRoutine(String userId) async {
    debugPrint('🕐 Detecting routine patterns for user $userId');

    if (!await _hasPersonalityAdaptation(userId)) {
      debugPrint('🕐 Routine detection: Ultra required ([hasPersonalityAdaptation])');
      return _neutralRoutine(userId);
    }

    // Analyze meal timing
    final mealPatterns = await _detectMealPatterns(userId);

    // Analyze exercise timing
    final exercisePatterns = await _detectExercisePatterns(userId);

    // Detect chronotype (sleep schedule)
    final chronotype = await _detectChronotype(userId);

    // Analyze energy levels by hour
    final energyLevels = await _analyzeEnergyPatterns(userId);

    // Analyze stress patterns
    final stressLevels = await _analyzeStressPatterns(userId);

    // Identify peak productivity hours
    final peakHours = _identifyPeakHours(energyLevels);

    // Identify low energy hours
    final lowEnergyHours = _identifyLowEnergyHours(energyLevels);

    // Detect work schedule
    final workSchedule = await _detectWorkSchedule(userId);

    // Calculate routine consistency
    final consistency = _calculateRoutineConsistency(mealPatterns, exercisePatterns);

    final routine = UserRoutineProfile(
      userId: userId,
      chronotype: chronotype,
      mealPatterns: mealPatterns,
      exercisePatterns: exercisePatterns,
      energyLevelsByHour: energyLevels,
      stressLevelsByHour: stressLevels,
      peakProductivityHours: peakHours,
      lowEnergyHours: lowEnergyHours,
      workSchedule: workSchedule,
      hasRegularRoutine: consistency > 70,
      routineConsistency: consistency,
    );

    // Store routine profile
    await _storeRoutineProfile(routine);

    debugPrint('✅ Routine detected: ${chronotype.toString().split('.').last}, consistency: ${consistency.toStringAsFixed(0)}%');

    return routine;
  }

  Future<Map<String, TimeOfDay>> _detectMealPatterns(String userId) async {
    final mealEvents = await _getMealEvents(userId, days: 14);

    final patterns = <String, List<DateTime>>{
      'breakfast': [],
      'lunch': [],
      'dinner': [],
      'snack': [],
    };

    for (final event in mealEvents) {
      final hour = event.timestamp.hour;
      if (hour >= 5 && hour < 11) {
        patterns['breakfast']!.add(event.timestamp);
      } else if (hour >= 11 && hour < 15) {
        patterns['lunch']!.add(event.timestamp);
      } else if (hour >= 17 && hour < 22) {
        patterns['dinner']!.add(event.timestamp);
      } else {
        patterns['snack']!.add(event.timestamp);
      }
    }

    // Calculate average time for each meal
    final mealPatterns = <String, TimeOfDay>{};
    for (final entry in patterns.entries) {
      if (entry.value.isEmpty) continue;

      final avgMinutes = entry.value
          .map((d) => d.hour * 60 + d.minute)
          .reduce((a, b) => a + b) ~/ entry.value.length;

      mealPatterns[entry.key] = TimeOfDay(avgMinutes ~/ 60, avgMinutes % 60);
    }

    return mealPatterns;
  }

  Future<Map<String, TimeOfDay>> _detectExercisePatterns(String userId) async {
    final exerciseEvents = await _getExerciseEvents(userId, days: 14);

    final patterns = <String, List<DateTime>>{
      'morning': [],
      'afternoon': [],
      'evening': [],
    };

    for (final event in exerciseEvents) {
      final hour = event.timestamp.hour;
      if (hour >= 5 && hour < 12) {
        patterns['morning']!.add(event.timestamp);
      } else if (hour >= 12 && hour < 17) {
        patterns['afternoon']!.add(event.timestamp);
      } else {
        patterns['evening']!.add(event.timestamp);
      }
    }

    final exercisePatterns = <String, TimeOfDay>{};
    for (final entry in patterns.entries) {
      if (entry.value.isEmpty) continue;

      final avgMinutes = entry.value
          .map((d) => d.hour * 60 + d.minute)
          .reduce((a, b) => a + b) ~/ entry.value.length;

      exercisePatterns[entry.key] = TimeOfDay(avgMinutes ~/ 60, avgMinutes % 60);
    }

    return exercisePatterns;
  }

  Future<ChronotypetPattern> _detectChronotype(String userId) async {
    // Analyze app usage patterns
    final events = await _getAllEvents(userId, days: 14);
    
    if (events.isEmpty) return ChronotypetPattern.normalSchedule;

    // Find most common first activity hour
    final firstActivityHours = <int>[];
    final eventsByDay = <DateTime, List<BehavioralEvent>>{};

    for (final event in events) {
      final date = DateTime(event.timestamp.year, event.timestamp.month, event.timestamp.day);
      eventsByDay[date] = (eventsByDay[date] ?? [])..add(event);
    }

    for (final dayEvents in eventsByDay.values) {
      if (dayEvents.isEmpty) continue;
      dayEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      firstActivityHours.add(dayEvents.first.timestamp.hour);
    }

    if (firstActivityHours.isEmpty) return ChronotypetPattern.normalSchedule;

    final avgFirstHour = firstActivityHours.reduce((a, b) => a + b) ~/ firstActivityHours.length;

    // Classify chronotype
    if (avgFirstHour >= 5 && avgFirstHour < 7) {
      return ChronotypetPattern.earlyBird;
    } else if (avgFirstHour >= 9 && avgFirstHour < 12) {
      return ChronotypetPattern.nightOwl;
    } else if (avgFirstHour >= 7 && avgFirstHour < 9) {
      return ChronotypetPattern.normalSchedule;
    }

    return ChronotypetPattern.irregular;
  }

  Future<Map<int, double>> _analyzeEnergyPatterns(String userId) async {
    // Infer energy from activity intensity and frequency
    final events = await _getAllEvents(userId, days: 14);

    final energyByHour = <int, List<double>>{};

    for (final event in events) {
      final hour = event.timestamp.hour;
      
      // High-energy activities
      if (event.eventType == 'scan' || event.eventType == 'meal_plan' || event.eventType == 'goal_completed') {
        energyByHour[hour] = (energyByHour[hour] ?? [])..add(75.0);
      }
      // Medium-energy activities
      else if (event.eventType == 'app_opened') {
        energyByHour[hour] = (energyByHour[hour] ?? [])..add(50.0);
      }
      // Low-energy activities
      else {
        energyByHour[hour] = (energyByHour[hour] ?? [])..add(30.0);
      }
    }

    // Calculate average energy per hour
    final avgEnergyByHour = <int, double>{};
    for (final entry in energyByHour.entries) {
      avgEnergyByHour[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    return avgEnergyByHour;
  }

  Future<Map<int, double>> _analyzeStressPatterns(String userId) async {
    // TODO: Integrate with wearable data (heart rate variability)
    // For now, return placeholder
    return {};
  }

  List<int> _identifyPeakHours(Map<int, double> energyLevels) {
    if (energyLevels.isEmpty) return [9, 14]; // Default

    final sorted = energyLevels.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  List<int> _identifyLowEnergyHours(Map<int, double> energyLevels) {
    if (energyLevels.isEmpty) return [14, 15]; // Post-lunch dip

    final sorted = energyLevels.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  Future<Map<String, dynamic>> _detectWorkSchedule(String userId) async {
    // Analyze app inactivity patterns (likely working during these hours)
    final events = await _getAllEvents(userId, days: 14);

    final activityByHour = <int, int>{};
    for (final event in events) {
      activityByHour[event.timestamp.hour] = (activityByHour[event.timestamp.hour] ?? 0) + 1;
    }

    // Find hours with lowest activity (likely work hours)
    final sorted = activityByHour.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final lowActivityHours = sorted.take(8).map((e) => e.key).toList()..sort();

    if (lowActivityHours.length >= 2) {
      return {
        'startHour': lowActivityHours.first,
        'endHour': lowActivityHours.last,
        'days': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'], // Assume weekdays
      };
    }

    // Default 9-5
    return {
      'startHour': 9,
      'endHour': 17,
      'days': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    };
  }

  double _calculateRoutineConsistency(
    Map<String, TimeOfDay> mealPatterns,
    Map<String, TimeOfDay> exercisePatterns,
  ) {
    // More patterns = more consistent routine
    final totalPossiblePatterns = 7; // 4 meals + 3 exercise times
    final detectedPatterns = mealPatterns.length + exercisePatterns.length;

    return (detectedPatterns / totalPossiblePatterns * 100).clamp(0, 100);
  }

  // ============================================================================
  // DATA RETRIEVAL
  // ============================================================================

  Future<List<BehavioralEvent>> _getMealEvents(String userId, {int days = 14}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('behavioral_events')
        .where('eventType', isEqualTo: 'scan')
        .where('timestamp', isGreaterThan: startDate.toIso8601String())
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return BehavioralEvent(
        userId: userId,
        eventType: data['eventType'],
        timestamp: DateTime.parse(data['timestamp']),
        metadata: data['metadata'] ?? {},
      );
    }).toList();
  }

  Future<List<BehavioralEvent>> _getExerciseEvents(String userId, {int days = 14}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('behavioral_events')
        .where('eventType', isEqualTo: 'exercise')
        .where('timestamp', isGreaterThan: startDate.toIso8601String())
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return BehavioralEvent(
        userId: userId,
        eventType: data['eventType'],
        timestamp: DateTime.parse(data['timestamp']),
        metadata: data['metadata'] ?? {},
      );
    }).toList();
  }

  Future<List<BehavioralEvent>> _getAllEvents(String userId, {int days = 14}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('behavioral_events')
        .where('timestamp', isGreaterThan: startDate.toIso8601String())
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return BehavioralEvent(
        userId: userId,
        eventType: data['eventType'],
        timestamp: DateTime.parse(data['timestamp']),
        metadata: data['metadata'] ?? {},
      );
    }).toList();
  }

  Future<void> _storeRoutineProfile(UserRoutineProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.userId)
        .collection('psychology')
        .doc('routine')
        .set({
      'chronotype': profile.chronotype.toString(),
      'mealPatterns': profile.mealPatterns.map((k, v) => MapEntry(k, v.toString())),
      'exercisePatterns': profile.exercisePatterns.map((k, v) => MapEntry(k, v.toString())),
      'energyLevelsByHour': profile.energyLevelsByHour,
      'stressLevelsByHour': profile.stressLevelsByHour,
      'peakProductivityHours': profile.peakProductivityHours,
      'lowEnergyHours': profile.lowEnergyHours,
      'workSchedule': profile.workSchedule,
      'hasRegularRoutine': profile.hasRegularRoutine,
      'routineConsistency': profile.routineConsistency,
    });
  }

  Future<UserRoutineProfile?> getRoutineProfile(String userId) async {
    if (!await _hasPersonalityAdaptation(userId)) {
      return null;
    }
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('psychology')
        .doc('routine')
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;

    return UserRoutineProfile(
      userId: userId,
      chronotype: ChronotypetPattern.values.firstWhere(
        (e) => e.toString() == data['chronotype'],
        orElse: () => ChronotypetPattern.normalSchedule,
      ),
      mealPatterns: (data['mealPatterns'] as Map).map((k, v) {
        final parts = (v as String).split(':');
        return MapEntry(k, TimeOfDay(int.parse(parts[0]), int.parse(parts[1])));
      }),
      exercisePatterns: (data['exercisePatterns'] as Map).map((k, v) {
        final parts = (v as String).split(':');
        return MapEntry(k, TimeOfDay(int.parse(parts[0]), int.parse(parts[1])));
      }),
      energyLevelsByHour: Map<int, double>.from(data['energyLevelsByHour']),
      stressLevelsByHour: Map<int, double>.from(data['stressLevelsByHour']),
      peakProductivityHours: List<int>.from(data['peakProductivityHours']),
      lowEnergyHours: List<int>.from(data['lowEnergyHours']),
      workSchedule: Map<String, dynamic>.from(data['workSchedule']),
      hasRegularRoutine: data['hasRegularRoutine'],
      routineConsistency: (data['routineConsistency'] as num).toDouble(),
    );
  }
}
