import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/aeg_ddd_provider.dart';
import '../../../../shared/widgets/claude_thinking_indicator.dart';

class RobustAEGScreen extends ConsumerWidget {
  const RobustAEGScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aegDDDNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aging Clock', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: state.when(
        loading: () => const Center(child: ClaudeThinkingIndicator(message: 'Calculating your true biological pace...')),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load aging clock', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(aegDDDNotifierProvider.notifier).triggerSynthesis(),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
        data: (entity) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1F2937),
                  border: Border.all(
                    color: entity.biologicalNetworkHealth > 80 ? Colors.green : (entity.biologicalNetworkHealth > 60 ? Colors.amber : Colors.redAccent),
                    width: 4,
                  ),
                ),
                child: Column(
                  children: [
                    const Text('Vitality Score', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '${entity.biologicalNetworkHealth.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
                    ),
                    const Text('/ 100', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              const Text('What is holding you back?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Bottleneck', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(entity.graph.criticalBottleneck, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('How to fix it', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(entity.topPriorityAction, style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
