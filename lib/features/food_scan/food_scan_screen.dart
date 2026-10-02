import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'food_scan_provider.dart';
import 'widgets/hallmarks_radar.dart';
import 'widgets/age_counter_card.dart';
import 'widgets/polyphenol_prescription.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/bio_card.dart';

class FoodScanScreen extends ConsumerWidget {
  const FoodScanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodScanProvider);
    final notifier = ref.read(foodScanProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phytochemical Scanner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF00F5FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.3)),
              ),
              child: Column(
                children: const [
                  Icon(Icons.camera_alt, size: 80, color: Color(0xFF00F5FF)),
                  SizedBox(height: 16),
                  Text('Point camera at your meal', style: TextStyle(color: Color(0xFF00F5FF))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt), label: const Text('Scan with Camera'))),
                const SizedBox(width: 16),
                Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.photo_library), label: const Text('From Gallery'))),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.analyzeMockFood(),
              child: const Text('Analyze with Claude Vision (Demo)'),
            ),
            const SizedBox(height: 24),
            if (state.isLoading)
              const ClaudeThinkingIndicator(message: 'Claude Vision is mapping phytochemicals to 12 Hallmarks...'),
            if (state.result != null) ...[
              const SectionHeader(title: 'Hallmarks Impact Radar'),
              Center(child: HallmarksRadar(impacts: state.result!.hallmarkImpacts)),
              const SectionHeader(title: 'AGE Biological Cost'),
              AGECounterCard(
                ageScore: state.result!.totalAgeScore,
                polyphenolScore: state.result!.polyphenolScore,
                bioAgeCostMinutes: state.result!.biologicalAgeCostMinutes,
              ),
              const SectionHeader(title: 'Phytochemical Analysis'),
              ...state.result!.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: BioCard(
                  title: item.name,
                  subtitle: 'AGE Score: ${item.ageScore}',
                  child: Text('Phytochemicals: ${item.phytochemicals.join(', ')}', style: const TextStyle(color: Colors.grey)),
                ),
              )),
              const SectionHeader(title: 'Wellness Suggestion'),
              PolyphenolGuidance(guidanceList: state.result!.guidanceList, portionLimits: state.result!.portionLimits),
            ],
          ],
        ),
      ),
    );
  }
}
