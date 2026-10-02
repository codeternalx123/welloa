import 'dart:math' as math;
import 'package:flutter/material.dart';

/// UNICORN UX: The Metabolic Forecast Gauge.
/// A high-precision visualization of the predicted glycemic impact.
/// Features: Adaptive Sweep Gradients, Neural Pulse Animations, and Kinetic Value Interpolation.
class MetabolicForecastGauge extends StatefulWidget {
  final double score; // 0 to 100
  final double size;
  final Duration animationDuration;

  const MetabolicForecastGauge({
    super.key,
    required this.score,
    this.size = 80,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<MetabolicForecastGauge> createState() => _MetabolicForecastGaugeState();
}

class _MetabolicForecastGaugeState extends State<MetabolicForecastGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    
    // Lead UX Idea: Use ElasticOut for a "living tissue" feel
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(MetabolicForecastGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: oldWidget.score, end: widget.score).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color node based on clinical thresholds
    final Color gaugeColor = widget.score >= 80
        ? const Color(0xFF00E676) // Optimal Emerald
        : widget.score >= 50
            ? const Color(0xFFFFAB00) // Clinical Amber
            : const Color(0xFFFF1744); // Acute Red

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // 1. THE NEURAL RADIANCE (Outer Glow)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gaugeColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // 2. THE KINETIC PAINTER
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(
                  value: _animation.value,
                  baseColor: gaugeColor,
                  trackColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              // 3. THE DIGITAL SCORE
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _animation.value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.size * 0.28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'BIO',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: widget.size * 0.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color baseColor;
  final Color trackColor;

  _GaugePainter({
    required this.value,
    required this.baseColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 8.0;

    // 1. Draw Background Track (Dimmer Ring)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - (strokeWidth / 2), trackPaint);

    // 2. Draw Active Sweep (The "Forecast" Progress)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [baseColor.withValues(alpha: 0.1), baseColor],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Standard high-authority sweep math
    final double sweepAngle = (value / 100) * 2 * math.pi;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
      -math.pi / 2, // Start at the 12 o'clock position
      sweepAngle,
      false,
      sweepPaint,
    );

    // 3. Draw The Leading "Photon" (Highlight Dot)
    if (value > 0) {
      final photonPaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
      final double endX = center.dx + (radius - strokeWidth/2) * math.cos(sweepAngle - math.pi/2);
      final double endY = center.dy + (radius - strokeWidth/2) * math.sin(sweepAngle - math.pi/2);
      
      canvas.drawCircle(Offset(endX, endY), 3, photonPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => 
      oldDelegate.value != value || oldDelegate.baseColor != baseColor;
}