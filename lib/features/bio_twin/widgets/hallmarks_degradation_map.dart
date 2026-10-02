import 'package:flutter/material.dart';
import '../../../core/models/bio_twin.dart';

class HallmarksDegradationMap extends StatelessWidget {
  final List<HallmarkScore> scores;

  const HallmarksDegradationMap({Key? key, required this.scores}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: scores.map((score) {
        final color = score.score > 70 ? Colors.green : (score.score >= 40 ? Colors.amber : Colors.red);
        final trendIcon = score.trend == 'improving' ? Icons.trending_up : (score.trend == 'declining' ? Icons.trending_down : Icons.trending_flat);
        final trendColor = score.trend == 'improving' ? Colors.green : (score.trend == 'declining' ? Colors.red : Colors.grey);
        
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                score.hallmarkName.split(' ').first,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${score.score.toStringAsFixed(0)}/100', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  Icon(trendIcon, color: trendColor, size: 14),
                ],
              ),
              LinearProgressIndicator(
                value: score.score / 100,
                color: color,
                backgroundColor: Colors.grey.withOpacity(0.2),
                minHeight: 4,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
