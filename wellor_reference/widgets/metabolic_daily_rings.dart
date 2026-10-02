import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import 'dart:math' as math;
import '../services/daily_balance_service.dart';
import '../utils/responsive_utils.dart';

/// UNICORN UX: The Metabolic Aperture.
/// Features: Kinetic Breathing, Luminous Filaments, and Spatial Core HUD.
class MetabolicDailyRings extends StatefulWidget {
  final DailyBalanceReport report;

  const MetabolicDailyRings({super.key, required this.report});

  @override
  State<MetabolicDailyRings> createState() => _MetabolicDailyRingsState();
}

class _MetabolicDailyRingsState extends State<MetabolicDailyRings> with TickerProviderStateMixin {
  late AnimationController _revealController;
  late AnimationController _pulseController;
  late Animation<double> _revealAnimation;

  @override
  void initState() {
    super.initState();
    // 1. REVEAL: The "Elastic" entry of data
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _revealAnimation = CurvedAnimation(parent: _revealController, curve: Curves.elasticOut);

    // 2. PULSE: Ambient "Breathing" to represent metabolic life
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _triggerSync();
  }

  void _triggerSync() {
    HapticFeedback.mediumImpact(); // Neural handshake
    _revealController.forward();
  }

  @override
  void didUpdateWidget(MetabolicDailyRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.timestamp != widget.report.timestamp) {
      _revealController.reset();
      _triggerSync();
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_revealAnimation, _pulseController]),
      builder: (context, child) {
        final ringSize = ResponsiveUtils.getResponsiveWidth(context, 260);
        final coreSize = ResponsiveUtils.getResponsiveWidth(context, 100);
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                _buildNeuralCore(context, coreSize),
                CustomPaint(
                  size: Size(ringSize, ringSize),
                  painter: _AperturePainter(
                    caloriesPct: widget.report.calories.percentage * _revealAnimation.value,
                    carbsPct: widget.report.carbs.percentage * _revealAnimation.value,
                    proteinPct: widget.report.protein.percentage * _revealAnimation.value,
                    riskLevel: widget.report.clinicalRiskLevel,
                    pulseValue: _pulseController.value,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 10)),
            _buildRingLegend(context),
          ],
        );
      },
    );
  }

  static String _neuralStatusLabel(ClinicalRisk risk) {
    switch (risk) {
      case ClinicalRisk.low:
        return 'Signal strong';
      case ClinicalRisk.moderate:
        return 'Tune today';
      case ClinicalRisk.high:
        return 'Rebalance';
    }
  }

  Widget _buildRingLegend(BuildContext context) {
    final fuel = clinicalRiskColor(widget.report.clinicalRiskLevel);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendItem(context, 'Fuel', fuel),
        _legendItem(context, 'Carbs', Colors.blueAccent),
        _legendItem(context, 'Protein', Colors.redAccent),
      ],
    );
  }

  Widget _legendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobileSize: 11, tabletSize: 12, desktopSize: 12),
            fontWeight: FontWeight.w700,
            color: Colors.blueGrey.shade700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildNeuralCore(BuildContext context, double size) {
    final percentFontSize = ResponsiveUtils.getResponsiveFontSize(context, mobileSize: 22, tabletSize: 26, desktopSize: 30);
    final textPadding = (ResponsiveUtils.getResponsivePadding(context).left * 0.28).clamp(8.0, 14.0);
    final fuelRaw = widget.report.calories.percentage;
    final fuelPct = (fuelRaw * 100).round().clamp(0, 999);
    final statusColor = clinicalRiskColor(widget.report.clinicalRiskLevel);
    final statusLabel = _neuralStatusLabel(widget.report.clinicalRiskLevel);
    final subtitle = fuelRaw > 1.0
        ? "Above today's fuel target"
        : "of today's fuel target";

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A).withValues(alpha: 0.04),
            const Color(0xFF10B981).withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          width: 1.2,
          color: statusColor.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: EdgeInsets.all(textPadding),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_rounded, size: percentFontSize * 0.45, color: const Color(0xFF312E81)),
                      const SizedBox(width: 5),
                      Text(
                        'NEURAL LINK',
                        style: TextStyle(
                          fontSize: percentFontSize * 0.32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: percentFontSize * 0.12),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        const Color(0xFF312E81),
                        statusColor,
                        const Color(0xFF10B981),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      '$fuelPct%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: percentFontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: percentFontSize * 0.08),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: percentFontSize * 0.28,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: percentFontSize * 0.14),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: percentFontSize * 0.35,
                      vertical: percentFontSize * 0.16,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: percentFontSize * 0.26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: statusColor.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  final double caloriesPct, carbsPct, proteinPct, pulseValue;
  final ClinicalRisk riskLevel;

  _AperturePainter({
    required this.caloriesPct,
    required this.carbsPct,
    required this.proteinPct,
    required this.riskLevel,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) - 20;
    const strokeWidth = 14.0;
    const gap = 8.0;

    // 1. FUEL FILAMENT (Outer)
    _drawFilament(canvas, center, baseRadius, caloriesPct, clinicalRiskColor(riskLevel), true);
    
    // 2. GLYCEMIC FILAMENT (Middle)
    _drawFilament(canvas, center, baseRadius - strokeWidth - gap, carbsPct, Colors.blueAccent, false);
    
    // 3. STRUCTURAL FILAMENT (Inner)
    _drawFilament(canvas, center, baseRadius - (strokeWidth * 2) - (gap * 2), proteinPct, Colors.redAccent, false);
  }

  void _drawFilament(Canvas canvas, Offset center, double radius, double pct, Color color, bool isPrimary) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // BASE GLASS TRACK
    final basePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;
    canvas.drawCircle(center, radius, basePaint);

    // NEURAL GLOW LAYER (Gaussian Bloom)
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 + (pulseValue * 4.0))
      ..color = color.withValues(alpha: 0.3 * (isPrimary ? 1.0 : 0.6));
    
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * pct, false, glowPaint);

    // KINETIC FILAMENT (The visible ring)
    final filamentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.2), color, color],
        stops: const [0.0, 0.8, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * pct, false, filamentPaint);

    // THE PHOTON (Active leading edge)
    if (pct > 0.01) {
      final photonAngle = (-math.pi / 2) + (math.pi * 2 * pct);
      final photonPos = Offset(
        center.dx + radius * math.cos(photonAngle),
        center.dy + radius * math.sin(photonAngle),
      );
      final photonPaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(photonPos, 3.0, photonPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePainter oldDelegate) => true;
}