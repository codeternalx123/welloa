import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'aeg_provider.dart';
import 'widgets/graph_canvas.dart';
import 'widgets/node_detail_panel.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';
import '../../shared/widgets/section_header.dart';

class AEGGraphScreen extends ConsumerWidget {
  const AEGGraphScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aegProvider);
    final notifier = ref.read(aegProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AEG Biological Network'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isLoading)
              const ClaudeThinkingIndicator(message: 'Synthesizing multi-node causal graph...'),
            if (state.result != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NETWORK HEALTH', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${state.result!.biologicalNetworkHealth.toStringAsFixed(1)} / 100', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text('Bottleneck: ${state.result!.graph.criticalBottleneck}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: GraphCanvas(graph: state.result!.graph),
              ),
              const SizedBox(height: 16),
              NodeDetailPanel(graph: state.result!.graph),
              const SectionHeader(title: 'Top Priority Action'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
                child: Text(state.result!.topPriorityAction, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.synthesizeMockGraph(),
              child: const Text('Synthesize Network (Demo)'),
            ),
          ],
        ),
      ),
    );
  }
}
