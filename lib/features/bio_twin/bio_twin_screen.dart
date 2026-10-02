import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bio_twin_provider.dart';
import 'widgets/biological_age_dial.dart';
import 'widgets/hallmarks_degradation_map.dart';
import 'widgets/trajectory_chart.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/bio_card.dart';

class BioTwinScreen extends ConsumerWidget {
  const BioTwinScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bioTwinProvider);
    final notifier = ref.read(bioTwinProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bio-Digital Twin'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00F5FF).withOpacity(0.1), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isLoading)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: const [
                    CircularProgressIndicator(color: Color(0xFF00F5FF)),
                    SizedBox(height: 24),
                    Text('Adversarial Inference Running...', style: TextStyle(fontFamily: 'Sora', fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Running 1M simulation loops', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 16),
                    ClaudeThinkingIndicator(),
                  ],
                ),
              ),
            if (state.result != null) ...[
              Center(
                child: BiologicalAgeDial(
                  chronologicalAge: state.result!.chronologicalAge,
                  biologicalAge: state.result!.biologicalAge,
                  ageGap: state.result!.ageGap,
                  reversalRate: state.result!.reversalRateMonthsPerYear,
                ),
              ),
              const SectionHeader(title: 'Hallmarks of Aging Map'),
              HallmarksDegradationMap(scores: state.result!.hallmarkScores),
              const SectionHeader(title: '6-Month Trajectory'),
              TrajectoryChart(
                projection: state.result!.sixMonthProjection,
                chronologicalAge: state.result!.chronologicalAge,
              ),
              const SectionHeader(title: 'Key Biomarkers'),
              ...state.result!.keyBioMarkers.map((m) {
                final color = m.status == 'optimal' ? Colors.green : (m.status == 'critical' ? Colors.red : Colors.amber);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: BioCard(
                    title: m.name,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${m.value} ${m.unit}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(m.optimalRange, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text(m.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.compileTwin(chronoAge: 38.5, biometrics: {'hrv': 65, 'sleep': 7.5}),
              child: const Text('Compile Bio-Twin'),
            ),
            const SizedBox(height: 8),
            const Text('Powered by adversarial inference', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                color: Colors.red.withOpacity(0.1),
                child: Text(state.error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
