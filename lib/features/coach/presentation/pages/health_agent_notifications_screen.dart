import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/health_provider.dart';
import '../../../../core/providers/health_alerts_provider.dart';

class HealthAgentNotificationsScreen extends ConsumerWidget {
  const HealthAgentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAlerts = ref.watch(healthAlertsProvider);
    final healthState = ref.watch(healthDataProvider);
    final health = healthState.valueOrNull ?? HealthData();
    final sleepHours = health.sleepMinutes / 60;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Live Health Alerts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: Colors.cyanAccent,
        backgroundColor: const Color(0xFF1E293B),
        onRefresh: () async {
          await ref.read(healthDataProvider.notifier).syncHealthData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status bar showing real synced stats
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.cyanAccent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Real-Time Daily Summary',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        health.isAuthorized ? '● Live tracker connected' : '○ Offline',
                        style: TextStyle(
                          color: health.isAuthorized ? Colors.greenAccent : Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricSummary('Steps', '${health.steps}', Colors.orangeAccent),
                      _buildMetricSummary('Rest', sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)}h' : '--', Colors.cyanAccent),
                      _buildMetricSummary('Active Energy', '${health.activeEnergy.toInt()} cal', Colors.tealAccent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh. Tap any alert below to receive personal everyday advice from the bot.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),

            if (healthAlerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    'No alerts right now. Your daily habits are on track!',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ),
              )
            else
              ...healthAlerts.map((alert) {
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: alert.color.withValues(alpha: 0.35)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: alert.color.withValues(alpha: 0.15),
                      radius: 22,
                      child: Icon(alert.icon, color: alert.color, size: 22),
                    ),
                    title: Text(
                      alert.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        alert.subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(alert.timeLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        const SizedBox(height: 6),
                        const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                      ],
                    ),
                    onTap: () {
                      if (alert.type == 'sync' && !health.isAuthorized) {
                        ref.read(healthDataProvider.notifier).syncHealthData();
                      }
                      context.push('/chat', extra: alert.toMap());
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSummary(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
