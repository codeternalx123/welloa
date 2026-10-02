// Builds live glucose + health profile context for GlucoCoach (Claude) prompts.
// Merges root `glucose_readings` and per-user subcollections.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CoachGlucosePoint {
  final double mgDl;
  final DateTime at;
  final String source;

  const CoachGlucosePoint({
    required this.mgDl,
    required this.at,
    required this.source,
  });
}

/// Snapshot used to personalize GlucoCoach replies and alerts.
class GlucoCoachCoachContext {
  final String userId;
  final String name;
  final List<String> healthGoals;
  final List<String> conditions;
  final String? glucotype;
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final List<String> medications;
  final CoachGlucosePoint? latestReading;
  final double? velocityMgDlPerMin;
  final String trend;
  final double? avg24hMgDl;
  final int? timeInRangePercent24h;
  final int readingsCount24h;
  final int todaySteps;
  final int todayWaterMl;
  final double? sleepHours;
  final int? sleepQuality;
  final Map<String, dynamic>? lastMeal;

  const GlucoCoachCoachContext({
    required this.userId,
    this.name = 'there',
    this.healthGoals = const [],
    this.conditions = const [],
    this.glucotype,
    this.weightKg,
    this.heightCm,
    this.age,
    this.medications = const [],
    this.latestReading,
    this.velocityMgDlPerMin,
    this.trend = 'unknown',
    this.avg24hMgDl,
    this.timeInRangePercent24h,
    this.readingsCount24h = 0,
    this.todaySteps = 0,
    this.todayWaterMl = 0,
    this.sleepHours,
    this.sleepQuality,
    this.lastMeal,
  });

  double? get currentGlucoseMgDl => latestReading?.mgDl;

  bool get hasRecentGlucose {
    if (latestReading == null) return false;
    return DateTime.now().difference(latestReading!.at).inMinutes <= 120;
  }

  String glucoseStatusLabel(double mgDl) {
    if (mgDl < 54) return 'critical low';
    if (mgDl < 70) return 'low';
    if (mgDl <= 140) return 'in range';
    if (mgDl <= 180) return 'elevated';
    if (mgDl <= 250) return 'high';
    return 'critical high';
  }

  /// Plain-text block for LLM prompts (GlucoCoach / Claude).
  String toPromptBlock() {
    final buf = StringBuffer('=== LIVE HEALTH CONTEXT ===\n');
    buf.writeln('Patient: $name');
    if (age != null) buf.writeln('Age: $age');
    if (weightKg != null) buf.writeln('Weight: ${weightKg!.toStringAsFixed(0)} kg');
    if (heightCm != null) buf.writeln('Height: ${heightCm!.toStringAsFixed(0)} cm');
    if (glucotype != null && glucotype!.isNotEmpty) {
      buf.writeln('Glucotype: $glucotype');
    }
    if (healthGoals.isNotEmpty) {
      buf.writeln('Health goals: ${healthGoals.join(", ")}');
    }
    if (conditions.isNotEmpty) {
      buf.writeln('Conditions: ${conditions.join(", ")}');
    }
    if (medications.isNotEmpty) {
      buf.writeln('Medications: ${medications.join(", ")}');
    }

    if (latestReading != null) {
      final g = latestReading!.mgDl;
      final minsAgo = DateTime.now().difference(latestReading!.at).inMinutes;
      buf.writeln(
        'Current glucose: ${g.toStringAsFixed(0)} mg/dL (${glucoseStatusLabel(g)}, '
        'trend: $trend, read $minsAgo min ago via ${latestReading!.source})',
      );
      if (velocityMgDlPerMin != null) {
        buf.writeln(
          'Glucose velocity: ${velocityMgDlPerMin!.toStringAsFixed(2)} mg/dL/min',
        );
      }
    } else {
      buf.writeln('Current glucose: no recent reading on file');
    }

    if (readingsCount24h > 0 && avg24hMgDl != null) {
      buf.writeln(
        '24h glucose: avg ${avg24hMgDl!.toStringAsFixed(0)} mg/dL, '
        'TIR ${timeInRangePercent24h ?? 0}% ($readingsCount24h readings)',
      );
    }

    if (todaySteps > 0) buf.writeln('Steps today: $todaySteps');
    if (todayWaterMl > 0) buf.writeln('Water today: ${todayWaterMl}ml');
    if (sleepHours != null) {
      buf.writeln(
        'Last sleep: ${sleepHours!.toStringAsFixed(1)}h'
        '${sleepQuality != null ? " (quality $sleepQuality/100)" : ""}',
      );
    }
    if (lastMeal != null) {
      final mealName = lastMeal!['name'] ?? lastMeal!['food_name'] ?? 'Unknown';
      final cals = lastMeal!['calories'];
      final carbs = lastMeal!['carbs'] ?? lastMeal!['carbohydrates'];
      buf.writeln(
        'Last meal: $mealName'
        '${cals != null ? ", ${cals} kcal" : ""}'
        '${carbs != null ? ", ${carbs}g carbs" : ""}',
      );
    }

    return buf.toString().trimRight();
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'healthGoals': healthGoals,
        'conditions': conditions,
        'glucotype': glucotype,
        'currentGlucose': currentGlucoseMgDl,
        'glucoseTrend': trend,
        'glucoseVelocity': velocityMgDlPerMin,
        'todaySteps': todaySteps,
        'todayWater': todayWaterMl,
        'sleepHours': sleepHours,
        'medications': medications,
      };
}

