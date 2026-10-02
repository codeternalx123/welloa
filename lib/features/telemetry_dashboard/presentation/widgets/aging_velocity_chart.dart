import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AgingVelocityChart extends StatelessWidget {
  final List<double> chronologicalAges;
  final List<double> biologicalAges;

  const AgingVelocityChart({
    super.key,
    required this.chronologicalAges,
    required this.biologicalAges,
  });

  @override
  Widget build(BuildContext context) {
    if (chronologicalAges.isEmpty || biologicalAges.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final maxY = chronologicalAges.reduce((a, b) => a > b ? a : b) + 5;
    final minY = biologicalAges.reduce((a, b) => a < b ? a : b) - 5;

    List<FlSpot> chronoSpots = [];
    List<FlSpot> bioSpots = [];

    for (int i = 0; i < chronologicalAges.length; i++) {
      chronoSpots.add(FlSpot(i.toDouble(), chronologicalAges[i]));
      bioSpots.add(FlSpot(i.toDouble(), biologicalAges[i]));
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 1,
              verticalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return const FlLine(
                  color: Colors.white10,
                  strokeWidth: 1,
                );
              },
              getDrawingVerticalLine: (value) {
                return const FlLine(
                  color: Colors.white10,
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text('Month \${value.toInt() + 1}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2,
                  getTitlesWidget: (value, meta) {
                    return Text('\${value.toInt()}', style: const TextStyle(color: Colors.white70, fontSize: 12));
                  },
                  reservedSize: 42,
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.white24),
            ),
            minX: 0,
            maxX: (chronologicalAges.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: chronoSpots,
                isCurved: true,
                color: Colors.redAccent,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
              LineChartBarData(
                spots: bioSpots,
                isCurved: true,
                color: Colors.greenAccent,
                barWidth: 5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.greenAccent.withOpacity(0.3),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final isBio = spot.barIndex == 1;
                    return LineTooltipItem(
                      "${isBio ? 'Bio' : 'Chrono'} Age: ${spot.y.toStringAsFixed(1)}",
                      TextStyle(color: isBio ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
