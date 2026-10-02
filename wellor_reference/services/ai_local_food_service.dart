import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

/// AI Service for detecting local/regional food names and reverse engineering
/// ingredients with USDA-based nutrition values.
///
/// Features:
/// - Recognize local/regional food names (e.g., Jollof rice, Fufu, Pap, Ugali)
/// - Reverse engineer ingredients from local food names
/// - Calculate accurate nutrition using USDA standards
/// - Container detection for smart single/multi-angle prompts
class AILocalFoodService {
  // Use the same API key as AICalorieCalculator for consistency
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyD8Y0lqg64K9jlsK0HBWe9tsLLEEnWWt1Q',
  );

    static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static GenerativeModel? _model;

  /// Initialize the Gemini model
  static void initialize() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        topK: 32,
        topP: 1,
        maxOutputTokens: 2048,
      ),
    );

    debugPrint('✅ AI Local Food Service initialized');
  }

  /// Detect local/regional food name and get USDA-based nutrition
  ///
  /// This method takes a food name (potentially in local dialect or regional name)
  /// and returns detailed nutrition information by:
  /// 1. Identifying the food
  /// 2. Reverse engineering ingredients
  /// 3. Calculating nutrition using USDA standards
  static Future<LocalFoodResult> analyzeLocalFood({
    required String foodName,
    double portionGrams = 100,
    String? regionHint,
  }) async {
    try {
      final prompt = _buildLocalFoodPrompt(foodName, portionGrams, regionHint);

      final url = Uri.parse('$_geminiEndpoint?key=$_apiKey');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.2,
                'topK': 32,
                'topP': 1,
                'maxOutputTokens': 2048,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null &&
              content['parts'] != null &&
              content['parts'].isNotEmpty) {
            final responseText = content['parts'][0]['text'] as String;
            debugPrint('🌍 Local Food AI Response: $responseText');
            return _parseLocalFoodResponse(responseText, foodName);
          }
        }
      } else {
        debugPrint('❌ Local food API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Local food analysis error: $e');
    }

    // Fallback to local database lookup
    return _lookupLocalDatabase(foodName, portionGrams);
  }

  /// Lookup food in local database as fallback
  static LocalFoodResult _lookupLocalDatabase(
    String foodName,
    double portionGrams,
  ) {
    final normalizedName = foodName.toLowerCase().trim();

    // Comprehensive USDA-based food database
    final Map<String, Map<String, dynamic>> foodDatabase = {
      // Eggs
      'egg': {'cal': 72, 'p': 6.3, 'c': 0.4, 'f': 5.0, 'portion': 50},
      'eggs': {'cal': 72, 'p': 6.3, 'c': 0.4, 'f': 5.0, 'portion': 50},
      'boiled egg': {'cal': 78, 'p': 6.3, 'c': 0.6, 'f': 5.3, 'portion': 50},
      'fried egg': {'cal': 92, 'p': 6.3, 'c': 0.4, 'f': 7.0, 'portion': 46},
      'scrambled egg': {'cal': 91, 'p': 6.1, 'c': 1.0, 'f': 6.7, 'portion': 61},
      'chicken egg': {'cal': 72, 'p': 6.3, 'c': 0.4, 'f': 5.0, 'portion': 50},
      'hard boiled egg': {
        'cal': 78,
        'p': 6.3,
        'c': 0.6,
        'f': 5.3,
        'portion': 50,
      },
      'soft boiled egg': {
        'cal': 78,
        'p': 6.3,
        'c': 0.6,
        'f': 5.3,
        'portion': 50,
      },
      'poached egg': {'cal': 72, 'p': 6.3, 'c': 0.4, 'f': 5.0, 'portion': 50},
      'omelette': {'cal': 154, 'p': 11, 'c': 1.6, 'f': 12, 'portion': 100},

      // Common foods
      'rice': {'cal': 130, 'p': 2.7, 'c': 28, 'f': 0.3, 'portion': 100},
      'white rice': {'cal': 130, 'p': 2.7, 'c': 28, 'f': 0.3, 'portion': 100},
      'brown rice': {'cal': 112, 'p': 2.6, 'c': 24, 'f': 0.9, 'portion': 100},
      'bread': {'cal': 265, 'p': 9, 'c': 49, 'f': 3.2, 'portion': 100},
      'chicken': {'cal': 165, 'p': 31, 'c': 0, 'f': 3.6, 'portion': 100},
      'chicken breast': {'cal': 165, 'p': 31, 'c': 0, 'f': 3.6, 'portion': 100},
      'beef': {'cal': 250, 'p': 26, 'c': 0, 'f': 15, 'portion': 100},
      'fish': {'cal': 136, 'p': 20, 'c': 0, 'f': 6, 'portion': 100},
      'banana': {'cal': 89, 'p': 1.1, 'c': 23, 'f': 0.3, 'portion': 118},
      'apple': {'cal': 52, 'p': 0.3, 'c': 14, 'f': 0.2, 'portion': 182},
      'milk': {'cal': 61, 'p': 3.2, 'c': 4.8, 'f': 3.3, 'portion': 100},
      'potato': {'cal': 77, 'p': 2, 'c': 17, 'f': 0.1, 'portion': 100},
      'pasta': {'cal': 131, 'p': 5, 'c': 25, 'f': 1.1, 'portion': 100},
      'salad': {'cal': 20, 'p': 1.5, 'c': 3.5, 'f': 0.2, 'portion': 100},

      // African foods
      'jollof rice': {'cal': 175, 'p': 4, 'c': 28, 'f': 6, 'portion': 100},
      'fufu': {'cal': 178, 'p': 1.3, 'c': 43, 'f': 0.3, 'portion': 100},
      'ugali': {'cal': 177, 'p': 2.7, 'c': 41, 'f': 0.7, 'portion': 100},
      'pap': {'cal': 90, 'p': 2, 'c': 20, 'f': 0.5, 'portion': 100},
      'sadza': {'cal': 177, 'p': 2.7, 'c': 41, 'f': 0.7, 'portion': 100},

      // Asian foods
      'sushi': {'cal': 150, 'p': 6, 'c': 25, 'f': 3, 'portion': 100},
      'noodles': {'cal': 138, 'p': 5, 'c': 25, 'f': 2, 'portion': 100},
      'ramen': {'cal': 190, 'p': 8, 'c': 26, 'f': 7, 'portion': 100},

      // Indian foods
      'chapati': {'cal': 120, 'p': 3.5, 'c': 18, 'f': 3.7, 'portion': 40},
      'naan': {'cal': 262, 'p': 9, 'c': 45, 'f': 5, 'portion': 90},
      'dal': {'cal': 116, 'p': 9, 'c': 20, 'f': 0.4, 'portion': 100},
      'biryani': {'cal': 180, 'p': 7, 'c': 24, 'f': 6, 'portion': 100},
    };

    // Find matching food
    Map<String, dynamic>? foodData;
    String matchedName = foodName;

    for (final entry in foodDatabase.entries) {
      if (normalizedName.contains(entry.key) ||
          entry.key.contains(normalizedName)) {
        foodData = entry.value;
        matchedName = entry.key;
        break;
      }
    }

    if (foodData != null) {
      final basePortionGrams = (foodData['portion'] as num).toDouble();
      final multiplier = portionGrams / basePortionGrams;

      return LocalFoodResult(
        originalName: foodName,
        standardName: matchedName
            .split(' ')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' '),
        ingredients: [],
        nutrition: LocalFoodNutrition(
          calories: (foodData['cal'] as num).toDouble() * multiplier,
          protein: (foodData['p'] as num).toDouble() * multiplier,
          carbs: (foodData['c'] as num).toDouble() * multiplier,
          fat: (foodData['f'] as num).toDouble() * multiplier,
          fiber: 0,
          sugar: 0,
          sodium: 0,
          cholesterol: foodName.toLowerCase().contains('egg')
              ? 186 * multiplier
              : 0,
        ),
        confidence: 0.95,
        isLocalFood: false,
      );
    }

    // Return empty result if not found
    return LocalFoodResult(
      originalName: foodName,
      standardName: foodName,
      ingredients: [],
      nutrition: LocalFoodNutrition.empty(),
      confidence: 0.3,
      isLocalFood: false,
    );
  }

  /// Analyze image to detect if food is in a container (plate/bowl)
  /// to suggest appropriate scanning mode
  static Future<ContainerDetectionResult> detectContainer({
    required String imagePath,
  }) async {
    if (_model == null) {
      return ContainerDetectionResult(
        hasContainer: false,
        containerType: 'unknown',
        recommendedMode: ScanMode.single,
        confidence: 0.5,
        reasoning: 'AI not initialized',
      );
    }

    try {
      final imageFile = await _readImageFile(imagePath);
      if (imageFile == null) {
        return ContainerDetectionResult(
          hasContainer: false,
          containerType: 'unknown',
          recommendedMode: ScanMode.single,
          confidence: 0.5,
          reasoning: 'Could not read image',
        );
      }

      final prompt = _buildContainerDetectionPrompt();

      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageFile)]),
      ];

      final response = await _model!.generateContent(content);
      final responseText = response.text ?? '';

      debugPrint('📦 Container Detection Response: $responseText');

      return _parseContainerResponse(responseText);
    } catch (e) {
      debugPrint('❌ Container detection error: $e');
      return ContainerDetectionResult(
        hasContainer: false,
        containerType: 'unknown',
        recommendedMode: ScanMode.single,
        confidence: 0.5,
        reasoning: 'Error during detection: $e',
      );
    }
  }

  /// Read image file as bytes
  static Future<Uint8List?> _readImageFile(String path) async {
    try {
      final file = File(path);
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Error reading image file: $e');
      return null;
    }
  }

  /// Build prompt for local food analysis
  static String _buildLocalFoodPrompt(
    String foodName,
    double portionGrams,
    String? regionHint,
  ) {
    return '''
Analyze this food name and provide detailed nutrition information using USDA standards.

Food Name: "$foodName"
Portion Size: ${portionGrams.toInt()}g
${regionHint != null ? 'Region Hint: $regionHint' : ''}

Your task:
1. Identify if this is a local/regional food name (e.g., Jollof rice, Fufu, Pap, Ugali, Sadza, Chapati, Injera, Moin Moin, etc.)
2. If local/regional, provide the standard international name equivalent
3. Reverse engineer the typical ingredients
4. Calculate ACCURATE nutrition using USDA standards for each ingredient

IMPORTANT USDA CALORIE REFERENCES:
- 1 cup cooked rice = 200-240 calories
- 1 cup cooked beans = 225 calories
- 1 tablespoon palm oil = 120 calories
- 1 medium egg = 70-75 calories
- 100g chicken = 165 calories
- 100g beef = 250 calories
- 100g fish = 100-150 calories
- 1 cup cooked yam = 177 calories
- 1 cup cooked cassava = 330 calories
- 1 cup maize meal = 500 calories
- 1 cup cooked plantain = 179 calories

Return ONLY a valid JSON object (no markdown, no code blocks):
{
  "original_name": "$foodName",
  "standard_name": "Standard food name",
  "is_local_food": true,
  "region": "Region of origin",
  "ingredients": [
    {
      "name": "Ingredient Name",
      "weight_grams": 50,
      "calories": 100,
      "protein_g": 2,
      "carbs_g": 20,
      "fat_g": 1
    }
  ],
  "total_nutrition": {
    "calories": 250,
    "protein_g": 8,
    "carbs_g": 45,
    "fat_g": 5,
    "fiber_g": 3,
    "sugar_g": 2,
    "sodium_mg": 400,
    "cholesterol_mg": 0
  },
  "confidence": 0.95,
  "description": "Brief description of the food"
}

Be ACCURATE with calories - use USDA standards for each ingredient and sum them correctly.
''';
  }

  /// Build prompt for container detection
  static String _buildContainerDetectionPrompt() {
    return '''
Analyze this food image to determine if the food is in a container and recommend the appropriate scanning mode.

Analyze for:
1. Is the food in a container (plate, bowl, tray, etc.)?
2. What type of container?
3. Is the food layered or mixed where multiple angles would help?
4. Can the food be clearly identified from a single view?

SCANNING MODE RECOMMENDATIONS:
- MULTI-ANGLE: Use for food in plates/bowls with multiple items, layered dishes, mixed dishes, soups with hidden ingredients
- SINGLE: Use for single items not in containers, packaged food, simple snacks, drinks in glasses, individual fruits/vegetables

Return ONLY a valid JSON object (no markdown, no code blocks):
{
  "has_container": true,
  "container_type": "plate/bowl/tray/cup/none",
  "food_complexity": "simple/mixed/layered",
  "recommended_mode": "multi/single",
  "confidence": 0.9,
  "reasoning": "Brief explanation of recommendation"
}
''';
  }

  /// Parse local food response
  static LocalFoodResult _parseLocalFoodResponse(
    String responseText,
    String originalName,
  ) {
    try {
      String cleanJson = _cleanJsonResponse(responseText);
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;

      final ingredients = <LocalFoodIngredient>[];
      if (json['ingredients'] != null) {
        for (final ing in json['ingredients'] as List) {
          ingredients.add(
            LocalFoodIngredient.fromJson(ing as Map<String, dynamic>),
          );
        }
      }

      final nutrition = json['total_nutrition'] != null
          ? LocalFoodNutrition.fromJson(
              json['total_nutrition'] as Map<String, dynamic>,
            )
          : LocalFoodNutrition.empty();

      return LocalFoodResult(
        originalName: json['original_name'] ?? originalName,
        standardName: json['standard_name'] ?? originalName,
        region: json['region'],
        ingredients: ingredients,
        nutrition: nutrition,
        confidence: (json['confidence'] ?? 0.5).toDouble(),
        isLocalFood: json['is_local_food'] ?? false,
        description: json['description'],
      );
    } catch (e) {
      debugPrint('❌ Failed to parse local food response: $e');
      return LocalFoodResult(
        originalName: originalName,
        standardName: originalName,
        ingredients: [],
        nutrition: LocalFoodNutrition.empty(),
        confidence: 0.5,
        isLocalFood: false,
      );
    }
  }

  /// Parse container detection response
  static ContainerDetectionResult _parseContainerResponse(String responseText) {
    try {
      String cleanJson = _cleanJsonResponse(responseText);
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;

      return ContainerDetectionResult(
        hasContainer: json['has_container'] ?? false,
        containerType: json['container_type'] ?? 'unknown',
        foodComplexity: json['food_complexity'] ?? 'simple',
        recommendedMode: json['recommended_mode'] == 'multi'
            ? ScanMode.multi
            : ScanMode.single,
        confidence: (json['confidence'] ?? 0.5).toDouble(),
        reasoning: json['reasoning'] ?? '',
      );
    } catch (e) {
      debugPrint('❌ Failed to parse container response: $e');
      return ContainerDetectionResult(
        hasContainer: false,
        containerType: 'unknown',
        recommendedMode: ScanMode.single,
        confidence: 0.5,
        reasoning: 'Parse error',
      );
    }
  }

  /// Clean JSON response from markdown formatting
  static String _cleanJsonResponse(String responseText) {
    String cleanJson = responseText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    return cleanJson.trim();
  }
}

