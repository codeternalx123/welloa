import 'package:flutter/material.dart';
import '../bio_arbitrage_provider.dart';
import '../domain/repositories/bio_arbitrage_repository.dart';

class ProofOfReversalCard extends StatelessWidget {
  final double proofScore;
  final List<AuditEntryEntity> auditTrail;
  final double creditsEarned;

  const ProofOfReversalCard({
    Key? key,
    required this.proofScore,
    required this.auditTrail,
    required this.creditsEarned,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: Color(0xFF8B5CF6))),
            ),
            child: Column(
              children: [
                const Text('PROOF-OF-REVERSAL CERTIFICATE', style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF8B5CF6), size: 24),
                    const SizedBox(width: 8),
                    Text('PoRC Score: ${proofScore.toStringAsFixed(1)} / 100', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Longevity Credits Earned:', style: TextStyle(color: Colors.grey)),
                    Text('${creditsEarned.toStringAsFixed(1)} LC', style: const TextStyle(color: Color(0xFF00F5FF), fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 32, color: Colors.grey),
                const Align(alignment: Alignment.centerLeft, child: Text('AUDITABLE CAUSAL CHAIN', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.2))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: auditTrail.length,
                    itemBuilder: (context, index) {
                      final entry = auditTrail[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6, right: 12), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF8B5CF6))),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.event, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                      Text('${entry.date.month}/${entry.date.day}/${entry.date.year}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Bio Age: ${entry.biologicalAgeAtTime.toStringAsFixed(2)} | Hash: ${entry.verificationHash}', style: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
