import 'dart:math';
import 'package:flutter/material.dart';

class ReversalRateGauge extends StatelessWidget {
  final double reversalRateMonthsPerYear;
  final double proofScore;

  const ReversalRateGauge({Key? key, required this.reversalRateMonthsPerYear, required this.proofScore}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: CustomPaint(
            painter: ReversalRateGaugePainter(rate: reversalRateMonthsPerYear, proofScore: proofScore),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${reversalRateMonthsPerYear.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFF00F5FF), fontSize: 56, fontWeight: FontWeight.bold, height: 1)),
                  const Text('mo/yr', style: TextStyle(color: Colors.cyan, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('REVERSAL RATE', style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (reversalRateMonthsPerYear > 7)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF00F5FF)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('TOP 5% GLOBALLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
      ],
    );
  }
}

class ReversalRateGaugePainter extends CustomPainter {
  final double rate;
  final double proofScore;

  ReversalRateGaugePainter({required this.rate, required this.proofScore});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const startAngle = 135 * pi / 180;
    const sweepAngle = 270 * pi / 180;

    // Outer Proof Score Ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()..color = const Color(0xFF8B5CF6).withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * (proofScore / 100).clamp(0.0, 1.0),
      false,
      Paint()..color = const Color(0xFF8B5CF6)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round,
    );

    // Inner Rate Ring (Max 12 mo/yr)
    final rateRadius = radius - 12;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rateRadius),
      startAngle,
      sweepAngle,
      false,
      Paint()..color = const Color(0xFF00F5FF).withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rateRadius),
      startAngle,
      sweepAngle * (rate / 12).clamp(0.0, 1.0),
      false,
      Paint()..color = const Color(0xFF00F5FF)..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
