import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/gamified_ai_coach_widget.dart';
import '../../../../shared/widgets/unicorn_glass_card.dart';
import '../../../../shared/widgets/animated_glow_border.dart';
import '../../../../shared/widgets/mesh_background.dart';
import '../../../../core/providers/profile_provider.dart';
import '../providers/sleep_provider.dart';

class SleepDashboardScreen extends ConsumerWidget {
  const SleepDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepState = ref.watch(sleepNotifierProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Deep Brain Cleaning', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: MeshBackground(
        tier: profile.tier,
        child: SafeArea(
          child: sleepState.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Claude is analyzing your sleep telemetry...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (sleepData) {
          final isPositive = sleepData.longevityImpactYears >= 0;
          final impactColor = isPositive ? Colors.greenAccent : Colors.redAccent;
          final impactText = isPositive ? '+${sleepData.longevityImpactYears} Years' : '${sleepData.longevityImpactYears} Years';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: UnicornGlassCard(
                    glowColor: impactColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    borderRadius: 20,
                    margin: EdgeInsets.zero,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: impactColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Longevity Impact: $impactText',
                          style: TextStyle(color: impactColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  sleepData.aiQuestion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.amberAccent),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.indigoAccent.withOpacity(0.3), width: 4),
                        ),
                      ),
                      const Icon(Icons.psychology, size: 140, color: Colors.indigoAccent),
                      Positioned(
                        bottom: 40,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${sleepData.clearancePercentage}% Cleared',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const GamifiedAICoachWidget(domainContext: 'Deep Brain Cleaning'),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildWashMetric(sleepData.metric1Label, sleepData.metric1Value, Colors.greenAccent),
                    _buildWashMetric(sleepData.metric2Label, sleepData.metric2Value, Colors.blueAccent),
                  ],
                ),
                const SizedBox(height: 32),
                AnimatedGlowBorder(
                  glowColor: Colors.purple,
                  child: UnicornGlassCard(
                    padding: const EdgeInsets.all(20),
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        const Text('🎯 AI Optimum Daily Goal', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          sleepData.dailyGoal,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Dopamine Architect Tip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                UnicornGlassCard(
                  glowColor: Colors.indigoAccent,
                  padding: const EdgeInsets.all(16),
                  margin: EdgeInsets.zero,
                  child: Text(
                    sleepData.nextActionTip,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ref.read(sleepNotifierProvider.notifier).fetchSleepData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _buildWashMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
