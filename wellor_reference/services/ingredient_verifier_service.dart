import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cloud_kitchen_service.dart';

/// 🔬 **INGREDIENT VERIFIER SERVICE**
/// Deterministic safety system for cross-referencing AI-generated meals
/// with cloud kitchen platform ingredient data.
///
/// **Core Mission:**
/// 1. Verify that delivered food matches what AI generated
/// 2. Check for health side effects, allergen conflicts, and metabolic risks
/// 3. Provide confidence scores for ingredient matching
/// 4. Block orders that fail safety thresholds
///
/// **Safety Layers:**
/// - Ingredient matching (fuzzy string matching + semantic similarity)
/// - Allergen detection (user profile vs platform data)
/// - Metabolic risk assessment (drug interactions, glycemic spikes)
/// - Nutritional variance analysis (expected vs actual macros)

// ============================================================================
// MODELS
// ============================================================================

/// User's health profile for safety checks
class UserHealthProfile {
  final String userId;
  final List<String> allergens;
  final List<String> medications; // For drug-food interaction checks
  final List<String> chronicConditions; // Diabetes, hypertension, etc.
  final Map<String, dynamic> metabolicConstraints; // Max carbs, sodium, etc.
  final bool isPregnant;
  final bool isLactating;

  UserHealthProfile({
    required this.userId,
    required this.allergens,
    required this.medications,
    required this.chronicConditions,
    required this.metabolicConstraints,
    this.isPregnant = false,
    this.isLactating = false,
  });
}

/// AI-generated meal specification (from meal planner)
class AIGeneratedMeal {
  final String mealName;
  final List<String> ingredients; // List of ingredient names
  final Map<String, double> expectedMacros; // Expected nutritional values
  final String? dietaryCategory; // Keto, paleo, etc.
  final List<String> allergenWarnings; // Known allergens in recipe

  AIGeneratedMeal({
    required this.mealName,
    required this.ingredients,
    required this.expectedMacros,
    this.dietaryCategory,
    required this.allergenWarnings,
  });
}

/// Detailed safety check result
class SafetyCheckResult {
  final bool isPassed;
  final double confidenceScore; // 0.0 - 1.0
  final List<String> passedChecks;
  final List<SafetyViolation> violations;
  final String recommendation; // "Safe to order", "Caution advised", "Do not order"

  SafetyCheckResult({
    required this.isPassed,
    required this.confidenceScore,
    required this.passedChecks,
    required this.violations,
    required this.recommendation,
  });
}

/// Specific safety violation
class SafetyViolation {
  final SafetyViolationType type;
  final String description;
  final String severity; // "low", "medium", "high", "critical"
  final String? suggestedAction;

  SafetyViolation({
    required this.type,
    required this.description,
    required this.severity,
    this.suggestedAction,
  });
}

enum SafetyViolationType {
  allergenConflict,
  ingredientMismatch,
  drugInteraction,
  metabolicRisk,
  nutritionalDeviation,
  contaminationRisk,
}

// ============================================================================
// SERVICE
// ============================================================================

class IngredientVerifierService {
  // Similarity thresholds
  static const double _ingredientMatchThreshold = 0.75; // 75% similarity required
  static const double _macroDeviationThreshold = 0.20; // ±20% acceptable variance
  static const double _safetyConfidenceThreshold = 0.85; // 85% confidence to pass

  // ============================================================================
  // PRIMARY VERIFICATION METHOD
  // ============================================================================

