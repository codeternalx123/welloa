import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // High-fidelity haptic integration

/// UNICORN UX: The Metabolic Telemetry Node.
/// Features: Spatial Glassmorphism, Biological Kineticism, and Neural Triage.
class CalorieDisplayWidget extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool isCompact;
  final VoidCallback? onTap;

  const CalorieDisplayWidget({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap?.call();
      },
      child: isCompact ? _buildNeuralCompactNode() : _buildSpatialExpandedHub(),
    );
  }

  // ============================================
  // VIEW: NEURAL COMPACT NODE
  // ============================================
  Widget _buildNeuralCompactNode() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FUEL PAYLOAD', 
                      style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(calories.toInt().toString(), 
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1)),
                        const SizedBox(width: 4),
                        const Text('KCAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
                      ],
                    ),
                  ],
                ),
              ),
              _buildMacroAperture('P', protein, const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _buildMacroAperture('C', carbs, const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _buildMacroAperture('F', fat, const Color(0xFFF59E0B)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroAperture(String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
          Text('${val.toInt()}g', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // ============================================
  // VIEW: SPATIAL EXPANDED HUB
  // ============================================
  Widget _buildSpatialExpandedHub() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                _buildApertureCore(),
                const SizedBox(height: 32),
                _buildMetabolicGrid(),
                const SizedBox(height: 24),
                _buildMacroLinearSync(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApertureCore() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 180, height: 180,
          child: CustomPaint(painter: NeuralAperturePainter(progress: 1.0, color: const Color(0xFF10B981))),
        ),
        Column(
          children: [
            const Text('TOTAL SYNC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.blueGrey)),
            Text(calories.toInt().toString(), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -3)),
            const Text('KCAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
          ],
        ),
      ],
    );
  }

  Widget _buildMetabolicGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatNode('STRUCTURAL', '${protein.toInt()}g', const Color(0xFFEF4444)),
        _buildStatNode('GLYCEMIC', '${carbs.toInt()}g', const Color(0xFF3B82F6)),
        _buildStatNode('RESERVE', '${fat.toInt()}g', const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _buildStatNode(String label, String val, Color c) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Text(val, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _buildMacroLinearSync() {
    final total = protein + carbs + fat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NEURAL MACRO DISTRIBUTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(flex: protein.toInt(), child: Container(color: const Color(0xFFEF4444))),
                Expanded(flex: carbs.toInt(), child: Container(color: const Color(0xFF3B82F6))),
                Expanded(flex: fat.toInt(), child: Container(color: const Color(0xFFF59E0B))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// PAINTER: THE NEURAL APERTURE
// ============================================
class NeuralAperturePainter extends CustomPainter {
  final double progress;
  final Color color;
  NeuralAperturePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track (Glass feel)
    final trackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, trackPaint);

    // Glow Filament (Gaussian bloom)
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, math.pi * 2 * progress, false, glowPaint);

    // Active Filament
    final filamentPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.2), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, math.pi * 2 * progress, false, filamentPaint);

    // The "Photon Node" (Leading edge)
    final photonPos = Offset(center.dx + radius * math.cos(-math.pi / 2 + math.pi * 2 * progress), 
                             center.dy + radius * math.sin(-math.pi / 2 + math.pi * 2 * progress));
    canvas.drawCircle(photonPos, 4, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================
// ANIMATION: STAGGERED REVEAL
// ============================================
class AnimatedCalorieDisplay extends StatefulWidget {
  final double calories, protein, carbs, fat;
  const AnimatedCalorieDisplay({super.key, required this.calories, required this.protein, required this.carbs, required this.fat});

  @override
  State<AnimatedCalorieDisplay> createState() => _AnimatedCalorieDisplayState();
}

class _AnimatedCalorieDisplayState extends State<AnimatedCalorieDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _anim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => CalorieDisplayWidget(
        calories: widget.calories * _anim.value,
        protein: widget.protein * _anim.value,
        carbs: widget.carbs * _anim.value,
        fat: widget.fat * _anim.value,
      ),
    );
  }
}

// ============================================
// COMPONENT: NEURAL SYNTHESIS NODE
// ============================================
class CompactNutritionCard extends StatelessWidget {
  final String mealName, time;
  final double calories, protein, carbs, fat;
  final VoidCallback? onTap;

  const CompactNutritionCard({super.key, required this.mealName, required this.calories, required this.protein, required this.carbs, required this.fat, required this.time, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { HapticFeedback.selectionClick(); onTap?.call(); },
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    _buildSynthesisAvatar(),
                    const SizedBox(width: 16),
                    Expanded(child: _buildIdentityColumn()),
                    _buildValueColumn(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSynthesisAvatar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
      child: const Icon(Icons.hub_rounded, color: Color(0xFF10B981), size: 20),
    );
  }

  Widget _buildIdentityColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mealName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        Text(time, style: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildValueColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${calories.toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
        const Text('SYNC KCAL', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.blueGrey)),
      ],
    );
  }
}