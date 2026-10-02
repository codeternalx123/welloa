import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/kinematic_provider.dart';
import '../../../../shared/widgets/gamified_ai_coach_widget.dart';

class RobustKinematicScreen extends ConsumerStatefulWidget {
  const RobustKinematicScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RobustKinematicScreen> createState() => _RobustKinematicScreenState();
}

class _RobustKinematicScreenState extends ConsumerState<RobustKinematicScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kinematicNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Sweet Spot', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (dose) {
          final isPositive = dose.longevityImpactYears >= 0;
          final color = isPositive ? Colors.greenAccent : Colors.redAccent;
          final impactText = isPositive ? '+${dose.longevityImpactYears} Years' : '${dose.longevityImpactYears} Years';
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Longevity Impact: $impactText',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                  const SizedBox(height: 32),
                  Text(
                    dose.aiQuestion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 32),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: dose.cnsReadiness / 100,
                          strokeWidth: 20,
                          backgroundColor: color.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      Column(
                        children: [
                          Icon(isPositive ? Icons.speed : Icons.warning_amber, size: 48, color: color),
                          const SizedBox(height: 8),
                          Text(
                            '${dose.cnsReadiness.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color),
                          ),
                          Text(
                            isPositive ? 'Sweet Spot' : 'Danger Zone',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetric(dose.metric1Label, dose.metric1Value, color),
                    _buildMetric(dose.metric2Label, dose.metric2Value, color),
                  ],
                ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text('🎯 AI Optimum Daily Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          dose.dailyGoal,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Dopamine Architect Tip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    dose.nextActionTip,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                  ),
                ),
                const SizedBox(height: 32),
                const GamifiedAICoachWidget(domainContext: 'Exercise Sweet Spot'),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => ref.read(kinematicNotifierProvider.notifier).evaluateIntake(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recalculate Dose', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
