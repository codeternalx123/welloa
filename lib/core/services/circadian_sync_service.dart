import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../../features/protocols/domain/models/supplement.dart';

class CircadianSchedule {
  final DateTime wakeTime;
  final DateTime breakfastTime;
  final DateTime lunchTime;
  final DateTime dinnerTime;
  final DateTime sleepTime;

  CircadianSchedule({
    required this.wakeTime,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    required this.sleepTime,
  });
}

class CircadianSyncService {
  final Health health;

  CircadianSyncService({Health? health, Health? healthFactory})
      : health = health ?? healthFactory ?? Health();

  Future<CircadianSchedule> calculateUserSchedule() async {
    // Attempt to pull real sleep data from the past 7 days to calculate average wake/sleep times
    final now = DateTime.now();
    final lastWeek = now.subtract(const Duration(days: 7));
    
    try {
      final sleepData = await health.getHealthDataFromTypes(
        startTime: lastWeek,
        endTime: now,
        types: [HealthDataType.SLEEP_IN_BED, HealthDataType.SLEEP_ASLEEP],
      );

      if (sleepData.isNotEmpty) {
        // Simple heuristic: average the wake times and sleep times
        int totalWakeMinutes = 0;
        int totalSleepMinutes = 0;
        int daysCount = 0;

        for (var point in sleepData) {
          if (point.dateTo.difference(point.dateFrom).inHours > 4) {
            totalWakeMinutes += (point.dateTo.hour * 60 + point.dateTo.minute).toInt();
            totalSleepMinutes += (point.dateFrom.hour * 60 + point.dateFrom.minute).toInt();
            daysCount++;
          }
        }

        if (daysCount > 0) {
          final avgWakeMins = totalWakeMinutes ~/ daysCount;
          final avgSleepMins = totalSleepMinutes ~/ daysCount;

          return _buildSchedule(
            wakeHour: avgWakeMins ~/ 60,
            wakeMin: avgWakeMins % 60,
            sleepHour: avgSleepMins ~/ 60,
            sleepMin: avgSleepMins % 60,
          );
        }
      }
    } catch (e) {
      debugPrint('CircadianSyncService: Error fetching health data: $e');
    }

    // Fallback: Standard 7 AM - 10 PM rhythm
    return _buildSchedule(wakeHour: 7, wakeMin: 0, sleepHour: 22, sleepMin: 0);
  }

  CircadianSchedule _buildSchedule({
    required int wakeHour,
    required int wakeMin,
    required int sleepHour,
    required int sleepMin,
  }) {
    final now = DateTime.now();
    final wakeTime = DateTime(now.year, now.month, now.day, wakeHour, wakeMin);
    
    // Default meal offsets from wake time
    // Breakfast 1 hour after waking, Lunch 5 hours, Dinner 11 hours
    final breakfastTime = wakeTime.add(const Duration(hours: 1));
    final lunchTime = wakeTime.add(const Duration(hours: 5));
    final dinnerTime = wakeTime.add(const Duration(hours: 11));
    
    var sleepTime = DateTime(now.year, now.month, now.day, sleepHour, sleepMin);
    if (sleepHour < wakeHour) {
      // Sleep is past midnight
      sleepTime = sleepTime.add(const Duration(days: 1));
    }

    return CircadianSchedule(
      wakeTime: wakeTime,
      breakfastTime: breakfastTime,
      lunchTime: lunchTime,
      dinnerTime: dinnerTime,
      sleepTime: sleepTime,
    );
  }

  DateTime getSupplementTime(SupplementTiming timing, CircadianSchedule schedule) {
    switch (timing) {
      case SupplementTiming.uponWaking:
        return schedule.wakeTime.add(const Duration(minutes: 15));
      case SupplementTiming.withBreakfast:
        return schedule.breakfastTime;
      case SupplementTiming.withLunch:
        return schedule.lunchTime;
      case SupplementTiming.withDinner:
        return schedule.dinnerTime;
      case SupplementTiming.beforeBed:
        return schedule.sleepTime.subtract(const Duration(minutes: 45));
      case SupplementTiming.anytime:
        return schedule.wakeTime.add(const Duration(hours: 3)); // Mid-morning default
    }
  }
}
