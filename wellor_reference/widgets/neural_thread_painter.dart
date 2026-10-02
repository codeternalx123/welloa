import 'package:flutter/material.dart';
import 'dart:math' as math;

/// UNICORN UX: Kinetic Neural Synapse System.
/// Features: Cubic Bezier Liquidity, Comet-Tail Data Packets, and Metabolic Glow Harmonics.
class NeuralThreadPainter extends CustomPainter {
  final List<Offset> bubblePositions;
  final Offset hubPosition;
  final double pulseValue; // Driven by an AnimationController (0.0 to 1.0)

  NeuralThreadPainter({
    required this.bubblePositions,
    required this.hubPosition,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bubblePositions.isEmpty) return;

    for (int i = 0; i < bubblePositions.length; i++) {
      // Logic: Stagger the pulse for each thread based on its index for organic chaos
      final threadPulse = (pulseValue + (i * 0.2)) % 1.0;
      _drawKineticSynapse(canvas, bubblePositions[i], hubPosition, threadPulse);
    }
  }

  void _drawKineticSynapse(Canvas canvas, Offset start, Offset end, double pulse) {
    // 1. DYNAMIC CUBIC GEOMETRY
    // We use two control points to create a "S-Curve" that feels like fluid tubing
    final double midX = (start.dx + end.dx) / 2;
    final double sway = math.sin(pulse * math.pi * 2) * 15; // Harmonic vibration
    
    final cp1 = Offset(midX, start.dy + sway);
    final cp2 = Offset(midX, end.dy - sway);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

    // 2. ATMOSPHERIC SHADOW (Depth Layer)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(path, shadowPaint);

    // 3. THE VITALITY GRADIENT
    // High-performance engineering: The thread glows brighter near the "active" data packet
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF10B981).withValues(alpha: 0.1), // Metabolic Green Fade
          const Color(0xFF34D399).withValues(alpha: 0.5), // Mid-Point Vitality
          const Color(0xFF10B981).withValues(alpha: 0.1),
        ],
        stops: [0.0, pulse, 1.0],
      ).createShader(Rect.fromPoints(start, end))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    // 4. THE KINETIC PHOTON (Comet-Tail Packet)
    _drawKineticPacket(canvas, path, pulse);
  }

  void _drawKineticPacket(Canvas canvas, Path path, double pulse) {
    final metrics = path.computeMetrics();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    // Lead Dev Optimization: We extract a sub-segment of the path to create a "tail"
    final double tailLength = metric.length * 0.15; // 15% of the total path
    final double endOffset = metric.length * pulse;
    final double startOffset = math.max(0.0, endOffset - tailLength);

    final tailPath = metric.extractPath(startOffset, endOffset);

    // Comet Glow Paint
    final cometPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.greenAccent.withValues(alpha: 0.0), Colors.greenAccent],
      ).createShader(Rect.fromPoints(
        metric.getTangentForOffset(startOffset)!.position,
        metric.getTangentForOffset(endOffset)!.position,
      ))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawPath(tailPath, cometPaint);

    // The "Head" of the packet (High intensity node)
    final headPos = metric.getTangentForOffset(endOffset)!.position;
    final headPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    
    canvas.drawCircle(headPos, 2.5, headPaint);
  }

  @override
  bool shouldRepaint(covariant NeuralThreadPainter oldDelegate) {
    // Lead Performance Tip: Continuous repaints are expensive, 
    // but necessary for 120Hz neural fluidity.
    return true; 
  }
}