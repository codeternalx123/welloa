import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/bio_twin.dart';

class TrajectoryChart extends StatelessWidget {
  final List<SimulationPoint> projection;
  final double chronologicalAge;

  const TrajectoryChart({
    Key? key,
    required this.projection,
    required this.chronologicalAge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const titles = ['Now', 'M1', 'M2', 'M3', 'M4', 'M5', 'M6'];
                  if (value.toInt() >= 0 && value.toInt() < titles.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(titles[value.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: projection.last.projectedBioAge - 2,
          maxY: chronologicalAge + 2,
          lineBarsData: [
            LineChartBarData(
              spots: projection.map((p) => FlSpot(p.monthOffset.toDouble(), p.projectedBioAge)).toList(),
              isCurved: true,
              color: const Color(0xFF00F5FF),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.2),
              ),
            ),
            LineChartBarData(
              spots: projection.map((p) => FlSpot(p.monthOffset.toDouble(), chronologicalAge)).toList(),
              isCurved: false,
              color: Colors.grey,
              barWidth: 2,
              isStrokeCapRound: true,
              dashArray: [5, 5],
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