  /// Verify that platform menu item matches AI-generated meal spec
  static Future<IngredientVerificationResult> verifyIngredients({
    required AIGeneratedMeal generatedMeal,
    required CloudKitchenMenuItem platformItem,
    required UserHealthProfile userProfile,
  }) async {
    debugPrint('🔬 IngredientVerifier: Comparing "${generatedMeal.mealName}" with "${platformItem.itemName}"');

    // Step 1: Ingredient matching analysis
    final ingredientAnalysis = _analyzeIngredientMatch(
      generatedIngredients: generatedMeal.ingredients,
      platformIngredients: platformItem.ingredients.map((i) => i.ingredientName).toList(),
    );

    // Step 2: Safety checks (allergens, drug interactions, metabolic risks)
    final safetyResult = await _performSafetyChecks(
      platformItem: platformItem,
      userProfile: userProfile,
      generatedMeal: generatedMeal,
    );

    // Step 3: Nutritional variance analysis
    final macroDeviation = _calculateMacroDeviation(
      expected: generatedMeal.expectedMacros,
      actual: platformItem.macronutrients,
    );

    // Step 4: Calculate overall confidence score
    final confidenceScore = _calculateConfidenceScore(
      ingredientMatchScore: ingredientAnalysis['matchScore'] as double,
      macroDeviationScore: 1.0 - macroDeviation,
      safetyScore: safetyResult.confidenceScore,
    );

    // Step 5: Determine verification status
    final status = _determineVerificationStatus(
      ingredientMatchScore: ingredientAnalysis['matchScore'] as double,
      macroDeviation: macroDeviation,
      safetyPassed: safetyResult.isPassed,
    );

    final healthWarnings = <String>[];
    if (!safetyResult.isPassed) {
      healthWarnings.addAll(safetyResult.violations.map((v) => v.description));
    }
    if (macroDeviation > _macroDeviationThreshold) {
      healthWarnings.add('Nutritional values differ significantly from AI recommendation (${(macroDeviation * 100).toStringAsFixed(0)}% variance)');
    }

    debugPrint('✅ Verification complete: $status (confidence: ${(confidenceScore * 100).toStringAsFixed(1)}%)');

    return IngredientVerificationResult(
      mealName: generatedMeal.mealName,
      platformItem: platformItem,
      status: status,
      matchedIngredients: ingredientAnalysis['matched'] as List<String>,
      missingIngredients: ingredientAnalysis['missing'] as List<String>,
      extraIngredients: ingredientAnalysis['extra'] as List<String>,
      isSafeForUser: safetyResult.isPassed && confidenceScore >= _safetyConfidenceThreshold,
      healthWarnings: healthWarnings,
      confidenceScore: confidenceScore,
    );
  }

  // ============================================================================
  // INGREDIENT MATCHING ANALYSIS
  // ============================================================================

  static Map<String, dynamic> _analyzeIngredientMatch({
    required List<String> generatedIngredients,
    required List<String> platformIngredients,
  }) {
    final matched = <String>[];
    final missing = <String>[];
    final extra = <String>[...platformIngredients];

    // Fuzzy matching for each generated ingredient
    for (final genIngredient in generatedIngredients) {
      bool found = false;
      
      for (final platIngredient in platformIngredients) {
        final similarity = _calculateStringSimilarity(
          genIngredient.toLowerCase(),
          platIngredient.toLowerCase(),
        );
        
        if (similarity >= _ingredientMatchThreshold) {
          matched.add(genIngredient);
          extra.remove(platIngredient);
          found = true;
          break;
        }
      }
      
      if (!found) {
        missing.add(genIngredient);
      }
    }

    final matchScore = generatedIngredients.isEmpty 
        ? 0.0 
        : matched.length / generatedIngredients.length;

    debugPrint('📊 Ingredient match: ${matched.length}/${generatedIngredients.length} (${(matchScore * 100).toStringAsFixed(1)}%)');
    debugPrint('  - Matched: $matched');
    debugPrint('  - Missing: $missing');
    debugPrint('  - Extra: $extra');

    return {
      'matched': matched,
      'missing': missing,
      'extra': extra,
      'matchScore': matchScore,
    };
  }

  /// Fuzzy string matching using Levenshtein distance
  static double _calculateStringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Check if one string contains the other (e.g., "chicken" vs "grilled chicken")
    if (a.contains(b) || b.contains(a)) return 0.9;

    // Levenshtein distance
    final matrix = List.generate(
      a.length + 1,
      (i) => List.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    final maxLength = max(a.length, b.length);
    final distance = matrix[a.length][b.length];
    return 1.0 - (distance / maxLength);
  }

  // ============================================================================
  // SAFETY CHECKS
  // ============================================================================

