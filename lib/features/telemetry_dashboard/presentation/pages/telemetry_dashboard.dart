import 'package:flutter/material.dart';
import '../widgets/aging_velocity_chart.dart';
import '../widgets/hrv_scatter_plot.dart';

class TelemetryDashboardPage extends StatelessWidget {
  const TelemetryDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock longitudinal data for demo purposes
    final chronoAges = [30.0, 30.08, 30.16, 30.25, 30.33, 30.41, 30.5];
    final bioAges = [30.5, 30.2, 29.8, 29.5, 29.2, 28.9, 28.5];

    // Mock HRV vs Sleep
    final hrvData = [
      {'sleep': 5.5, 'hrv': 45.0},
      {'sleep': 6.0, 'hrv': 50.0},
      {'sleep': 6.5, 'hrv': 55.0},
      {'sleep': 7.0, 'hrv': 68.0},
      {'sleep': 7.5, 'hrv': 75.0},
      {'sleep': 8.0, 'hrv': 85.0},
      {'sleep': 8.5, 'hrv': 82.0},
      {'sleep': 9.0, 'hrv': 80.0},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Telemetry Engine', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biological Age Velocity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'The gap between chronological (red) and biological (green) age represents your structural rate of aging.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: AgingVelocityChart(
                chronologicalAges: chronoAges,
                biologicalAges: bioAges,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Kinematic Readiness (HRV vs Sleep)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Heart Rate Variability plotted against hours slept. Identifies your optimal recovery zone.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: HrvScatterPlot(dataPoints: hrvData),
            ),
          ],
        ),
      ),
    );
  }
}
