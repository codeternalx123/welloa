import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/food_analysis.dart';
import '../../../core/constants/app_colors.dart';

class HallmarksRadar extends StatelessWidget {
  final List<HallmarkImpact> impacts;

  const HallmarksRadar({Key? key, required this.impacts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(
        painter: HallmarksRadarPainter(impacts: impacts),
      ),
    );
  }
}

class HallmarksRadarPainter extends CustomPainter {
  final List<HallmarkImpact> impacts;

  HallmarksRadarPainter({required this.impacts});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    final paintBg = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), paintBg);
    }

    final int n = impacts.length;
    final double angleStep = 2 * pi / n;
    
    Path polygonPath = Path();
    
    for (int i = 0; i < n; i++) {
      final double angle = i * angleStep - pi / 2;
      final impact = impacts[i];
      final double r = radius * (impact.impactScore.abs().clamp(0.0, 1.0));
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      
      if (i == 0) {
        polygonPath.moveTo(x, y);
      } else {
        polygonPath.lineTo(x, y);
      }

      canvas.drawLine(center, Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)), paintBg);
      
      final cPaint = Paint()..color = AppColors.hallmarkColors[impact.hallmarkName] ?? Colors.cyan;
      canvas.drawCircle(Offset(x, y), 4, cPaint);
      
      final label = impact.hallmarkName.split(' ').first;
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 8),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + (radius + 15) * cos(angle) - textPainter.width / 2,
               center.dy + (radius + 15) * sin(angle) - textPainter.height / 2),
      );
    }
    polygonPath.close();

    final fillPaint = Paint()
      ..color = const Color(0xFF00F5FF).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF00F5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    canvas.drawPath(polygonPath, fillPaint);
    canvas.drawPath(polygonPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
