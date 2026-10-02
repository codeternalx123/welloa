import 'package:flutter/material.dart';
import '../../../core/models/causal_insight.dart';

class TemporalImpactCard extends StatelessWidget {
  final CausalOutcome outcome;
  final double causalConfidence;

  const TemporalImpactCard({
    Key? key,
    required this.outcome,
    required this.causalConfidence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TEMPORAL IMPACT', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              if (causalConfidence > 0.8)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Text('do-operator confirmed', style: TextStyle(color: Colors.green, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(outcome.metric, style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text('${outcome.value.toStringAsFixed(1)} ${outcome.unit}', style: const TextStyle(color: Colors.red, fontSize: 42, fontWeight: FontWeight.bold)),
          Text('TEMPORAL EXTENT: ${outcome.temporalExtentHours.toStringAsFixed(1)} HOURS', style: const TextStyle(color: Colors.amber, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
          const Divider(height: 24, color: Colors.grey),
          Text(outcome.description, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
          const Divider(height: 24, color: Colors.grey),
          const Text('Causal Confidence vs. Correlation', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Causal (do-operator): ${(causalConfidence * 100).toInt()}%', style: const TextStyle(color: Colors.cyan, fontSize: 12)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: causalConfidence, color: Colors.cyan, backgroundColor: Colors.grey.withOpacity(0.2)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Correlation only: ~52%', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: 0.52, color: Colors.grey, backgroundColor: Colors.grey.withOpacity(0.2)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
