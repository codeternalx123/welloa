import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kinematic_provider.dart';
import 'widgets/hrv_sleep_panel.dart';
import 'widgets/hormetic_zone_gauge.dart';
import 'widgets/workout_recompiler_card.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/bio_card.dart';

class KinematicDashboard extends ConsumerWidget {
  const KinematicDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kinematicProvider);
    final notifier = ref.read(kinematicProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kinematic Routine Engine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.result != null) ...[
              const SectionHeader(title: 'Biometric Inputs'),
              HRVSleepPanel(
                hrv: state.result!.hrvScore,
                sleepScore: state.result!.sleepScore,
                weightDelta: state.result!.weightDeltaKg,
                cnsScore: state.result!.cnsReadinessScore,
              ),
              const SectionHeader(title: 'Hormetic Zone Assessment'),
              Center(
                child: HormeticZoneGauge(
                  cnsReadinessScore: state.result!.cnsReadinessScore,
                  currentZone: state.result!.hormeticZone,
                ),
              ),
              const SectionHeader(title: 'Workout Guidance'),
              WorkoutRecompilerCard(
                original: state.result!.originalPlan,
                recompiled: state.result!.recompiledWorkout,
                wasIntercepted: state.result!.wasIntercepted,
              ),
              const SizedBox(height: 16),
              BioCard(
                title: 'Readiness Narrative',
                child: Text(state.result!.readinessNarrative, style: const TextStyle(color: Colors.white, height: 1.5)),
              ),
              const SizedBox(height: 24),
            ],
            if (state.isLoading)
              const ClaudeThinkingIndicator(message: 'Evaluating CNS readiness and recompiling workout...'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : () => notifier.evaluateMockIntake(),
                    child: const Text('Evaluate (Demo)'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Load Real Data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
