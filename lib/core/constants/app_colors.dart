import 'package:flutter/material.dart';

/// AEG Longevity Platform — Design System Color Palette
/// Dark clinical-premium aesthetic inspired by bioluminescent deep-sea organisms.
class AppColors {
  // Private constructor — this is a pure static utility class.
  AppColors._();

  // ─────────────────────────────────────────────────────────────
  // Core Backgrounds
  // ─────────────────────────────────────────────────────────────

  /// Deep navy — primary app background
  static const Color background = Color(0xFF0A0E1A);

  /// Slightly lighter surface for cards and panels
  static const Color surface = Color(0xFF111827);

  /// Elevated surface for modals, bottom sheets, tooltips
  static const Color surfaceElevated = Color(0xFF1F2937);

  // ─────────────────────────────────────────────────────────────
  // Brand Colors
  // ─────────────────────────────────────────────────────────────

  /// Bioluminescent cyan — primary accent
  static const Color primary = Color(0xFF00F5FF);

  /// Electric purple — secondary accent
  static const Color secondary = Color(0xFF8B5CF6);

  /// Emerald green — tertiary / positive indicator
  static const Color tertiary = Color(0xFF10B981);

  // ─────────────────────────────────────────────────────────────
  // Semantic Colors
  // ─────────────────────────────────────────────────────────────

  /// Amber — warnings, moderate risk
  static const Color warning = Color(0xFFF59E0B);

  /// Red — errors, high risk, damage signals
  static const Color error = Color(0xFFEF4444);

  // ─────────────────────────────────────────────────────────────
  // Typography
  // ─────────────────────────────────────────────────────────────

  /// Near-white — primary body text
  static const Color textPrimary = Color(0xFFF9FAFB);

  /// Medium grey — secondary labels, captions
  static const Color textSecondary = Color(0xFF9CA3AF);

  /// Dark grey — muted, disabled, placeholder text
  static const Color textMuted = Color(0xFF4B5563);

  // ─────────────────────────────────────────────────────────────
  // Hallmarks of Aging — Color Map
  // Each color is carefully chosen to evoke the biological domain.
  // ─────────────────────────────────────────────────────────────

  static const Map<String, Color> hallmarkColors = {
    // Genomic integrity — classic DNA double-helix blue
    'Genomic Instability': Color(0xFF3B82F6),

    // Telomere length — protective cap symbolised by teal
    'Telomere Attrition': Color(0xFF14B8A6),

    // Epigenetic clock — deep indigo representing molecular memory
    'Epigenetic Alterations': Color(0xFF6366F1),

    // Protein quality control — gold for chaperone clarity
    'Loss of Proteostasis': Color(0xFFF59E0B),

    // Nutrient sensing — green for metabolic vitality
    'Deregulated Nutrient Sensing': Color(0xFF10B981),

    // Mitochondria — orange for energy / reactive oxygen
    'Mitochondrial Dysfunction': Color(0xFFF97316),

    // Cellular senescence — muted purple, aged cells
    'Cellular Senescence': Color(0xFF8B5CF6),

    // Stem cell exhaustion — rose, depleted renewal capacity
    'Stem Cell Exhaustion': Color(0xFFEC4899),

    // Cell communication — cyan for signal networks
    'Altered Intercellular Communication': Color(0xFF00F5FF),

    // Autophagy — lime green, cellular recycling
    'Disabled Macroautophagy': Color(0xFF84CC16),

    // Chronic inflammation — red, fire of inflammaging
    'Chronic Inflammation': Color(0xFFEF4444),

    // Dysbiosis — earthy amber, gut ecosystem imbalance
    'Dysbiosis': Color(0xFFD97706),
  };

  // ─────────────────────────────────────────────────────────────
  // Gradient Helpers
  // ─────────────────────────────────────────────────────────────

  /// Primary cyan → purple diagonal gradient (use on hero sections)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Dark surface fade (card inner glow effect)
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceElevated, surface],
  );

  /// Cyan glow overlay for score meters
  static const RadialGradient cyanGlow = RadialGradient(
    colors: [Color(0x3300F5FF), Color(0x0000F5FF)],
    radius: 0.8,
  );
}
