import 'dart:math';
import 'package:flutter/material.dart';

class HormeticZoneGauge extends StatelessWidget {
  final double cnsReadinessScore;
  final int currentZone;

  const HormeticZoneGauge({Key? key, required this.cnsReadinessScore, required this.currentZone}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('HORMETIC ZONE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          height: 160,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CustomPaint(
                size: const Size(300, 150),
                painter: HormeticGaugePainter(currentZone: currentZone),
              ),
              Positioned(
                bottom: 10,
                child: Text('ZONE $currentZone', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Text('CNS Readiness: ${cnsReadinessScore.toStringAsFixed(1)} / 100', style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class HormeticGaugePainter extends CustomPainter {
  final int currentZone;

  HormeticGaugePainter({required this.currentZone});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    
    final List<Color> colors = [
      const Color(0xFF3B82F6), // Zone 1
      const Color(0xFF10B981), // Zone 2
      const Color(0xFFF59E0B), // Zone 3
      const Color(0xFFF97316), // Zone 4
      const Color(0xFFEF4444), // Zone 5
    ];
    
    final double sweepAngle = pi / 5; // 180 degrees / 5 zones

    for (int i = 0; i < 5; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = (i + 1 == currentZone) ? 40 : 30
        ..strokeCap = StrokeCap.butt;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 20),
        pi + (i * sweepAngle),
        sweepAngle - 0.05,
        false,
        paint,
      );
    }
    
    // Draw Needle
    final needleAngle = pi + ((currentZone - 0.5) * sweepAngle);
    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
      
    final needleEnd = Offset(
      center.dx + (radius - 50) * cos(needleAngle),
      center.dy + (radius - 50) * sin(needleAngle),
    );
    
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
