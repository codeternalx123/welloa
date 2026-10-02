import 'package:flutter/material.dart';

class HRVSleepPanel extends StatelessWidget {
  final double hrv;
  final double sleepScore;
  final double weightDelta;
  final double cnsScore;

  const HRVSleepPanel({
    Key? key,
    required this.hrv,
    required this.sleepScore,
    required this.weightDelta,
    required this.cnsScore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color hrvColor = hrv > 65 ? Colors.green : (hrv > 45 ? Colors.amber : Colors.red);
    Color sleepColor = sleepScore > 75 ? Colors.green : (sleepScore > 55 ? Colors.amber : Colors.red);
    Color weightColor = weightDelta.abs() > 0.5 ? Colors.amber : Colors.green;
    Color cnsColor = cnsScore > 70 ? Colors.green : (cnsScore > 40 ? Colors.amber : Colors.red);
    String cnsLabel = cnsScore > 70 ? 'HIGH' : (cnsScore > 40 ? 'MODERATE' : 'LOW');

    return Column(
      children: [
        Row(
          children: [
            _buildTile('HRV', '${hrv.toStringAsFixed(0)} ms', hrvColor),
            const SizedBox(width: 8),
            _buildTile('Sleep', '${sleepScore.toStringAsFixed(0)}', sleepColor),
            const SizedBox(width: 8),
            _buildTile('Weight', '${weightDelta > 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg', weightColor),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Text('CNS READINESS COMPOSITE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            SizedBox(width: 4),
            Icon(Icons.info_outline, color: Colors.grey, size: 14),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: cnsScore / 100,
          backgroundColor: Colors.grey.withOpacity(0.2),
          color: cnsColor,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(cnsLabel, style: TextStyle(color: cnsColor, fontWeight: FontWeight.bold)),
            Text('${cnsScore.toStringAsFixed(0)} / 100', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
