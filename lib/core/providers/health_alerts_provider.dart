import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'health_provider.dart';

class HealthAlert {
  final String id;
  final String type; // 'sleep', 'steps', 'energy', 'hydration', 'sync'
  final String title;
  final String subtitle;
  final String timeLabel;
  final Color color;
  final IconData icon;
  final Map<String, dynamic> realMetrics;

  const HealthAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.color,
    required this.icon,
    required this.realMetrics,
  });

  String get summaryText => '$title: $subtitle';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'timeLabel': timeLabel,
      'realMetrics': realMetrics,
    };
  }
}

final healthAlertsProvider = Provider<List<HealthAlert>>((ref) {
  final healthState = ref.watch(healthDataProvider);
  final health = healthState.valueOrNull ?? HealthData();

  final sleepHours = health.sleepMinutes / 60;
  final steps = health.steps;
  final activeCalories = health.activeEnergy.toInt();
  final isAuthorized = health.isAuthorized;

  final List<HealthAlert> alerts = [];

  // 1. Health Sync Alert (if not authorized, alert user with real device status)
  if (!isAuthorized) {
    alerts.add(
      HealthAlert(
        id: 'sync_prompt',
        type: 'sync',
        title: '📱 Connect Live Tracker',
        subtitle: 'Tap to connect your step counter and sleep tracker so all alerts show your live daily progress.',
        timeLabel: 'Tracker sync',
        color: const Color(0xFF38BDF8),
        icon: Icons.sync,
        realMetrics: {
          'isAuthorized': false,
        },
      ),
    );
  }

  // 2. Real Sleep Alert (Zero medical jargon, strictly real hours)
  if (sleepHours > 0 && sleepHours < 6.0) {
    alerts.add(
      HealthAlert(
        id: 'sleep_low',
        type: 'sleep',
        title: '😴 Catch Up on Sleep',
        subtitle: 'You logged ${sleepHours.toStringAsFixed(1)} hours of rest. Going to bed 30 minutes earlier tonight will recharge your body.',
        timeLabel: 'Sleep tracker',
        color: const Color(0xFFFBBF24),
        icon: Icons.bedtime,
        realMetrics: {
          'sleepHours': sleepHours,
          'sleepMinutes': health.sleepMinutes,
        },
      ),
    );
  } else if (sleepHours >= 7.5) {
    alerts.add(
      HealthAlert(
        id: 'sleep_great',
        type: 'sleep',
        title: '✨ Fully Recharged',
        subtitle: 'Great job! You logged ${sleepHours.toStringAsFixed(1)} hours of sleep. Your body had plenty of time to rest and refresh.',
        timeLabel: 'Sleep tracker',
        color: const Color(0xFF34D399),
        icon: Icons.nights_stay,
        realMetrics: {
          'sleepHours': sleepHours,
          'sleepMinutes': health.sleepMinutes,
        },
      ),
    );
  } else if (sleepHours > 0) {
    alerts.add(
      HealthAlert(
        id: 'sleep_normal',
        type: 'sleep',
        title: '🌙 Steady Rest',
        subtitle: 'You got ${sleepHours.toStringAsFixed(1)} hours of rest. Putting your phone down 20 minutes before bed will help you rest even deeper.',
        timeLabel: 'Sleep tracker',
        color: const Color(0xFF22D3EE),
        icon: Icons.bedtime_outlined,
        realMetrics: {
          'sleepHours': sleepHours,
          'sleepMinutes': health.sleepMinutes,
        },
      ),
    );
  } else {
    alerts.add(
      HealthAlert(
        id: 'sleep_untracked',
        type: 'sleep',
        title: '🌙 Ready for Rest',
        subtitle: 'No sleep logged yet for last night. Remember to wear your tracker tonight for tomorrow\'s morning summary.',
        timeLabel: 'Sleep tracker',
        color: const Color(0xFF818CF8),
        icon: Icons.bedtime_outlined,
        realMetrics: {
          'sleepHours': 0.0,
          'sleepMinutes': 0.0,
        },
      ),
    );
  }

  // 3. Real Steps & Movement Alert
  if (steps == 0) {
    alerts.add(
      HealthAlert(
        id: 'steps_zero',
        type: 'steps',
        title: '👟 Start Moving',
        subtitle: 'You have 0 steps recorded so far today. Put on your shoes and take a short 5-minute stroll to kick off your day.',
        timeLabel: 'Live steps',
        color: const Color(0xFFFB923C),
        icon: Icons.directions_walk,
        realMetrics: {'steps': 0},
      ),
    );
  } else if (steps < 4000) {
    alerts.add(
      HealthAlert(
        id: 'steps_low',
        type: 'steps',
        title: '🚶 Quick Step Refresh',
        subtitle: 'You have taken $steps steps today. A short 10-minute stroll around the block will lift your mood and wake up your legs.',
        timeLabel: 'Live steps',
        color: const Color(0xFFFB923C),
        icon: Icons.directions_walk,
        realMetrics: {'steps': steps},
      ),
    );
  } else if (steps >= 8000) {
    alerts.add(
      HealthAlert(
        id: 'steps_high',
        type: 'steps',
        title: '🏆 Fantastic Step Count!',
        subtitle: 'You reached $steps steps today! Walking this much keeps your heart strong and your joints flexible.',
        timeLabel: 'Live steps',
        color: const Color(0xFF4ADE80),
        icon: Icons.emoji_events,
        realMetrics: {'steps': steps},
      ),
    );
  } else {
    alerts.add(
      HealthAlert(
        id: 'steps_mid',
        type: 'steps',
        title: '👟 Keep Moving',
        subtitle: "You're at $steps steps today. Taking the stairs or a quick afternoon walk will easily get you to your 8,000 goal.",
        timeLabel: 'Live steps',
        color: const Color(0xFF60A5FA),
        icon: Icons.directions_walk,
        realMetrics: {'steps': steps},
      ),
    );
  }

  // 4. Real Active Energy Burn Alert
  if (activeCalories == 0) {
    alerts.add(
      const HealthAlert(
        id: 'energy_zero',
        type: 'energy',
        title: '⚡ Wake Up Your Body',
        subtitle: 'No active calories burned yet today. Stand up, stretch your arms overhead, and roll your shoulders.',
        timeLabel: 'Energy burn',
        color: Color(0xFFC084FC),
        icon: Icons.bolt,
        realMetrics: {'activeCalories': 0},
      ),
    );
  } else if (activeCalories < 250) {
    alerts.add(
      HealthAlert(
        id: 'energy_low',
        type: 'energy',
        title: '⚡ Stretch & Shake It Out',
        subtitle: 'You have burned $activeCalories active calories today. Stand up, take a walk, and take a couple of deep breaths.',
        timeLabel: 'Energy burn',
        color: const Color(0xFFC084FC),
        icon: Icons.bolt,
        realMetrics: {'activeCalories': activeCalories},
      ),
    );
  } else {
    alerts.add(
      HealthAlert(
        id: 'energy_high',
        type: 'energy',
        title: '🔥 Active Day!',
        subtitle: "You've burned $activeCalories active calories through movement. Fantastic effort staying active and keeping your stamina up.",
        timeLabel: 'Energy burn',
        color: const Color(0xFF2DD4BF),
        icon: Icons.local_fire_department,
        realMetrics: {'activeCalories': activeCalories},
      ),
    );
  }

  // 5. Real Time-of-Day Hydration & Fresh Food Alert
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) {
    alerts.add(
      HealthAlert(
        id: 'nourish_morning',
        type: 'hydration',
        title: '💧 Morning Fresh Start',
        subtitle: 'Drink a tall glass of cool water right now to wake up your body and get your digestion moving smoothly.',
        timeLabel: 'Morning habit',
        color: const Color(0xFF38BDF8),
        icon: Icons.water_drop,
        realMetrics: {'hour': hour},
      ),
    );
  } else if (hour >= 12 && hour < 17) {
    alerts.add(
      HealthAlert(
        id: 'nourish_afternoon',
        type: 'hydration',
        title: '🥗 Afternoon Fuel & Water',
        subtitle: 'Drink a glass of water and enjoy crisp greens or fresh fruit to beat the midday slump and keep your head clear.',
        timeLabel: 'Afternoon habit',
        color: const Color(0xFF4ADE80),
        icon: Icons.eco,
        realMetrics: {'hour': hour},
      ),
    );
  } else if (hour >= 17 && hour < 22) {
    alerts.add(
      HealthAlert(
        id: 'nourish_evening',
        type: 'hydration',
        title: '🍵 Evening Recharge',
        subtitle: 'Sip a warm herbal tea or water with dinner, and start winding down so your body can prepare for restful sleep.',
        timeLabel: 'Evening habit',
        color: const Color(0xFFA78BFA),
        icon: Icons.nightlife,
        realMetrics: {'hour': hour},
      ),
    );
  } else {
    alerts.add(
      HealthAlert(
        id: 'nourish_night',
        type: 'hydration',
        title: '🌙 Rest & Hydrate',
        subtitle: 'Take a small sip of water, put down screens, and let your eyes rest for a deep, revitalizing sleep.',
        timeLabel: 'Night habit',
        color: const Color(0xFF818CF8),
        icon: Icons.bedtime,
        realMetrics: {'hour': hour},
      ),
    );
  }

  return alerts;
});
