import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/causal_ddd_provider.dart';
import '../../../../shared/widgets/claude_thinking_indicator.dart';
import '../../../../shared/widgets/unicorn_glass_card.dart';
import '../../../../shared/widgets/animated_glow_border.dart';
import '../../../../shared/widgets/mesh_background.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/health_provider.dart';

class RobustCausalScreen extends ConsumerStatefulWidget {
  const RobustCausalScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RobustCausalScreen> createState() => _RobustCausalScreenState();
}

class _RobustCausalScreenState extends ConsumerState<RobustCausalScreen> {
  @override
  void initState() {
    super.initState();
    // Run the initial query on the next frame so providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(causalDDDNotifierProvider.notifier);
      final healthState = ref.read(healthDataProvider);
      notifier.runQuery(0, healthState.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(causalDDDNotifierProvider);
    final notifier = ref.read(causalDDDNotifierProvider.notifier);
    final profile = ref.watch(profileProvider);
    final healthState = ref.watch(healthDataProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Why It Matters', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: MeshBackground(
        tier: profile.tier,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select a scenario to explore:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip(0, 'Carbs + Low Sleep', state.selectedPreset, notifier, healthState.value),
                      const SizedBox(width: 8),
                      _buildPresetChip(1, 'HIIT + Dehydration', state.selectedPreset, notifier, healthState.value),
                      const SizedBox(width: 8),
                      _buildPresetChip(2, 'Stress + Fasting', state.selectedPreset, notifier, healthState.value),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                state.insight.when(
                  loading: () => const ClaudeThinkingIndicator(message: 'Analyzing the hidden cause and effect...'),
                  error: (err, stack) => AnimatedGlowBorder(
                    glowColor: Colors.redAccent,
                    child: UnicornGlassCard(
                      padding: const EdgeInsets.all(24),
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          const Text('Insight Generation Failed', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.2)),
                            onPressed: () => notifier.runQuery(state.selectedPreset, healthState.value),
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('Retry Analysis', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    ),
                  ),
                  data: (entity) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedGlowBorder(
                        glowColor: Colors.purpleAccent,
                        child: UnicornGlassCard(
                          padding: const EdgeInsets.all(20),
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.lightbulb_outline, color: Colors.cyanAccent),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text('The Hidden Cause', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.purpleAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.radar, color: Colors.purpleAccent, size: 16),
                                        const SizedBox(width: 6),
                                        Text('${(entity.causalConfidence * 100).toInt()}% Confidence', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(entity.narrative, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Actionable Counterfactuals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      ...entity.counterfactuals.map((cf) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: UnicornGlassCard(
                          padding: const EdgeInsets.all(16),
                          margin: EdgeInsets.zero,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.auto_graph, color: Colors.greenAccent, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cf.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 14),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text('+${cf.deltaVsActual.abs().toStringAsFixed(1)} hrs lifespan projection', 
                                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(int index, String label, int selectedIndex, CausalDDDNotifier notifier, HealthData? healthData) {
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => notifier.selectPreset(index, healthData),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

