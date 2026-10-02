import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'epigenomic_provider.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/bio_card.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';

class EpigenomicScreen extends ConsumerWidget {
  const EpigenomicScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(epigenomicProvider);
    final notifier = ref.read(epigenomicProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Epigenomic Diffing Engine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isLoading)
              const ClaudeThinkingIndicator(message: 'Diffing 850,000 CpG methylation sites...'),
            if (state.diffResult != null) ...[
              const SectionHeader(title: 'DunedinPACE: Pace of Aging'),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Baseline (6mo ago)', state.diffResult!.baseline.dunedinPACERate.toStringAsFixed(2), Colors.grey)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Colors.white)),
                  Expanded(child: _buildMetricCard('Current', state.diffResult!.current.dunedinPACERate.toStringAsFixed(2), Colors.cyan)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                child: Row(
                  children: [
                    const Icon(Icons.trending_down, color: Colors.green, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AGING DECELERATED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          Text('${(state.diffResult!.paceDelta.abs() * 100).toStringAsFixed(0)}% Slower Aging Rate', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Epigenetic Interpretation'),
              BioCard(title: 'Methylation Silencing', child: Text(state.diffResult!.biologicalInterpretation, style: const TextStyle(color: Colors.white, height: 1.5))),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.runDiffAnalysis(),
              child: const Text('Run DNA Methylation Diff (Demo)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
