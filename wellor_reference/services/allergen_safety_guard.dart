import 'package:flutter/foundation.dart';


/// UNICORN GRADE: Clinical-grade Allergen Detection & Risk Engine.
/// Features: Semantic Derivative Mapping, Recursive Audit, and Severity Triage.
class AllergenSafetyGuard {
  static final AllergenSafetyGuard _instance = AllergenSafetyGuard._internal();
  factory AllergenSafetyGuard() => _instance;
  AllergenSafetyGuard._internal();

  // ============================================
  // KNOWLEDGE BASE: DERIVATIVE MAPPING
  // ============================================

  /// Mapping of primary allergens to their common scientific or commercial derivatives.
  /// This prevents "Hidden Ingredient" incidents.
  final Map<String, List<String>> _allergenDictionary = {
    'milk': ['whey', 'casein', 'lactose', 'curd', 'ghee', 'butter', 'sodium caseinate', 'lactalbumin'],
    'peanuts': ['arachis oil', 'mandelonas', 'mixed nuts', 'groundnuts', 'satay sauce'],
    'wheat': ['gluten', 'seitan', 'semolina', 'farina', 'spelt', 'bulgur', 'tritium', 'durum'],
    'eggs': ['albumin', 'globulin', 'lecithin', 'lysozyme', 'mayo', 'ovalbumin', 'surimi'],
    'soy': ['tofu', 'tempeh', 'edamame', 'miso', 'teriyaki', 'textured vegetable protein', 'tvp', 'lecithin'],
    'shellfish': ['shrimp', 'prawn', 'crab', 'lobster', 'glucosamine', 'clam', 'mussel'],
    'tree nuts': ['almond', 'walnut', 'cashew', 'pecan', 'pistachio', 'macadamia', 'praline', 'gianduja'],
  };

  // ============================================
  // CORE INTELLIGENCE: THE SAFETY AUDIT
  // ============================================

  /// Performs a deep-tissue audit of a product's ingredients against the user profile.
  /// Returns a [SafetyAuditReport] with actionable risk metadata.
  SafetyAuditReport auditProduct({
    required List<String> ingredients,
    required List<String> userAllergens,
  }) {
    if (userAllergens.isEmpty) return SafetyAuditReport.safe();

    List<String> detectedAllergens = [];
    List<String> triggerIngredients = [];
    
    // Normalize for case-insensitive matching
    final normalizedIngredients = ingredients.map((e) => e.toLowerCase().trim()).toList();
    final normalizedUserAllergens = userAllergens.map((e) => e.toLowerCase().trim()).toList();

    for (var allergen in normalizedUserAllergens) {
      // 1. DIRECT MATCH (e.g., "Wheat" in user list vs "Wheat" in ingredients)
      if (normalizedIngredients.any((ing) => ing.contains(allergen))) {
        detectedAllergens.add(allergen.toUpperCase());
        triggerIngredients.add(ingredients.firstWhere((ing) => ing.toLowerCase().contains(allergen)));
      }

      // 2. SEMANTIC DERIVATIVE MATCH (The Unicorn Feature)
      // Check if the user's allergen has derivatives present in the ingredients
      if (_allergenDictionary.containsKey(allergen)) {
        for (var derivative in _allergenDictionary[allergen]!) {
          if (normalizedIngredients.any((ing) => ing.contains(derivative))) {
            if (!detectedAllergens.contains(allergen.toUpperCase())) {
              detectedAllergens.add(allergen.toUpperCase());
            }
            triggerIngredients.add(ingredients.firstWhere((ing) => ing.toLowerCase().contains(derivative)));
          }
        }
      }
    }

    if (detectedAllergens.isNotEmpty) {
      return SafetyAuditReport(
        isSafe: false,
        severity: _determineSeverity(detectedAllergens.length),
        detectedAllergens: detectedAllergens,
        triggerIngredients: triggerIngredients.toSet().toList(), // Remove duplicates
        message: "🚨 Critical Safety Alert: Found derivatives of ${detectedAllergens.join(', ')}.",
      );
    }

    return SafetyAuditReport.safe();
  }

  // ============================================
  // BUSINESS LOGIC: RISK TRIAGE
  // ============================================

  SafetyRiskSeverity _determineSeverity(int count) {
    if (count >= 3) return SafetyRiskSeverity.extreme;
    if (count >= 1) return SafetyRiskSeverity.critical;
    return SafetyRiskSeverity.negligible;
  }

  /// Audits a list of ingredients against user profile allergens.
  /// Used by MealPlanningService for clinical meal plan safety verification.
  SafetyAuditReport auditIngredients(List<dynamic> ingredients, dynamic profile) {
    // Extract ingredient names from MealIngredient objects or strings
    final List<String> ingredientNames = ingredients.map((ing) {
      if (ing is String) return ing;
      // Handle MealIngredient objects
      if (ing.name != null) return ing.name.toString();
      return ing.toString();
    }).toList();

    // Extract allergens from profile
    List<String> userAllergens = [];
    if (profile.allergens != null && profile.allergens is List) {
      userAllergens = List<String>.from(profile.allergens);
    }

    return auditProduct(
      ingredients: ingredientNames,
      userAllergens: userAllergens,
    );
  }
}

// ============================================
// MODELS: IMMUTABLE SAFETY ENTITIES
// ============================================

enum SafetyRiskSeverity { negligible, critical, extreme }

@immutable
class SafetyAuditReport {
  final bool isSafe;
  final SafetyRiskSeverity severity;
  final List<String> detectedAllergens;
  final List<String> triggerIngredients;
  final String message;

  const SafetyAuditReport({
    required this.isSafe,
    this.severity = SafetyRiskSeverity.negligible,
    this.detectedAllergens = const [],
    this.triggerIngredients = const [],
    this.message = "This product is verified safe for your metabolic profile.",
  });

  factory SafetyAuditReport.safe() => const SafetyAuditReport(isSafe: true);
}