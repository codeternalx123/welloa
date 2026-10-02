import 'package:flutter/material.dart';
import '../../../core/models/causal_insight.dart';
import '../../../shared/widgets/bio_card.dart';

class CounterfactualExplorer extends StatelessWidget {
  final List<CounterfactualScenario> counterfactuals;

  const CounterfactualExplorer({Key? key, required this.counterfactuals}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: counterfactuals.map((cf) {
        final isBetter = cf.deltaVsActual < 0;
        final color = isBetter ? Colors.green : Colors.red;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: BioCard(
            title: cf.description,
            accentColor: color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Changed: ${cf.changedVariable} → ${cf.changedValue}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(isBetter ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text('${cf.deltaVsActual.abs().toStringAsFixed(1)} hrs ${isBetter ? 'BETTER' : 'WORSE'}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Alternative outcome: ${cf.alternativeOutcome.toStringAsFixed(1)} hours', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
