import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/discover/presentation/providers/dynamic_unicorn_provider.dart';
import 'unicorn_score_screen.dart';
import '../widgets/claude_thinking_indicator.dart';
import '../../shared/widgets/gamified_ai_coach_widget.dart';

class DynamicUnicornScreen extends ConsumerWidget {
  final String domain;
  final String loadingTitle;
  final IconData icon;
  final Color themeColor;

  const DynamicUnicornScreen({
    Key? key,
    required this.domain,
    required this.loadingTitle,
    required this.icon,
    required this.themeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dynamicUnicornProvider(domain));

    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClaudeThinkingIndicator(message: 'Synthesizing Health Connect Data for \$loadingTitle...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load insights', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        data: (insightsList) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ...insightsList.map((insights) => UnicornScoreCard(
                title: insights['title'] ?? loadingTitle,
                metricName: insights['metricName'] ?? 'Metric',
                score: insights['score'] ?? 'N/A',
                subtitle: insights['subtitle'] ?? '',
                advice: insights['advice'] ?? '',
                themeColor: themeColor,
                icon: icon,
                longevityImpact: insights['longevityImpact'] ?? '',
              )).toList(),
              const SizedBox(height: 32),
              if (domain == 'dna' || domain == 'sleep')
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => context.push(domain == 'dna' ? '/discover/dna/input' : '/discover/sleep/input'),
                    icon: const Icon(Icons.edit_note, color: Colors.white),
                    label: const Text('Input Real Data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              if (domain == 'dna' || domain == 'sleep')
                const SizedBox(height: 32),
              GamifiedAICoachWidget(domainContext: loadingTitle),
            ],
          );
        },
      ),
      ),
    );
  }
}
