import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import '../models/nutrition_calculation.dart';

/// UNICORN UX: The Metabolic Intervention Node.
/// Features: Spatial Glassmorphism, Predictive Impact Shadows, and Neural Triage Badging.
class SnackRecommendationCard extends StatelessWidget {
  final VerifiedNutritionData food;
  final VoidCallback? onTap;

  const SnackRecommendationCard({
    super.key,
    required this.food,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Lead Dev Logic: Determine accent color based on nutrition profile
    final Color accentColor = _getImpactColor();

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 18, bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32), // High-radius squircle geometry
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2), 
                width: 1.5
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact(); // Neural handshake
                  onTap?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSpatialHeader(accentColor),
                      const Spacer(),
                      _buildCausalTitle(),
                      const SizedBox(height: 6),
                      _buildMacroTelemetry(),
                      const SizedBox(height: 14),
                      _buildNeuralBadging(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // COMPONENT: SPATIAL HEADER (Aperture Design)
  // ============================================
  Widget _buildSpatialHeader(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Icon(_getImpactIcon(), color: color, size: 18),
        ),
        // Safety Score HUD
        Text(
          '${(100 - (food.carbsG / 2)).toInt()}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCausalTitle() {
    return Text(
      food.foodName.toUpperCase(),
      maxLines: 2,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: -0.5,
        color: Color(0xFF0F172A), // Slate-900
      ),
    );
  }

  // ============================================
  // COMPONENT: MACRO TELEMETRY (Bio-Data)
  // ============================================
  Widget _buildMacroTelemetry() {
    return Row(
      children: [
        Text(
          '${food.calories.toInt()} kcal',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(width: 6),
        Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black12)),
        const SizedBox(width: 6),
        Text(
          '${food.carbsG.toInt()}g net',
          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
        ),
      ],
    );
  }

  // ============================================
  // COMPONENT: NEURAL BADGING (Contextual Intelligence)
  // ============================================
  Widget _buildNeuralBadging() {
    final String label = _getNeuralLabel();
    final Color color = _getImpactColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  String _getNeuralLabel() {
    if (food.fiberG > 4) return "GLUCOSE BUFFER";
    if (food.proteinG > 12) return "PROTEIN SYNC";
    if (food.carbsG < 10) return "KETOGENIC FLIGHT";
    return "METABOLIC SYNC";
  }

  Color _getImpactColor() {
    if (food.fiberG > 4 || food.proteinG > 12) return const Color(0xFF10B981); // Vitality Green
    if (food.carbsG > 20) return const Color(0xFFF59E0B); // Cautionary Amber
    return const Color(0xFF6366F1); // Indigo Primary
  }

  IconData _getImpactIcon() {
    if (food.fiberG > 4) return Icons.security_rounded;
    if (food.proteinG > 12) return Icons.bolt_rounded;
    return Icons.auto_awesome_rounded;
  }
}