import 'package:flutter/foundation.dart';
import '../models/nutrition_calculation.dart'; // Ensure your model is here

/// UNICORN GRADE: Clinical Unit Normalization Engine.
/// Standardizes disparate API outputs into a single 'Wellor Truth' metric.
class NutritionNormalizationService {
  static final NutritionNormalizationService _instance = NutritionNormalizationService._internal();
  factory NutritionNormalizationService() => _instance;
  NutritionNormalizationService._internal();

  // ============================================
  // CORE LOGIC: THE SCALING ENGINE
  // ============================================

  /// Normalizes nutrition data based on target weight vs. source base-weight.
  /// Handles the '100g' vs 'Per Serving' discrepancy automatically.
  VerifiedNutritionData normalize({
    required VerifiedNutritionData rawData,
    required double targetWeightGrams,
  }) {
    // 1. Calculate the Scaling Factor
    // If OFF returns 100g data, but user ate 250g, factor is 2.5
    final double sourceBase = rawData.servingWeightGrams > 0 
        ? rawData.servingWeightGrams 
        : 100.0; // Default to 100g if missing (standard for OFF)

    final double scaleFactor = targetWeightGrams / sourceBase;

    debugPrint('⚖️ Normalizing ${rawData.foodName}: Factor $scaleFactor ($sourceBase -> $targetWeightGrams)');

    // 2. Return a Scaled "Clinical Truth" Object
    return VerifiedNutritionData(
      foodName: rawData.foodName,
      source: rawData.source,
      isVerified: true,
      servingWeightGrams: targetWeightGrams,
      
      // Macronutrients (Scaled)
      calories: _scale(rawData.calories, scaleFactor),
      proteinG: _scale(rawData.proteinG, scaleFactor),
      carbsG: _scale(rawData.carbsG, scaleFactor),
      fatG: _scale(rawData.fatG, scaleFactor),
      
      // Micronutrients (Scaled & Unit Checked)
      fiberG: _scale(rawData.fiberG, scaleFactor),
      sugarG: _scale(rawData.sugarG, scaleFactor),
      sodiumMg: _scale(rawData.sodiumMg, scaleFactor),
      cholesterolMg: _scale(rawData.cholesterolMg, scaleFactor),
      saturatedFatG: _scale(rawData.saturatedFatG, scaleFactor),
      transFatG: _scale(rawData.transFatG, scaleFactor),
    );
  }

  // ============================================
  // UTILITIES: MATH SAFETY
  // ============================================

  double _scale(double value, double factor) {
    // Lead Dev Rule: Never return NaN or Infinity to the UI
    if (value.isNaN || value.isInfinite) return 0.0;
    return double.parse((value * factor).toStringAsFixed(2));
  }

  /// Converts common kitchen units to standard grams for the engine.
  double convertToGrams(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'oz':
      case 'ounce':
        return value * 28.3495;
      case 'lb':
      case 'pound':
        return value * 453.592;
      case 'kg':
        return value * 1000.0;
      case 'cup':
        // Warning: Volume to weight is an estimate
        return value * 240.0; 
      default:
        return value; // Assume grams
    }
  }
}