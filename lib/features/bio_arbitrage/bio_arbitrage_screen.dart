import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bio_arbitrage_provider.dart';
import 'widgets/reversal_rate_gauge.dart';
import 'widgets/proof_of_reversal_card.dart';
import 'widgets/enterprise_dashboard.dart';
import '../../shared/widgets/claude_thinking_indicator.dart';
import '../../shared/widgets/section_header.dart';

class BioArbitrageScreen extends ConsumerWidget {
  const BioArbitrageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bioArbitrageProvider);
    final notifier = ref.read(bioArbitrageProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biological Age Arbitrage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isLoading)
              const ClaudeThinkingIndicator(message: 'Generating verifiable proof of biological reversal...'),
            if (state.reversalRateScore != null) ...[
              Center(child: ReversalRateGauge(reversalRateMonthsPerYear: state.reversalRateScore!, proofScore: state.proofOfReversalScore!)),
              const SectionHeader(title: 'Proof-of-Reversal Certificate'),
              ProofOfReversalCard(
                proofScore: state.proofOfReversalScore!,
                auditTrail: state.auditTrail!,
                creditsEarned: state.creditsEarned!,
              ),
              const SectionHeader(title: 'Enterprise Value Layer'),
              EnterpriseDashboard(enterpriseValue: state.enterpriseValue!),
              const SizedBox(height: 24),
              const Text('Disclaimer: PoRC scores are generated from deterministic biological modeling. Not financial advice.', style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.loadArbitrage(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Calculate Arbitrage', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