/// Enum for scanning modes
enum ScanMode { single, multi }

/// Result from local food analysis
class LocalFoodResult {
  final String originalName;
  final String standardName;
  final String? region;
  final List<LocalFoodIngredient> ingredients;
  final LocalFoodNutrition nutrition;
  final double confidence;
  final bool isLocalFood;
  final String? description;

  LocalFoodResult({
    required this.originalName,
    required this.standardName,
    this.region,
    required this.ingredients,
    required this.nutrition,
    required this.confidence,
    required this.isLocalFood,
    this.description,
  });
}

/// Individual ingredient from reverse engineering
class LocalFoodIngredient {
  final String name;
  final double weightGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  LocalFoodIngredient({
    required this.name,
    required this.weightGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory LocalFoodIngredient.fromJson(Map<String, dynamic> json) {
    return LocalFoodIngredient(
      name: json['name'] ?? 'Unknown',
      weightGrams: (json['weight_grams'] ?? 0).toDouble(),
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein_g'] ?? 0).toDouble(),
      carbs: (json['carbs_g'] ?? 0).toDouble(),
      fat: (json['fat_g'] ?? 0).toDouble(),
    );
  }
}

/// Nutrition data from local food analysis
class LocalFoodNutrition {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double cholesterol;

  LocalFoodNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.cholesterol,
  });

