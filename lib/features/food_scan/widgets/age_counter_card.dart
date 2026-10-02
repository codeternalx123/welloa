import 'package:flutter/material.dart';

class AGECounterCard extends StatelessWidget {
  final double ageScore;
  final double polyphenolScore;
  final double bioAgeCostMinutes;

  const AGECounterCard({
    Key? key,
    required this.ageScore,
    required this.polyphenolScore,
    required this.bioAgeCostMinutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color ageColor = ageScore < 30 ? const Color(0xFF10B981) : (ageScore < 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    
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
            children: const [
              Text('AGE Score', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.info_outline, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ageScore.toStringAsFixed(1),
            style: TextStyle(color: ageColor, fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const Text('Advanced Glycation Endpoints (lower is better)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const Divider(height: 24, color: Colors.grey),
          const Text('Polyphenol Counter-Score', style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: polyphenolScore / 100,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: const Color(0xFF00F5FF),
          ),
          const SizedBox(height: 4),
          Text('${polyphenolScore.toStringAsFixed(1)} / 100', style: const TextStyle(color: Colors.cyan)),
          const Divider(height: 24, color: Colors.grey),
          if (bioAgeCostMinutes < 0)
            Text('▲ ${bioAgeCostMinutes.abs().toStringAsFixed(1)} min GAINED', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
          else
            Text('▼ ${bioAgeCostMinutes.toStringAsFixed(1)} min LOST', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          const Text('Net biological age impact of this meal', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