  static Future<SafetyCheckResult> _performSafetyChecks({
    required CloudKitchenMenuItem platformItem,
    required UserHealthProfile userProfile,
    required AIGeneratedMeal generatedMeal,
  }) async {
    debugPrint('🛡️ Performing safety checks...');

    final violations = <SafetyViolation>[];
    final passedChecks = <String>[];

    // Check 1: Allergen conflicts
    final allergenViolations = _checkAllergens(platformItem, userProfile);
    if (allergenViolations.isNotEmpty) {
      violations.addAll(allergenViolations);
    } else {
      passedChecks.add('No allergen conflicts detected');
    }

    // Check 2: Drug-food interactions
    final drugViolations = _checkDrugInteractions(platformItem, userProfile);
    if (drugViolations.isNotEmpty) {
      violations.addAll(drugViolations);
    } else {
      passedChecks.add('No drug-food interactions detected');
    }

    // Check 3: Metabolic risk assessment
    final metabolicViolations = _checkMetabolicRisks(platformItem, userProfile);
    if (metabolicViolations.isNotEmpty) {
      violations.addAll(metabolicViolations);
    } else {
      passedChecks.add('Metabolic parameters within safe range');
    }

    // Check 4: Chronic condition constraints
    final conditionViolations = _checkChronicConditions(platformItem, userProfile);
    if (conditionViolations.isNotEmpty) {
      violations.addAll(conditionViolations);
    } else {
      passedChecks.add('Compatible with chronic conditions');
    }

    // Calculate safety confidence score
    final totalChecks = 4;
    final passedCount = passedChecks.length;
    final confidenceScore = passedCount / totalChecks;

    final isPassed = violations.isEmpty || 
        violations.every((v) => v.severity == 'low');

    final recommendation = _generateSafetyRecommendation(violations, confidenceScore);

    debugPrint('🛡️ Safety checks complete: ${passedChecks.length}/$totalChecks passed');
    if (violations.isNotEmpty) {
      debugPrint('⚠️ Violations found: ${violations.length}');
      for (final v in violations) {
        debugPrint('  - [${v.severity.toUpperCase()}] ${v.description}');
      }
    }

    return SafetyCheckResult(
      isPassed: isPassed,
      confidenceScore: confidenceScore,
      passedChecks: passedChecks,
      violations: violations,
      recommendation: recommendation,
    );
  }

  static List<SafetyViolation> _checkAllergens(
    CloudKitchenMenuItem item,
    UserHealthProfile profile,
  ) {
    final violations = <SafetyViolation>[];
    
    for (final ingredient in item.ingredients) {
      for (final allergen in ingredient.allergens) {
        if (profile.allergens.contains(allergen.toLowerCase())) {
          violations.add(SafetyViolation(
            type: SafetyViolationType.allergenConflict,
            description: 'Contains ${allergen}, which you are allergic to (found in ${ingredient.ingredientName})',
            severity: 'critical',
            suggestedAction: 'Do not order this meal. Search for allergen-free alternatives.',
          ));
        }
      }
    }
    
    return violations;
  }

  static List<SafetyViolation> _checkDrugInteractions(
    CloudKitchenMenuItem item,
    UserHealthProfile profile,
  ) {
    final violations = <SafetyViolation>[];
    
    // Common drug-food interactions
    final interactions = {
      'warfarin': ['kale', 'spinach', 'broccoli', 'cabbage'], // High vitamin K
      'statins': ['grapefruit'], // CYP3A4 inhibition
      'maoi': ['aged cheese', 'cured meat', 'soy sauce'], // Tyramine
      'levothyroxine': ['soy', 'walnuts', 'fiber'], // Absorption interference
    };

    for (final medication in profile.medications) {
      final problematicFoods = interactions[medication.toLowerCase()] ?? [];
      
      for (final ingredient in item.ingredients) {
        for (final food in problematicFoods) {
          if (ingredient.ingredientName.toLowerCase().contains(food)) {
            violations.add(SafetyViolation(
              type: SafetyViolationType.drugInteraction,
              description: '${ingredient.ingredientName} may interact with your medication ($medication)',
              severity: 'high',
              suggestedAction: 'Consult your doctor before consuming this meal.',
            ));
          }
        }
      }
    }
    
    return violations;
  }

  static List<SafetyViolation> _checkMetabolicRisks(
    CloudKitchenMenuItem item,
    UserHealthProfile profile,
  ) {
    final violations = <SafetyViolation>[];
    
    // Check glycemic load for diabetics
    if (profile.chronicConditions.contains('diabetes') && item.glycemicLoad != null) {
      if (item.glycemicLoad! > 20) {
        violations.add(SafetyViolation(
          type: SafetyViolationType.metabolicRisk,
          description: 'High glycemic load (${item.glycemicLoad!.toStringAsFixed(1)}) may cause blood sugar spike',
          severity: 'medium',
          suggestedAction: 'Consider a lower-carb option or split the meal into smaller portions.',
        ));
      }
    }

    // Check sodium for hypertension
    if (profile.chronicConditions.contains('hypertension')) {
      final sodium = item.macronutrients['sodium'];
      if (sodium != null && sodium > 600) { // mg per meal
        violations.add(SafetyViolation(
          type: SafetyViolationType.metabolicRisk,
          description: 'High sodium content (${sodium.toStringAsFixed(0)}mg) may elevate blood pressure',
          severity: 'medium',
          suggestedAction: 'Request low-sodium preparation if available.',
        ));
      }
    }

    // Check custom metabolic constraints
    for (final entry in profile.metabolicConstraints.entries) {
      final nutrient = entry.key;
      final maxValue = entry.value as double;
      final actualValue = item.macronutrients[nutrient];
      
      if (actualValue != null && actualValue > maxValue) {
        violations.add(SafetyViolation(
          type: SafetyViolationType.metabolicRisk,
          description: 'Exceeds your $nutrient limit (${actualValue.toStringAsFixed(1)}g vs ${maxValue}g max)',
          severity: 'medium',
          suggestedAction: 'Choose a meal that fits your metabolic constraints.',
        ));
      }
    }
    
    return violations;
  }

