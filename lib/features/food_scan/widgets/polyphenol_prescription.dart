import 'package:flutter/material.dart';

class PolyphenolGuidance extends StatelessWidget {
  final List<String> guidanceList;
  final List<String> portionLimits;

  const PolyphenolGuidance({
    Key? key,
    required this.guidanceList,
    required this.portionLimits,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        border: const Border(left: BorderSide(color: Color(0xFF00F5FF), width: 3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Insights: Polyphenol Counter-Intake', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF00F5FF).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('PRESCRIPTION', style: TextStyle(color: Color(0xFF00F5FF), fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...guidanceList.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•', style: TextStyle(color: Color(0xFF00F5FF), fontSize: 18, height: 1)),
                const SizedBox(width: 8),
                Expanded(child: Text(p, style: const TextStyle(color: Colors.grey, fontSize: 13))),
              ],
            ),
          )),
          if (portionLimits.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text('Portion Limits', style: TextStyle(color: Colors.amber, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            ...portionLimits.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l, style: const TextStyle(color: Colors.amber, fontSize: 12))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