class GlucoCoachContextService {
  static final GlucoCoachContextService _instance =
      GlucoCoachContextService._internal();
  factory GlucoCoachContextService() => _instance;
  GlucoCoachContextService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<GlucoCoachCoachContext> buildForUser(
    String userId, {
    Map<String, dynamic>? profileOverride,
  }) async {
    Map<String, dynamic> profile = profileOverride ?? {};
    if (profile.isEmpty) {
      try {
        final doc = await _db.collection('users').doc(userId).get();
        profile = doc.data() ?? {};
      } catch (e) {
        debugPrint('📱 Coach context: profile load error: $e');
      }
    }

    final readings = await _fetchGlucoseReadings(userId);
    final latest = readings.isNotEmpty ? readings.first : null;
    final velocity = _velocity(readings);
    final trend = _trend(velocity);
    final stats24h = _stats24h(readings);

    final todaySteps = await _todaySteps(userId);
    final todayWaterMl = await _todayWaterMl(userId);
    final sleep = await _lastSleep(userId);
    final lastMeal = await _lastMeal(userId);
    final medications = await _medications(userId);

    return GlucoCoachCoachContext(
      userId: userId,
      name: profile['name'] as String? ?? 'there',
      healthGoals: List<String>.from(profile['healthGoals'] ?? []),
      conditions: List<String>.from(
        profile['diseases'] ?? profile['conditions'] ?? [],
      ),
      glucotype: profile['glucotype'] as String?,
      weightKg: (profile['weight'] as num?)?.toDouble(),
      heightCm: (profile['height'] as num?)?.toDouble(),
      age: (profile['age'] as num?)?.toInt(),
      medications: medications,
      latestReading: latest,
      velocityMgDlPerMin: velocity,
      trend: trend,
      avg24hMgDl: stats24h.$1,
      timeInRangePercent24h: stats24h.$2,
      readingsCount24h: stats24h.$3,
      todaySteps: todaySteps,
      todayWaterMl: todayWaterMl,
      sleepHours: sleep.$1,
      sleepQuality: sleep.$2,
      lastMeal: lastMeal,
    );
  }

  Future<List<CoachGlucosePoint>> _fetchGlucoseReadings(String userId) async {
    final points = <CoachGlucosePoint>[];
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));

    try {
      final rootSnap = await _db
          .collection('glucose_readings')
          .where('user_id', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      for (final doc in rootSnap.docs) {
        final parsed = _parsePoint(doc.data(), 'cgm');
        if (parsed != null) points.add(parsed);
      }
    } catch (e) {
      debugPrint('📱 Coach context: root glucose query: $e');
    }

    try {
      final subSnap = await _db
          .collection('users')
          .doc(userId)
          .collection('glucose_readings')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      for (final doc in subSnap.docs) {
        final parsed = _parsePoint(doc.data(), 'device');
        if (parsed != null) points.add(parsed);
      }
    } catch (e) {
      debugPrint('📱 Coach context: user glucose subcollection: $e');
    }

    points.sort((a, b) => b.at.compareTo(a.at));
    final seen = <String>{};
    final deduped = <CoachGlucosePoint>[];
    for (final p in points) {
      final key = '${p.at.millisecondsSinceEpoch}_${p.mgDl.round()}';
      if (seen.add(key)) deduped.add(p);
    }
    return deduped;
  }

  CoachGlucosePoint? _parsePoint(Map<String, dynamic> data, String source) {
    final mgDl = _parseGlucoseMgDl(data);
    final at = _parseTimestamp(data['timestamp']);
    if (mgDl == null || at == null) return null;
    return CoachGlucosePoint(mgDl: mgDl, at: at, source: source);
  }

  double? _parseGlucoseMgDl(Map<String, dynamic> data) {
    final raw = data['glucose_level'] ??
        data['glucoseLevel'] ??
        data['value'] ??
        data['glucose'];
    if (raw is num) return raw.toDouble();
    return null;
  }

  DateTime? _parseTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  double? _velocity(List<CoachGlucosePoint> readings) {
    if (readings.length < 2) return null;
    final a = readings[0];
    final b = readings[1];
    final mins = a.at.difference(b.at).inMinutes;
    if (mins <= 0) return null;
    return (a.mgDl - b.mgDl) / mins;
  }

  String _trend(double? velocity) {
    if (velocity == null) return 'unknown';
    if (velocity > 0.5) return 'rising';
    if (velocity < -0.5) return 'falling';
    return 'stable';
  }

  (double?, int?, int) _stats24h(List<CoachGlucosePoint> readings) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final recent = readings.where((r) => r.at.isAfter(cutoff)).toList();
    if (recent.isEmpty) return (null, null, 0);
    final values = recent.map((r) => r.mgDl).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final inRange = values.where((g) => g >= 70 && g <= 140).length;
    final tir = ((inRange / values.length) * 100).round();
    return (avg, tir, values.length);
  }

  Future<int> _todaySteps(String userId) async {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('daily_activity')
          .doc(todayStr)
          .get();
      return (doc.data()?['steps'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _todayWaterMl(String userId) async {
    try {
      final todayStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('water_logs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
          .get();
      var total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['amount_ml'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<(double?, int?)> _lastSleep(String userId) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('sleep_logs')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return (null, null);
      final data = snap.docs.first.data();
      final hours = (data['total_hours'] ?? data['duration_hours']) as num?;
      final quality = (data['quality'] ?? data['score']) as num?;
      return (hours?.toDouble(), quality?.toInt());
    } catch (_) {
      return (null, null);
    }
  }

  Future<Map<String, dynamic>?> _lastMeal(String userId) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('meal_logs')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _medications(String userId) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('medications')
          .limit(10)
          .get();
      return snap.docs
          .map((d) => d.data()['name'] as String? ?? d.id)
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
