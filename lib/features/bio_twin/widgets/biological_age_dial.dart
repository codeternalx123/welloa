import 'dart:math';
import 'package:flutter/material.dart';

class BiologicalAgeDial extends StatelessWidget {
  final double chronologicalAge;
  final double biologicalAge;
  final double ageGap;
  final double reversalRate;

  const BiologicalAgeDial({
    Key? key,
    required this.chronologicalAge,
    required this.biologicalAge,
    required this.ageGap,
    required this.reversalRate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: biologicalAge),
          duration: const Duration(seconds: 2),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return CustomPaint(
              size: const Size(250, 250),
              painter: BiologicalAgeDialPainter(
                chronologicalAge: chronologicalAge,
                biologicalAge: value,
                ageGap: ageGap,
              ),
              child: SizedBox(
                width: 250,
                height: 250,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Text(
                        'BIOLOGICAL AGE',
                        style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (ageGap > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.trending_down, color: Colors.green),
              const SizedBox(width: 8),
              Text('+${ageGap.toStringAsFixed(1)} YRS YOUNGER', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.trending_up, color: Colors.red),
              const SizedBox(width: 8),
              Text('${ageGap.abs().toStringAsFixed(1)} YRS OLDER', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF00F5FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.5)),
          ),
          child: Text(
            'Reversing at ${reversalRate.toStringAsFixed(1)} mo/yr',
            style: const TextStyle(color: Color(0xFF00F5FF), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class BiologicalAgeDialPainter extends CustomPainter {
  final double chronologicalAge;
  final double biologicalAge;
  final double ageGap;

  BiologicalAgeDialPainter({
    required this.chronologicalAge,
    required this.biologicalAge,
    required this.ageGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final rectOuter = Rect.fromCircle(center: center, radius: radius);
    final rectInner = Rect.fromCircle(center: center, radius: radius - 16);

    const startAngle = (135) * pi / 180;
    const sweepAngle = (270) * pi / 180;

    final paintOuter = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final paintOuterProgress = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rectOuter, startAngle, sweepAngle, false, paintOuter);
    canvas.drawArc(rectOuter, startAngle, sweepAngle * (chronologicalAge / 100).clamp(0.0, 1.0), false, paintOuterProgress);

    final paintInnerBg = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final paintInnerProgress = Paint()
      ..color = ageGap > 0 ? const Color(0xFF00F5FF) : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rectInner, startAngle, sweepAngle, false, paintInnerBg);
    canvas.drawArc(rectInner, startAngle, sweepAngle * (biologicalAge / 100).clamp(0.0, 1.0), false, paintInnerProgress);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
