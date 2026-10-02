import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/clinical_graph.dart';
import '../models/clinical_food_vision_service.dart';
import '../models/nutrition_calculation.dart';

/// Senior-level AI Orchestrator for Clinical-Grade Food Analysis.
class AICalorieCalculator {
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_SECURE_API_KEY';
  static const String _endpoint = 
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Main entry point: Performs concurrent analysis for speed and accuracy.
  static Future<NutritionCalculation> analyzeFood({
    required String imagePath,
    required Map<String, dynamic> clinicalPrescription,
  }) async {
    // 1. Concurrent Execution: Start both tiers to minimize latency.
    final cloudTask = _analyzeWithGemini(imagePath, clinicalPrescription);
    final localTask = _analyzeLocally(imagePath);

    try {
      // 2. Race/Fallback logic: Gemini provides accurate detection, 
      // local tier returns empty if timeout (forces retry for accuracy)
      final result = await cloudTask.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('⚠️ Gemini timeout after 20s - unable to analyze');
          return localTask;
        },
      );

      // 3. Validate result
      if (result.foodItems.isNotEmpty) {
        debugPrint('✅ Success: ${result.foodItems.length} food item(s) detected');
        for (var item in result.foodItems) {
          debugPrint('  - ${item.name}: ${item.calories} cal, ${item.weightGrams}g');
        }
        return _enforceClinicalSafety(result, clinicalPrescription);
      } else {
        // Empty result from Gemini or timeout
        debugPrint('⚠️ No food detected - image may be unclear or dark');
        return await localTask;
      }
    } catch (e) {
      debugPrint('❌ Analysis error: $e');
      // Return empty rather than guess
      return NutritionCalculation.empty();
    }
  }

  /// New clinical wrapper that returns a richer ClinicalDetectionResult
  /// containing the NutritionCalculation plus vision metadata.
  static Future<ClinicalDetectionResult> analyzeFoodClinical({
    required String imagePath,
    required Map<String, dynamic> clinicalPrescription,
  }) async {
    final nutrition = await analyzeFood(imagePath: imagePath, clinicalPrescription: clinicalPrescription);

    // Heuristic confidence: if there are warnings or empty items, lower confidence
    double confidence = 0.96;
    if (nutrition == NutritionCalculation.empty()) confidence = 0.45;
    if (nutrition.warnings.isNotEmpty) confidence = confidence - 0.15;

    return ClinicalDetectionResult.fromNutrition(nutrition, confidence: confidence);
  }

  /// Tier 1: Semantic Vision Tier (Gemini 2.0 Flash)
  static Future<NutritionCalculation> _analyzeWithGemini(
    String imagePath,
    Map<String, dynamic> prescription,
  ) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_endpoint?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [
              {'text': _generateSystemPrompt(prescription)},
              {'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}}
            ]
          }],
          'generationConfig': {
            'temperature': 0.1, // Near-zero for deterministic clinical results
            'response_mime_type': 'application/json'
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Safe navigation for nested JSON
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final rawOutput = data['candidates'][0]['content']['parts'][0]['text'];
          
          // Extract JSON from markdown code blocks if needed
          String jsonText = rawOutput;
          final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(rawOutput);
          if (jsonMatch != null) {
            jsonText = jsonMatch.group(1) ?? rawOutput;
          }
          
          // Try to parse JSON
          try {
            final parsed = jsonDecode(jsonText);
            return NutritionCalculation.fromJson(parsed);
          } catch (e) {
            debugPrint('JSON parsing failed: $e');
            debugPrint('Raw output: $rawOutput');
            throw Exception('Failed to parse AI response as JSON');
          }
        }
        throw Exception('Invalid response structure from Gemini');
      } else {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        throw Exception('Gemini API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Gemini analysis error: $e');
      throw Exception('Cloud Vision Tier Unavailable: $e');
    }
  }

  /// Tier 2: Local Validation Tier (Minimal Fallback)
  static Future<NutritionCalculation> _analyzeLocally(String imagePath) async {
    try {
      // MINIMAL fallback: Return empty calculation to force user to retry
      // This prevents inaccurate guesses from being used
      debugPrint('⚠️ Using minimal local fallback - please retry with better lighting');
      
      return NutritionCalculation.empty();
    } catch (e) {
      debugPrint('Local fallback error: $e');
      return NutritionCalculation.empty();
    }
  }

  /// Clinical Safety Layer: Intersects AI data with Knowledge Graph constraints.
  static NutritionCalculation _enforceClinicalSafety(
    NutritionCalculation meal, 
    Map<String, dynamic> prescription
  ) {
    final List<String> medicalWarnings = [];
    
    // Handle type casting for nutrientDrivers from API/Firestore
    final driversRaw = prescription['nutrientDrivers'];
    if (driversRaw == null) {
      return meal.copyWith(warnings: medicalWarnings);
    }
    
    // Convert dynamic map to proper types
    final Map<String, NutrientImpact> drivers = {};
    if (driversRaw is Map) {
      driversRaw.forEach((key, value) {
        final nutrient = key.toString();
        NutrientImpact? impact;
        
        // Convert value (could be String, int, or enum) to NutrientImpact
        if (value is NutrientImpact) {
          impact = value;
        } else if (value is String) {
          // Parse string to enum
          try {
            impact = NutrientImpact.values.firstWhere(
              (e) => e.toString().split('.').last == value,
              orElse: () => NutrientImpact.neutral,
            );
          } catch (_) {
            impact = NutrientImpact.neutral;
          }
        }
        
        if (impact != null) {
          drivers[nutrient] = impact;
        }
      });
    }

    // Cross-check detected nutrients against the restrictStrict nodes
    drivers.forEach((nutrient, impact) {
      final value = meal.getNutrient(nutrient);
      if (impact == NutrientImpact.restrictStrict && value > _getCeiling(nutrient)) {
        medicalWarnings.add("🚨 DANGER: $nutrient content exceeds your clinical ceiling.");
      }
    });

    return meal.copyWith(warnings: medicalWarnings);
  }

  static String _generateSystemPrompt(Map<String, dynamic> prescription) {
    return '''
You are a Professional Clinical Dietician with expert Computer Vision abilities.
Analyze the food image provided VERY CAREFULLY and respond ONLY with a JSON object.

⚠️ CRITICAL RULES:
1. ALWAYS detect food if ANY food items are visible in the image
2. For each food item, provide its EXACT NAME (not "food" or "detected food")
3. Estimate weight in grams based on typical serving sizes
4. Use ACCURATE nutritional data for the detected food
5. Return ONLY valid JSON with NO markdown, NO code blocks, NO explanations

COMMON FOOD CALORIE REFERENCE (use for accuracy):
- 1 large egg (50g): 70-80 cal, 6g protein
- 2 eggs (100g): 140-160 cal, 12g protein
- 1 cup rice (150g): 190-210 cal, 4g protein
- 1 slice bread (30g): 75-85 cal, 2g protein
- 100g chicken breast: 160-165 cal, 31g protein
- 100g rice: 130 cal, 2.7g protein
- 100g egg: 150 cal, 13g protein
- 1 apple (182g): 95 cal, 0.5g protein
- 1 banana (118g): 105 cal, 1.3g protein
- 100g fish/salmon: 200 cal, 25g protein

REQUIRED JSON FORMAT (EXACT):
{
  "total_calories": <accurate total>,
  "protein_grams": <accurate protein>,
  "carbs_grams": <accurate carbs>,
  "fat_grams": <accurate fat>,
  "fiber_grams": <accurate fiber>,
  "sodium_mg": <accurate sodium>,
  "potassium_mg": <accurate potassium>,
  "food_items": [
    {
      "name": "specific food name (e.g., 'fried egg', 'boiled rice', 'grilled chicken')",
      "weight_grams": <estimated weight>,
      "calories": <calories for that weight>
    }
  ]
}

RESPONSE FORMAT:
- Return ONLY valid JSON (no markdown)
- If image has food: populate food_items with ACTUAL food names
- Use accurate calorie data from the reference above
- Estimate portion sizes based on visible size in image
- If no food is visible: return empty food_items: []

EXAMPLES OF CORRECT RESPONSES:
- 1 egg: {"name": "boiled egg", "weight_grams": 50, "calories": 75}
- Fried eggs (2): {"name": "fried eggs", "weight_grams": 100, "calories": 160}
- Rice bowl: {"name": "cooked white rice", "weight_grams": 150, "calories": 195}
- Chicken breast: {"name": "grilled chicken breast", "weight_grams": 150, "calories": 250}

MINIMUM REQUIREMENTS:
- If any food is visible, ALWAYS provide accurate food_items
- Use realistic portion sizes
- Match calories to the reference data
- Never return generic "food" or "detected food" names
''';
  }

  static double _getCeiling(String nutrient) {
    // Standard Medical Ceilings per meal
    final caps = {'sodium': 800.0, 'netCarbs': 35.0, 'protein': 25.0};
    return caps[nutrient] ?? 9999.0;
  }

  /// Backwards-compatible wrapper used by UI screens.
  /// Prefer passing a clinical prescription (from MetabolicOrchestrator/NutritionGoalsProvider).
  static Future<NutritionCalculation> calculateFromImage({
    required String imagePath,
    dynamic userGoals,
    Map<String, dynamic>? clinicalPrescription,
  }) async {
    final prescription = clinicalPrescription ?? _prescriptionFromUserGoals(userGoals);
    return await analyzeFood(imagePath: imagePath, clinicalPrescription: prescription);
  }

  /// Wrapper to analyze multiple angles (uses first image as primary input).
  static Future<NutritionCalculation> calculateFromMultipleAngles({
    required List<String> imagePaths,
    dynamic userGoals,
    Map<String, dynamic>? clinicalPrescription,
  }) async {
    if (imagePaths.isEmpty) return NutritionCalculation.empty();
    final prescription = clinicalPrescription ?? _prescriptionFromUserGoals(userGoals);
    // For now, analyze the first angle (server may later support multi-frame fusion)
    return await analyzeFood(imagePath: imagePaths.first, clinicalPrescription: prescription);
  }

  /// Produce simple personalized advice text for UI. Can be extended to call LLM.
  static Future<String> getPersonalizedAdvice({
    required NutritionCalculation currentMeal,
    required dynamic dailyTracker,
    required dynamic userGoals,
    Map<String, dynamic>? clinicalPrescription,
  }) async {
    final prescription = clinicalPrescription ?? _prescriptionFromUserGoals(userGoals);
    final drivers = prescription['nutrientDrivers'] as Map<String, dynamic>? ?? {};

    final warnings = <String>[];
    drivers.forEach((nutrient, imp) {
      // imp may be an enum serialized; normalize string or enum name
      final impactName = imp is String ? imp : imp.toString();
      if (impactName.contains('restrict')) {
        final value = currentMeal.getNutrient(nutrient);
        if (value > _getCeiling(nutrient)) {
          warnings.add('High $nutrient detected');
        }
      }
    });

    if (warnings.isNotEmpty) {
      return '⚠️ ${warnings.join(', ')} — consider swapping items or reducing portion.';
    }

    return 'Looks aligned with your goals today.';
  }

  static Map<String, dynamic> _prescriptionFromUserGoals(dynamic userGoals) {
    try {
      if (userGoals == null) return {'targetCalories': 2000, 'nutrientDrivers': {}, 'clinicalWarnings': []};
      final daily = (userGoals.dailyCalorieTarget != null) ? userGoals.dailyCalorieTarget : 2000;
      return {'targetCalories': daily, 'nutrientDrivers': {}, 'clinicalWarnings': []};
    } catch (_) {
      return {'targetCalories': 2000, 'nutrientDrivers': {}, 'clinicalWarnings': []};
    }
  }

  /// Get available foods for search/filtering
  static Future<List<Map<String, dynamic>>> getAvailableFoods() async {
    // Placeholder: return sample foods
    return const [];
  }

  /// Search USDA database
  static Future<List<Map<String, dynamic>>> searchUSDADatabase(String query) async {
    // Placeholder: return search results
    return [];
  }

  /// Create nutrition from USDA result
  static Future<NutritionCalculation> createFromUSDA(Map<String, dynamic> usdaResult) async {
    return NutritionCalculation(
      totalCalories: _safeToDouble(usdaResult['calories'], 0.0),
      proteinGrams: _safeToDouble(usdaResult['protein'], 0.0),
      carbsGrams: _safeToDouble(usdaResult['carbs'], 0.0),
      fatGrams: _safeToDouble(usdaResult['fats'], 0.0),
      fiberGrams: _safeToDouble(usdaResult['fiber'], 0.0),
      sodiumMg: _safeToDouble(usdaResult['sodium'], 0.0),
      potassiumMg: _safeToDouble(usdaResult['potassium'], 0.0),
      foodItems: [],
    );
  }

  /// Safe conversion from various numeric types to double
  static double _safeToDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return defaultValue;
  }
}