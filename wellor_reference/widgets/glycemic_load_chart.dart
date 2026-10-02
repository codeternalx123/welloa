import 'dart:ui';
import 'package:flutter/material.dart';

/// UNICORN UX: Kinetic Metabolic Forecast Hub.
/// Features: Cubic Spline Splines, Neural Pulse Animation, and Spatial Glassmorphism.
class GlycemicLoadChart extends StatefulWidget {
  final double carbs;
  final double fiber;
  final double protein;
  final double fat;

  const GlycemicLoadChart({
    super.key,
    required this.carbs,
    required this.fiber,
    required this.protein,
    required this.fat,
  });

  @override
  State<GlycemicLoadChart> createState() => _GlycemicLoadChartState();
}

class _GlycemicLoadChartState extends State<GlycemicLoadChart> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Ambient "Biological Breathing" animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // --- ARCHITECTURAL LOGIC: The Biometric Engine ---
  
  double get _impactScore {
    if (widget.carbs == 0) return 0.05;
    final netCarbs = (widget.carbs - widget.fiber).clamp(0.1, double.infinity);
    // Buffer logic: Fiber is 2x effective at blunting, Protein 1x, Fat 0.5x
    final biologicalBuffer = (widget.fiber * 2.5) + (widget.protein * 1.2) + (widget.fat * 0.8);
    return (netCarbs / (biologicalBuffer + 15)).clamp(0.05, 1.0);
  }

  Color get _vitalityColor {
    if (_impactScore < 0.35) return const Color(0xFF10B981); // Metabolic Green
    if (_impactScore < 0.65) return const Color(0xFFF59E0B); // Warning Amber
    return const Color(0xFFEF4444); // Acute Red
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: _vitalityColor.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHighAuthorityHeader(),
              const Spacer(),
              _buildKineticCanvas(),
              const Spacer(),
              _buildChronoAxis(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighAuthorityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NEURAL METABOLIC FORECAST', 
              style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 9)),
            const SizedBox(height: 4),
            Text('Impact Velocity: ${(_impactScore * 10).toStringAsFixed(1)}x', 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ],
        ),
        _buildDynamicTriageBadge(),
      ],
    );
  }

  Widget _buildDynamicTriageBadge() {
    String label = _impactScore < 0.35 ? 'BUFFERED' : _impactScore < 0.65 ? 'VOLATILE' : 'ACUTE SPIKE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _vitalityColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _vitalityColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLiveIndicator(),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: _vitalityColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _vitalityColor,
          boxShadow: [BoxShadow(color: _vitalityColor, blurRadius: 4 * _pulseController.value, spreadRadius: 2 * _pulseController.value)],
        ),
      ),
    );
  }

  Widget _buildKineticCanvas() {
    return SizedBox(
      height: 100,
      width: double.infinity,
      child: CustomPaint(
        painter: _NeuralSplinePainter(
          impact: _impactScore,
          color: _vitalityColor,
          pulse: _pulseController.value,
        ),
      ),
    );
  }

  Widget _buildChronoAxis() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ['INGESTION', 'PEAK', 'RECOVERY', 'STABLE']
        .map((t) => Text(t, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)))
        .toList(),
    );
  }
}

// ============================================
// THE ENGINE: NEURAL SPLINE PAINTER
// ============================================

class _NeuralSplinePainter extends CustomPainter {
  final double impact;
  final Color color;
  final double pulse;

  _NeuralSplinePainter({required this.impact, required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2 + (pulse * 0.1)), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final double baseline = size.height * 0.85;
    
    // MATHEMATICAL MODELLING
    // Peak height: Proportional to impact
    // Peak location: High impact spikes earlier (lower X)
    double peakX = size.width * (0.4 - (impact * 0.1));
    double peakY = baseline - (impact * size.height * 0.85);
    
    path.moveTo(0, baseline);
    
    // Cubic Bezier for "Clinical Liquidity"
    path.cubicTo(
      peakX * 0.5, baseline,       // CP 1
      peakX * 0.8, peakY,          // CP 2
      peakX, peakY                 // PEAK
    );
    
    // The "Metabolic Tail" (Descent)
    path.cubicTo(
      size.width * 0.7, peakY + (baseline - peakY) * 0.2, 
      size.width * 0.9, baseline - 5,
      size.width, baseline
    );

    // Draw Shadow Depth
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // DRAW THE "PHOTON NODE" (Active leading edge of data)
    final headPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(Offset(peakX, peakY), 3 + (pulse * 2), headPaint);
    canvas.drawCircle(Offset(peakX, peakY), 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NeuralSplinePainter oldDelegate) => true;
}