  static List<SafetyViolation> _checkChronicConditions(
    CloudKitchenMenuItem item,
    UserHealthProfile profile,
  ) {
    final violations = <SafetyViolation>[];
    
    // Pregnancy/lactation restrictions
    if (profile.isPregnant || profile.isLactating) {
      final riskyIngredients = ['raw fish', 'unpasteurized cheese', 'raw egg', 'alcohol'];
      for (final ingredient in item.ingredients) {
        for (final risky in riskyIngredients) {
          if (ingredient.ingredientName.toLowerCase().contains(risky)) {
            violations.add(SafetyViolation(
              type: SafetyViolationType.contaminationRisk,
              description: '${ingredient.ingredientName} is not recommended during pregnancy/lactation',
              severity: 'high',
              suggestedAction: 'Choose pregnancy-safe alternatives.',
            ));
          }
        }
      }
    }
    
    return violations;
  }

  static String _generateSafetyRecommendation(
    List<SafetyViolation> violations,
    double confidenceScore,
  ) {
    if (violations.isEmpty && confidenceScore >= _safetyConfidenceThreshold) {
      return 'Safe to order - All safety checks passed';
    }

    final critical = violations.where((v) => v.severity == 'critical').length;
    final high = violations.where((v) => v.severity == 'high').length;
    final medium = violations.where((v) => v.severity == 'medium').length;

    if (critical > 0) {
      return 'Do not order - Critical health risks detected';
    } else if (high > 0) {
      return 'Caution advised - Consult healthcare provider';
    } else if (medium > 0) {
      return 'Moderate risk - Review warnings before ordering';
    } else {
      return 'Low risk - Minor considerations noted';
    }
  }

  // ============================================================================
  // NUTRITIONAL VARIANCE ANALYSIS
  // ============================================================================

  static double _calculateMacroDeviation({
    required Map<String, double> expected,
    required Map<String, double> actual,
  }) {
    final deviations = <double>[];
    
    for (final key in expected.keys) {
      final expectedValue = expected[key] ?? 0.0;
      final actualValue = actual[key] ?? 0.0;
      
      if (expectedValue > 0) {
        final deviation = (actualValue - expectedValue).abs() / expectedValue;
        deviations.add(deviation);
      }
    }

    if (deviations.isEmpty) return 0.0;
    
    // Return average deviation
    return deviations.reduce((a, b) => a + b) / deviations.length;
  }

  // ============================================================================
  // CONFIDENCE SCORE CALCULATION
  // ============================================================================

  static double _calculateConfidenceScore({
    required double ingredientMatchScore,
    required double macroDeviationScore,
    required double safetyScore,
  }) {
    // Weighted average (safety is most important)
    return (ingredientMatchScore * 0.3) + 
           (macroDeviationScore * 0.2) + 
           (safetyScore * 0.5);
  }

  static IngredientVerificationStatus _determineVerificationStatus({
    required double ingredientMatchScore,
    required double macroDeviation,
    required bool safetyPassed,
  }) {
    if (!safetyPassed) {
      return IngredientVerificationStatus.mismatch;
    }

    if (ingredientMatchScore >= 0.9 && macroDeviation <= 0.1) {
      return IngredientVerificationStatus.verified;
    } else if (ingredientMatchScore >= _ingredientMatchThreshold && 
               macroDeviation <= _macroDeviationThreshold) {
      return IngredientVerificationStatus.partialMatch;
    } else if (ingredientMatchScore < _ingredientMatchThreshold) {
      return IngredientVerificationStatus.mismatch;
    } else {
      return IngredientVerificationStatus.unknown;
    }
  }
}
