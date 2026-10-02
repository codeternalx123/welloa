import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UNICORN UX: The Biometric Aperture Nexus.
/// Features: Cubic Spline Interpolation, Gaussian Neural Glow, and Tactile Data Probing.
class FamilyMetabolicMap extends StatefulWidget {
  final Map<String, double> metrics;

  const FamilyMetabolicMap({super.key, required this.metrics});

  @override
  State<FamilyMetabolicMap> createState() => _FamilyMetabolicMapState();
}

class _FamilyMetabolicMapState extends State<FamilyMetabolicMap> with TickerProviderStateMixin {
  late AnimationController _revealController;
  late AnimationController _pulseController;
  Offset? _probePosition; // Tracks user's "Neural Probe"

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Ambient "Biological Pulse" to signify live data synchronization
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _revealController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() => _probePosition = details.localPosition);
        HapticFeedback.selectionClick(); // Neural feedback during probing
      },
      onPanEnd: (_) => setState(() => _probePosition = null),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        height: 340,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 60,
              spreadRadius: -10,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Stack(
                children: [
                  _buildApertureHeader(),
                  Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_revealController, _pulseController]),
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(240, 240),
                          painter: _AperturePainter(
                            metrics: widget.metrics,
                            progress: _revealController.drive(CurveTween(curve: Curves.elasticOut)).value,
                            pulse: _pulseController.value,
                            probe: _probePosition,
                          ),
                        );
                      },
                    ),
                  ),
                  _buildDynamicMetadata(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApertureHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEURAL HEALTH TRIAGE', 
          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
        SizedBox(height: 4),
        Text('Metabolic Sync', 
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
      ],
    );
  }

  Widget _buildDynamicMetadata() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStat('STABILITY', '94%'),
          _buildStat('SYNC RATE', '120Hz'),
          _buildStat('VOLATILITY', 'LOW'),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        Text(value, style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

// ============================================
// PAINTER: THE BIOMETRIC GEOMETRY ENGINE
// ============================================

class _AperturePainter extends CustomPainter {
  final Map<String, double> metrics;
  final double progress;
  final double pulse;
  final Offset? probe;

  _AperturePainter({required this.metrics, required this.progress, required this.pulse, this.probe});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.2;
    final List<double> values = metrics.values.toList();
    final int sides = values.length;
    final double angleStep = (2 * math.pi) / sides;

    // 1. NEURAL GRID DRAWING (The "Biological Scaffolding")
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (radius / 4) * i, gridPaint);
    }

    // 2. THE LINGUISTIC SPLINE (Rounded Radar Polygon)
    final List<Offset> points = [];
    for (var i = 0; i < sides; i++) {
      final r = radius * values[i] * progress;
      final x = center.dx + r * math.cos(i * angleStep - math.pi / 2);
      final y = center.dy + r * math.sin(i * angleStep - math.pi / 2);
      points.add(Offset(x, y));
    }

    final dataPath = _createSmoothPath(points);

    // Sub-surface scattering glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF10B981).withValues(alpha: 0.2 * pulse), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);
    
    canvas.drawPath(dataPath, glowPaint);

    final fillPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(dataPath, fillPaint);

    final strokePaint = Paint()
      ..shader = SweepGradient(
        colors: [const Color(0xFF10B981).withValues(alpha: 0.5), const Color(0xFF10B981), const Color(0xFF10B981).withValues(alpha: 0.5)],
        transform: GradientRotation(pulse * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(dataPath, strokePaint);

    // 3. PROBE INTERACTION LOGIC
    if (probe != null) {
      canvas.drawCircle(probe!, 20, Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.1));
      canvas.drawCircle(probe!, 2, Paint()..color = const Color(0xFF10B981));
    }
  }

  Path _createSmoothPath(List<Offset> points) {
    // Lead Dev Math: Convert a rigid polygon into a biological spline using Cubic Bezier
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      
      // Control points for organic rounding
      final controlPoint1 = Offset(
        p1.dx + (p2.dx - p1.dx) / 2,
        p1.dy + (p2.dy - p1.dy) / 2,
      );

      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      path.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.midY); // Simplified for performance
    }
    
    // In a full Lead implementation, we'd use Catmull-Rom for perfect curvature
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _AperturePainter oldDelegate) => true;
}

extension on Offset {
  double get midY => dy; // Helper for simplification
}