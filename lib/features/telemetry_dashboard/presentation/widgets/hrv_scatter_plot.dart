import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HrvScatterPlot extends StatelessWidget {
  final List<Map<String, double>> dataPoints; // Keys: 'sleep' (hours), 'hrv' (ms)

  const HrvScatterPlot({
    super.key,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const Center(child: Text('No HRV vs Sleep data available'));
    }

    List<ScatterSpot> spots = dataPoints.map((dp) {
      final sleep = dp['sleep'] ?? 0.0;
      final hrv = dp['hrv'] ?? 0.0;
      return ScatterSpot(sleep, hrv, dotPainter: FlDotCirclePainter(
        color: Colors.cyanAccent.withOpacity(0.8),
        radius: 6,
      ));
    }).toList();

    return AspectRatio(
      aspectRatio: 1.2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ScatterChart(
          ScatterChartData(
            scatterSpots: spots,
            minX: 4, // Minimum 4 hours sleep
            maxX: 10, // Max 10 hours sleep
            minY: 20, // Min HRV
            maxY: 120, // Max HRV
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.white24),
            ),
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
              getDrawingVerticalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                axisNameWidget: const Text('Sleep (Hours)', style: TextStyle(color: Colors.white70)),
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(value.toInt().toString(), style: const TextStyle(color: Colors.white70)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: const Text('HRV (ms)', style: TextStyle(color: Colors.white70)),
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white70));
                  },
                ),
              ),
            ),
            scatterTouchData: ScatterTouchData(
              enabled: true,
              touchTooltipData: ScatterTouchTooltipData(
                getTooltipColor: (spot) => Colors.blueGrey,
                getTooltipItems: (touchedSpot) {
                  return ScatterTooltipItem(
                    'Sleep: ${touchedSpot.x}h\nHRV: ${touchedSpot.y}ms',
                    textStyle: const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
