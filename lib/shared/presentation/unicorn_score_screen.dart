import 'package:flutter/material.dart';

class UnicornScoreCard extends StatelessWidget {
  final String title;
  final String metricName;
  final String score;
  final String subtitle;
  final String advice;
  final Color themeColor;
  final IconData icon;
  final String longevityImpact;

  const UnicornScoreCard({
    Key? key,
    required this.title,
    required this.metricName,
    required this.score,
    required this.subtitle,
    required this.advice,
    required this.themeColor,
    required this.icon,
    required this.longevityImpact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: longevityImpact.startsWith('+') ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: longevityImpact.startsWith('+') ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      longevityImpact.startsWith('+') ? Icons.trending_up : Icons.trending_down,
                      color: longevityImpact.startsWith('+') ? Colors.greenAccent : Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Longevity Impact: $longevityImpact',
                      style: TextStyle(
                        color: longevityImpact.startsWith('+') ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor.withOpacity(0.5), width: 2),
                ),
                child: Icon(icon, size: 48, color: themeColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              metricName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              score,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: themeColor,
                shadows: [
                  Shadow(color: themeColor.withOpacity(0.5), blurRadius: 20),
                ],
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                advice,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}
