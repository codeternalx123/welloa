import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'insights_provider.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/bio_card.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';

class PharmacogenomicScreen extends ConsumerWidget {
  const PharmacogenomicScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pharmacogenomicProvider);
    final notifier = ref.read(pharmacogenomicProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrigenomics Insights Engine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isLoading)
              const ClaudeThinkingIndicator(message: 'Cross-referencing CYP450 enzyme genetic pathways...'),
            if (state.result != null) ...[
              const SectionHeader(title: 'Genetic Enzyme Profile'),
              ...state.result!.geneticProfile.map((enzyme) {
                final color = enzyme.metabolizerStatus == 'Normal' ? Colors.green : (enzyme.metabolizerStatus == 'Rapid' ? Colors.cyan : Colors.amber);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: BioCard(
                    title: '${enzyme.geneName} [${enzyme.genotype}]',
                    accentColor: color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text('${enzyme.metabolizerStatus} Metabolizer'.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(enzyme.impactDescription, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                );
              }),
              const SectionHeader(title: 'Tailored Phytochemical Guidances'),
              ...state.result!.tailoredGuidances.map((insights) {
                final isSafe = insights.riskLevel == 'Safe';
                final isContra = insights.riskLevel == 'Caution Advised';
                final color = isContra ? Colors.red : (isSafe ? Colors.green : Colors.amber);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(insights.compoundName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Icon(isContra ? Icons.block : (isSafe ? Icons.check_circle : Icons.warning), color: color),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildIntakeText('Standard Intake', '${insights.standardIntakeMg} mg', Colors.grey)),
                            const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                            Expanded(child: _buildIntakeText('Your Tailored Intake', insights.personalizedIntakeMg > 0 ? '${insights.personalizedIntakeMg} mg' : 'AVOID', color)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Genetic Driver: ${insights.responsibleEnzyme}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(insights.adjustmentRationale, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.runGeneticSynthesis(),
              child: const Text('Analyze Genomic Interactions (Demo)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntakeText(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
