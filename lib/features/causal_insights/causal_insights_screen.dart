import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'causal_provider.dart';
import 'widgets/causal_dag_view.dart';
import 'widgets/temporal_impact_card.dart';
import 'widgets/counterfactual_explorer.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/bio_card.dart';

class CausalInsightsScreen extends ConsumerWidget {
  const CausalInsightsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(causalProvider);
    final notifier = ref.read(causalProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Causal Feedback Engine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip(0, 'Carb + Sleep Deficit', state.selectedPreset, notifier),
                  const SizedBox(width: 8),
                  _buildPresetChip(1, 'HIIT + Dehydration', state.selectedPreset, notifier),
                  const SizedBox(width: 8),
                  _buildPresetChip(2, 'Stress + Fasting', state.selectedPreset, notifier),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (state.isLoading)
              const ClaudeThinkingIndicator(message: 'Running do-calculus adjustmental queries...'),
            if (state.result != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
                child: Text(state.result!.doOperatorQuery, style: const TextStyle(fontFamily: 'monospace', color: Colors.cyan, fontSize: 12)),
              ),
              const SectionHeader(title: 'Input Variables'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.result!.inputVariables.map((v) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8)),
                  child: Text('${v.name}: ${v.value}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
              ),
              const SectionHeader(title: 'Causal Directed Graph'),
              CausalDAGView(variables: state.result!.inputVariables, outcome: state.result!.outcome),
              const SectionHeader(title: 'Temporal Impact Analysis'),
              TemporalImpactCard(outcome: state.result!.outcome, causalConfidence: state.result!.causalConfidence),
              const SectionHeader(title: 'Counterfactual Explorer'),
              CounterfactualExplorer(counterfactuals: state.result!.counterfactuals),
              const SectionHeader(title: 'Causal Narrative'),
              BioCard(title: 'Reasoning Synthesis', child: Text(state.result!.narrative, style: const TextStyle(color: Colors.white, height: 1.5))),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.runMockInference(),
              child: const Text('Run Causal Inference (Demo)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(int index, String label, int selectedIndex, CausalNotifier notifier) {
    final isSelected = index == selectedIndex;
    return InkWell(
      onTap: () => notifier.selectPreset(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F5FF) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}
