import 'package:flutter/material.dart';
import '../../../core/models/aeg_node.dart';
import '../../../shared/widgets/bio_card.dart';

class NodeDetailPanel extends StatelessWidget {
  final AEGNode? selectedNode;
  final AEGGraph? graph;

  const NodeDetailPanel({Key? key, this.selectedNode, this.graph}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedNode != null) {
      return BioCard(
        title: selectedNode!.label,
        subtitle: 'Type: ${selectedNode!.nodeType.toUpperCase()}',
        accentColor: selectedNode!.status == 'critical' ? Colors.red : (selectedNode!.status == 'suboptimal' ? Colors.amber : Colors.green),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Value:', style: TextStyle(color: Colors.grey)),
                Text('${selectedNode!.currentValue} ${selectedNode!.unit}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Optimal Range:', style: TextStyle(color: Colors.grey)),
                Text('${selectedNode!.optimalValue} ${selectedNode!.unit}', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ),
      );
    }

    if (graph != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Systemic Synthesis', style: TextStyle(fontFamily: 'Sora', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyan)),
            const SizedBox(height: 12),
            Text(graph!.synthesisNarrative, style: const TextStyle(color: Colors.grey, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.cyan.withOpacity(0.3))),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.cyan),
                  const SizedBox(width: 8),
                  Expanded(child: Text(graph!.criticalBottleneck, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
