import 'dart:ui';
import 'package:flutter/material.dart';
// For High-Fidelity Neural Haptics
import '../models/nutrition_calculation.dart';

/// UNICORN UX: The Metabolic Synthesis Node.
/// Features: Spatial Glassmorphism, Bio-Refractive Accents, and Clinical Triage.
class ClinicalNutrientCard extends StatelessWidget {
  final NutritionCalculation calculation;

  const ClinicalNutrientCard({super.key, required this.calculation});

  @override
  Widget build(BuildContext context) {
    final triageColor = _getRatioColor();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: triageColor.withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  triageColor.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildApertureHeader(triageColor),
                const SizedBox(height: 28),
                _buildKineticMainMetrics(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Opacity(opacity: 0.1, child: Divider(thickness: 1)),
                ),
                _buildClinicalTriageGrid(),
                if (calculation.warnings.isNotEmpty) _buildNeuralWarningSystem(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // COMPONENT: APERTURE HEADER
  // ============================================
  Widget _buildApertureHeader(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "METABOLIC SYNTHESIS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.blueGrey.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Clinical Telemetry",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        _buildRatioAperture(color),
      ],
    );
  }

  Widget _buildRatioAperture(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            "K:Na SYNC",
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 1),
          ),
          Text(
            calculation.potassiumSodiumRatio.toStringAsFixed(2),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: KINETIC MAIN METRICS
  // ============================================
  Widget _buildKineticMainMetrics() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _metricAperture("FUEL", calculation.totalCalories.toInt().toString(), "kcal", const Color(0xFFF59E0B)),
        _metricAperture("GLYCEMIC", calculation.netCarbs.toInt().toString(), "g", const Color(0xFF6366F1)),
        _metricAperture("STRUCTURAL", calculation.proteinGrams.toInt().toString(), "g", const Color(0xFF10B981)),
      ],
    );
  }

  Widget _metricAperture(String label, String val, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: CLINICAL TRIAGE GRID
  // ============================================
  Widget _buildClinicalTriageGrid() {
    return Column(
      children: [
        _biomarkerNode("Sodium Payload (Na)", "${calculation.sodiumMg.toInt()}mg", calculation.sodiumMg > 800),
        const SizedBox(height: 16),
        _biomarkerNode("Potassium Reserve (K)", "${calculation.potassiumMg.toInt()}mg", false, isPositive: true),
        const SizedBox(height: 16),
        _biomarkerNode("Digestive Fiber", "${calculation.fiberGrams.toInt()}g", false, isPositive: true),
      ],
    );
  }

  Widget _biomarkerNode(String label, String value, bool isAlert, {bool isPositive = false}) {
    final Color accent = isAlert ? const Color(0xFFEF4444) : (isPositive ? const Color(0xFF10B981) : const Color(0xFF64748B));
    return Row(
      children: [
        Container(
          width: 4, height: 24,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: accent)),
      ],
    );
  }

  // ============================================
  // COMPONENT: NEURAL WARNINGS
  // ============================================
  Widget _buildNeuralWarningSystem() {
    return Column(
      children: [
        const SizedBox(height: 24),
        ...calculation.warnings.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFEF4444).withValues(alpha: 0.06),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      w.toUpperCase(),
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Color _getRatioColor() {
    if (calculation.potassiumSodiumRatio >= 2.0) return const Color(0xFF10B981);
    if (calculation.potassiumSodiumRatio >= 1.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}