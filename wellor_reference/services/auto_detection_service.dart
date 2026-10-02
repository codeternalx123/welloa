import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'allergen_safety_guard.dart';
import 'claude_food_analysis_service.dart';
import 'gemini_food_detection_service.dart';

/// Food Detection Service powered by Gemini 2.5 Flash (free tier).
class AutoDetectionService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    GeminiFoodDetectionService.initialize();
    _initialized = true;
    debugPrint('🚀 Detection Engine: Gemini 2.5 Flash ready.');
  }

  static Future<void> dispose() async {
    _initialized = false;
  }

  // ============================================
  // CORE: GEMINI AI FOOD DETECTION
  // ============================================

  static Future<AutoDetectionResult> analyzeImage(
    XFile imageFile, {
    required List<String> userAllergens,
  }) async {
    await initialize();

    try {
      final cloudResult = await GeminiFoodDetectionService.analyzeMeal(
        imagePaths: [imageFile.path],
        userAllergens: userAllergens,
      );

      return AutoDetectionResult(
        foods: cloudResult.dishes,
        macros: cloudResult.nutrition,
        safetyReport: cloudResult.safetyReport,
        type: DetectionType.food,
      );
    } catch (e) {
      debugPrint('❌ Gemini Detection Failed: $e');
      if (ClaudeFoodAnalysisService().isAvailable) {
        debugPrint('🔄 Falling back to Claude for food analysis');
        return _analyzeWithClaude(imageFile.path, userAllergens);
      }
      rethrow;
    }
  }

  static Future<AutoDetectionResult> _analyzeWithClaude(
    String imagePath,
    List<String> userAllergens,
  ) async {
    final nutrition = await ClaudeFoodAnalysisService.analyzeFood(
      imagePath: imagePath,
      clinicalPrescription: {
        'health_conditions': userAllergens,
        'allergies': userAllergens,
        'dietary_restrictions': <String>[],
      },
    );

    final dishes = nutrition.foodItems.isNotEmpty
        ? nutrition.foodItems.map((item) {
            return DetectedDish(
              name: item.name,
              ingredients: const [],
              weightEstimate: item.weightGrams.round(),
              calories: item.calories.round(),
            );
          }).toList()
        : [
            DetectedDish(
              name: 'Detected meal',
              ingredients: const [],
              weightEstimate: 250,
              calories: nutrition.totalCalories.round(),
              proteinG: nutrition.proteinGrams,
              carbsG: nutrition.carbsGrams,
              fatG: nutrition.fatGrams,
            ),
          ];

    final safetyAudit = AllergenSafetyGuard().auditProduct(
      ingredients: dishes.map((d) => d.name).toList(),
      userAllergens: userAllergens,
    );

    return AutoDetectionResult(
      foods: dishes,
      macros: GlobalNutrition(
        calories: nutrition.totalCalories.round(),
        protein: nutrition.proteinGrams.round(),
        carbs: nutrition.carbsGrams.round(),
        fat: nutrition.fatGrams.round(),
      ),
      safetyReport: safetyAudit,
      type: DetectionType.food,
    );
  }
}

// ============================================
// MODELS: IMMUTABLE DETECTION STATE
// ============================================

enum DetectionType { food, none }

@immutable
class AutoDetectionResult {
  final List<DetectedDish> foods;
  final GlobalNutrition? macros;
  final SafetyAuditReport? safetyReport;
  final DetectionType type;

  const AutoDetectionResult({
    this.foods = const [],
    this.macros,
    this.safetyReport,
    required this.type,
  });
}