  factory LocalFoodNutrition.empty() {
    return LocalFoodNutrition(
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      fiber: 0,
      sugar: 0,
      sodium: 0,
      cholesterol: 0,
    );
  }

  factory LocalFoodNutrition.fromJson(Map<String, dynamic> json) {
    return LocalFoodNutrition(
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein_g'] ?? 0).toDouble(),
      carbs: (json['carbs_g'] ?? 0).toDouble(),
      fat: (json['fat_g'] ?? 0).toDouble(),
      fiber: (json['fiber_g'] ?? 0).toDouble(),
      sugar: (json['sugar_g'] ?? 0).toDouble(),
      sodium: (json['sodium_mg'] ?? 0).toDouble(),
      cholesterol: (json['cholesterol_mg'] ?? 0).toDouble(),
    );
  }
}

/// Result from container detection
class ContainerDetectionResult {
  final bool hasContainer;
  final String containerType;
  final String? foodComplexity;
  final ScanMode recommendedMode;
  final double confidence;
  final String reasoning;

  ContainerDetectionResult({
    required this.hasContainer,
    required this.containerType,
    this.foodComplexity,
    required this.recommendedMode,
    required this.confidence,
    required this.reasoning,
  });

  /// Get user-friendly recommendation text
  String get recommendationText {
    if (recommendedMode == ScanMode.multi) {
      return '📸 Multi-angle recommended for this ${containerType.isNotEmpty ? containerType : 'dish'}. Capture 3 views for best accuracy!';
    } else {
      return '📷 Single photo works great for this item!';
    }
  }

  /// Get icon for the recommendation
  String get recommendationIcon {
    return recommendedMode == ScanMode.multi ? '🔄' : '📷';
  }
}
