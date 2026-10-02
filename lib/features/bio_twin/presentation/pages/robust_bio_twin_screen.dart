import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bio_twin_ddd_provider.dart';
import '../../widgets/biological_age_dial.dart';
import '../../widgets/trajectory_chart.dart';
import '../../../../shared/widgets/claude_thinking_indicator.dart';
import '../../../../shared/presentation/unicorn_score_screen.dart';

final unicornSimulatorInsightsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final claude = ref.read(btClaudeServiceProvider);
  final health = ref.read(btHealthServiceProvider);
  final biometrics = await health.getFullBiometrics();
  
  final dna = await claude.generateUnicornInsights(domain: 'dna', healthData: biometrics);
  final gut = await claude.generateUnicornInsights(domain: 'gut', healthData: biometrics);
  
  return [...dna.take(1), ...gut.take(1)]; // Take top insight from each core domain
});

class GamifiedLoadingSequencer extends StatefulWidget {
  const GamifiedLoadingSequencer({Key? key}) : super(key: key);

  @override
  State<GamifiedLoadingSequencer> createState() => _GamifiedLoadingSequencerState();
}

class _GamifiedLoadingSequencerState extends State<GamifiedLoadingSequencer> {
  int _currentIndex = 0;
  Timer? _timer;
  
  final List<String> _steps = [
    "Sequencing DNA Wear and Tear...",
    "Scanning for Zombie Cells...",
    "Mapping Gut Bacteria Balance...",
    "Projecting Biological Age Trajectory...",
    "Applying Advanced Longevity Hacks...",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _steps.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.purpleAccent),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _steps[_currentIndex],
              key: ValueKey(_currentIndex),
              style: const TextStyle(
                color: Colors.purpleAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Building your Future Self Simulator...",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class RobustBioTwinScreen extends ConsumerWidget {
  const RobustBioTwinScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bioTwinDDDNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Future Self Simulator', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: state.when(
        loading: () => const GamifiedLoadingSequencer(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load simulation', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(bioTwinDDDNotifierProvider.notifier).executeCompilationPipeline(forceRefresh: true),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
        data: (twin) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: BiologicalAgeDial(
                  chronologicalAge: twin.chronologicalAge,
                  biologicalAge: twin.biologicalAge,
                  ageGap: twin.ageGap,
                  reversalRate: twin.reversalRateMonthsPerYear,
                ),
              ),
              const SizedBox(height: 24),
              const Text('Aging Pace Projection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TrajectoryChart(
                projection: twin.sixMonthProjection,
                chronologicalAge: twin.chronologicalAge,
              ),
              const SizedBox(height: 24),
              const Text('What\'s driving this?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...twin.keyBioMarkers.map((m) {
                final color = m.status == 'optimal' ? Colors.green : (m.status == 'critical' ? Colors.red : Colors.amber);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        Row(
                          children: [
                            Text('${m.value} ${m.unit}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              
              // UNICORN FEATURES (INDUSTRY PAIN POINTS)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purpleAccent.withOpacity(0.1), Colors.blueAccent.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                        SizedBox(width: 8),
                        Text('Industry-Leading Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Addressing the biggest unsolved questions in longevity mapping.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 24),
                    
                    Consumer(
                      builder: (context, ref, child) {
                        final insightsAsync = ref.watch(unicornSimulatorInsightsProvider);
                        return insightsAsync.when(
                          loading: () => const ClaudeThinkingIndicator(message: "Fetching DNA & Gut Data..."),
                          error: (e, s) => Text('Error loading insights: $e'),
                          data: (insights) {
                            return Column(
                              children: insights.map((insight) {
                                return UnicornScoreCard(
                                  title: insight['title'] ?? 'Insight',
                                  metricName: insight['metricName'] ?? '',
                                  score: insight['score'] ?? '',
                                  subtitle: insight['subtitle'] ?? '',
                                  advice: insight['advice'] ?? '',
                                  longevityImpact: insight['longevityImpact'] ?? '',
                                  themeColor: insight['title'].toString().contains('DNA') ? Colors.purpleAccent : Colors.tealAccent,
                                  icon: insight['title'].toString().contains('DNA') ? Icons.science : Icons.spa,
                                );
                              }).toList(),
                            );
                          },
                        );
                      }
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(bioTwinDDDNotifierProvider.notifier).executeCompilationPipeline(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Update Simulation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
