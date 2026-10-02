import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/env_config.dart';
import 'package:image/image.dart' as img; 
import '../models/nutrition_calculation.dart';
import '../models/health_models.dart' hide SafetyAuditReport;
import 'allergen_safety_guard.dart';

/// UNICORN GRADE: High-Concurrency AI Vision & Clinical Intelligence Hub.
///
/// Free-tier food scanning uses Gemini 2.5 Flash (cost-effective, JSON-native).
/// Paid tiers use Claude Sonnet 3.5 via the clinical vision pipeline.
class GeminiFoodDetectionService {
  static final GeminiFoodDetectionService _instance = GeminiFoodDetectionService._internal();
  factory GeminiFoodDetectionService() => _instance;
  GeminiFoodDetectionService._internal();

  static GenerativeModel? _model;
  static final _firestore = FirebaseFirestore.instance;

  /// Initialize with Secure Environment Variables & Forced JSON Mode
  static void initialize() {
    final apiKey = EnvConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      debugPrint('⚠️ CRITICAL: GEMINI_API_KEY missing from environment.');
      debugPrint('📝 Add GEMINI_API_KEY to .env for free-tier food scanning.');
      return;
    }
    
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1, // UNICORN: Stability for nutritional data
        topK: 32,
        topP: 1,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json', // Force valid JSON 
      ),
    );
    
    debugPrint('✅ Wellor Vision Hub: Gemini 2.5 Flash initialized for free-tier scanning.');
  }

  // ============================================
  // CORE DISCOVERY: DETECTION & SAFETY INTERCEPT (Gemini 2.5 Flash — free tier)
  // ============================================

  /// High-fidelity scan that triggers the AI Safety Interceptor.
  /// Fuses image path and multi-angle support into a single polymorphic entry point.
  static Future<GeminiDetectionResult> analyzeMeal({
    required List<String> imagePaths,
    required List<String> userAllergens,
    String? userContext,
  }) async {
    if (_model == null) {
      throw Exception(
        'Food scanning engine not initialized. Add GEMINI_API_KEY to your .env file.',
      );
    }

    debugPrint('🆓 Using Gemini 2.5 Flash for food detection');

    try {
      // 1. BACKGROUND ADAPTIVE COMPRESSION (Isolate-safe)
      final List<DataPart> imageParts = await _processImagesForWire(imagePaths);

      // 2. CONTEXTUAL PROMPT INJECTION
      final prompt = imagePaths.length > 1 
          ? _buildMultiAnglePrompt(userContext, imagePaths.length)
          : _buildStandardPrompt(userContext);

      // 3. EXECUTION WITH LATENCY BUDGET
      final response = await _model!.generateContent([
        Content.multi([TextPart(prompt), ...imageParts])
      ]).timeout(const Duration(seconds: 15));

      final responseText = response.text;
      if (responseText == null || responseText.trim().isEmpty) {
        throw Exception('EMPTY_AI_RESPONSE');
      }

      // 4. ISOLATE-SAFE PARSING
      final result = await compute(_parseAndHydrate, {
        'json': _extractJsonPayload(responseText),
        'path': imagePaths.first
      });

      if (result.dishes.isEmpty) {
        throw Exception('NO_FOOD_DETECTED');
      }

      // 5. UNICORN BRIDGE: THE AI SAFETY INTERCEPTOR
      final allDetectedIngredients = result.dishes
          .expand((dish) => dish.ingredients.map((i) => i.name))
          .toList();

      final safetyAudit = AllergenSafetyGuard().auditProduct(
        ingredients: allDetectedIngredients,
        userAllergens: userAllergens,
      );

      return result.copyWith(safetyReport: safetyAudit);

    } on TimeoutException {
      throw Exception('Ecosystem Latency: Try moving to better signal.');
    } catch (e) {
      debugPrint('❌ Vision Hub Crash: $e');
      rethrow;
    }
  }

  // ============================================
  // PRE-PROCESSING: BACKGROUND ISOLATES
  // ============================================

  /// Compresses and resizes to 800px on a background thread to keep UI at 60fps.
  static Future<List<DataPart>> _processImagesForWire(List<String> paths) async {
    return await compute((List<String> p) async {
      final List<DataPart> processed = [];
      for (var path in p) {
        final bytes = File(path).readAsBytesSync();
        final image = img.decodeImage(bytes);
        if (image != null) {
          final resized = img.copyResize(image, width: 800);
          processed.add(DataPart('image/jpeg', 
            Uint8List.fromList(img.encodeJpg(resized, quality: 75))));
        }
      }
      if (processed.isEmpty) {
        throw Exception('Could not read image file');
      }
      return processed;
    }, paths);
  }

  static String _extractJsonPayload(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    final listStart = text.indexOf('[');
    if (start == -1 && listStart >= 0) return text.substring(listStart);
    if (start >= 0 && (listStart < 0 || start < listStart)) {
      return text.substring(start);
    }
    if (listStart >= 0) return text.substring(listStart);
    return text;
  }

  static GeminiDetectionResult _parseAndHydrate(Map<String, dynamic> params) {
    try {
      final decoded = jsonDecode(params['json']);
    final Map<String, dynamic> map;

    if (decoded is List) {
      map = {'dishes': decoded};
    } else if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('dishes')) {
        map = decoded;
      } else if (decoded.containsKey('foods')) {
        map = {'dishes': decoded['foods'], 'nutrition': decoded['nutrition']};
      } else {
        map = decoded;
      }
    } else {
      map = const {'dishes': []};
    }

    return GeminiDetectionResult.fromMap(map, params['path']);
    } catch (e) {
      debugPrint('❌ Food JSON parse error: $e | raw=${params['json']}');
      return GeminiDetectionResult.fromMap(const {'dishes': []}, params['path']);
    }
  }

  // ============================================
  // CLINICAL GROUNDING: SYSTEM PROMPTS
  // ============================================

  static String _buildStandardPrompt(String? context) {
    return '''
    ACT AS: Senior Clinical Nutritionist Vision System.
    TASK: Identify ALL food items separately and quantify nutrition for EACH using USDA anchors.
    CONTEXT: ${context ?? 'None'}
    ANCHORS: 1 Egg: 78cal, 6.3g protein, 0.6g carbs, 5.3g fat | 100g Chicken: 165cal, 31g protein, 0g carbs, 3.6g fat | 1tbsp Oil: 120cal, 0g protein, 0g carbs, 14g fat

    CRITICAL: For EACH detected food item, provide INDIVIDUAL macro breakdown:
    - Name each food specifically (e.g. 'Grilled Chicken Breast' not just 'food')
    - Calories for THIS dish (must not be 0)
    - Protein in grams for THIS dish
    - Carbs in grams for THIS dish
    - Fat in grams for THIS dish
    - Weight estimate in grams

    IMPORTANT: If multiple dishes are visible, list each one separately with its OWN nutrition.

    Requirement: Return EXACT JSON with this structure:
    {
      "dishes": [
        {
          "name": "specific food name",
          "weight_estimate": 100,
          "calories": 165,
          "protein_g": 31,
          "carbs_g": 0,
          "fat_g": 3.6,
          "ingredients": [
            {"name": "ingredient", "weight_grams": 100}
          ]
        }
      ],
      "nutrition": {
        "calories": 165,
        "protein_g": 31,
        "carbs_g": 0,
        "fat_g": 3.6
      }
    }
    ''';
  }

  static String _buildMultiAnglePrompt(String? context, int count) {
    return '''
    ACT AS: Volumetric Multi-Angle Analysis System.
    TASK: Cross-reference $count images to identify ALL visible food items and provide INDIVIDUAL nutrition for EACH.
    CONTEXT: ${context ?? 'None'}
    ANCHORS: 1 Egg: 78cal, 6.3g protein, 0.6g carbs, 5.3g fat | 100g Chicken: 165cal, 31g protein, 0g carbs, 3.6g fat | 1tbsp Oil: 120cal, 0g protein, 0g carbs, 14g fat

    CRITICAL: For EACH detected food item separately:
    - Name each food specifically (e.g. 'Spaghetti with Meat Sauce' not 'food')
    - Calories for THIS dish (never 0)
    - Protein in grams for THIS dish
    - Carbs in grams for THIS dish
    - Fat in grams for THIS dish
    - Weight estimate in grams

    IMPORTANT: If multiple dishes are visible, list each one separately with its OWN nutrition.
    
    Requirement: Return JSON with this structure:
    {
      "dishes": [
        {
          "name": "specific food name",
          "weight_estimate": 100,
          "calories": 165,
          "protein_g": 31,
          "carbs_g": 0,
          "fat_g": 3.6,
          "ingredients": [{"name": "ingredient", "weight_grams": 100}]
        }
      ],
      "nutrition": {
        "calories": 165,
        "protein_g": 31,
        "carbs_g": 0,
        "fat_g": 3.6
      }
    }
    ''';
  }

  // ============================================
  // TELEMETRY & TRAINING
  // ============================================

  static Future<void> saveUserCorrection({
    required String originalDetectionId,
    required List<DetectedDish> correctedDishes,
    required String userId,
  }) async {
    try {
      await _firestore.collection('food_detection_corrections').add({
        'detection_id': originalDetectionId,
        'corrected_dishes': correctedDishes.map((d) => d.toJson()).toList(),
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Telemetry: Training data ingested.');
    } catch (e) {
      debugPrint('❌ Telemetry Error: $e');
    }
  }
}

// ============================================
// MODELS: IMMUTABLE DATA ENTITIES
// ============================================

@immutable
class GeminiDetectionResult {
  final List<DetectedDish> dishes;
  final GlobalNutrition? nutrition;
  final SafetyAuditReport? safetyReport;
  final String primaryImagePath;
  final DateTime detectionTime;
  final String scanMode;
  final GeminiBarcodeInfo? barcodeInfo;
  final List<String> allergens;
  final List<String> allergenMayContain;
  final List<String> flags;
  final List<GeminiProfileFlag> profileFlags;
  final String? scanRecommendation;
  final String? productName;
  final String? productBrand;

  const GeminiDetectionResult({
    required this.dishes,
    this.nutrition,
    this.safetyReport,
    required this.primaryImagePath,
    required this.detectionTime,
    this.scanMode = 'visual',
    this.barcodeInfo,
    this.allergens = const [],
    this.allergenMayContain = const [],
    this.flags = const [],
    this.profileFlags = const [],
    this.scanRecommendation,
    this.productName,
    this.productBrand,
  });

  factory GeminiDetectionResult.fromMap(Map<String, dynamic> map, String path) {
    return GeminiDetectionResult(
      primaryImagePath: path,
      detectionTime: DateTime.now(),
      dishes: (map['dishes'] as List? ?? []).map((d) => DetectedDish.fromMap(d)).toList(),
      nutrition: map['nutrition'] != null ? GlobalNutrition.fromMap(map['nutrition']) : null,
      productName: map['product_name']?.toString(),
      productBrand: map['brand']?.toString(),
    );
  }

  GeminiDetectionResult copyWith({SafetyAuditReport? safetyReport}) => GeminiDetectionResult(
    dishes: dishes,
    nutrition: nutrition,
    primaryImagePath: primaryImagePath,
    detectionTime: detectionTime,
    safetyReport: safetyReport ?? this.safetyReport,
    scanMode: scanMode,
    barcodeInfo: barcodeInfo,
    allergens: allergens,
    allergenMayContain: allergenMayContain,
    flags: flags,
    profileFlags: profileFlags,
    scanRecommendation: scanRecommendation,
    productName: productName,
    productBrand: productBrand,
  );

  String get detectionId => '${primaryImagePath}_${detectionTime.millisecondsSinceEpoch}';
}

@immutable
class DetectedDish {
  final String name;
  final List<DetectedIngredient> ingredients;
  final int? weightEstimate;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const DetectedDish({
    required this.name, 
    required this.ingredients, 
    this.weightEstimate,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  factory DetectedDish.fromMap(Map<String, dynamic> map) => DetectedDish(
    name: map['name'] ?? 'Unknown',
    weightEstimate: _safeToInt(map['weight_estimate']),
    calories: _safeToInt(map['calories'] ?? 0),
    proteinG: (map['protein_g'] as num? ?? 0).toDouble(),
    carbsG: (map['carbs_g'] as num? ?? 0).toDouble(),
    fatG: (map['fat_g'] as num? ?? 0).toDouble(),
    ingredients: (map['ingredients'] as List? ?? []).map((i) => 
      i is Map<String, dynamic> ? DetectedIngredient.fromJson(i) : DetectedIngredient(name: i.toString())
    ).toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name, 
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
  };
}

@immutable
class DetectedIngredient {
  final String name;
  final double weightGrams;

  const DetectedIngredient({required this.name, this.weightGrams = 0.0});

  factory DetectedIngredient.fromJson(Map<String, dynamic> json) => DetectedIngredient(
    name: json['name'] ?? 'Unknown',
    weightGrams: (json['weight_grams'] as num? ?? 0.0).toDouble(),
  );

  Map<String, dynamic> toJson() => {'name': name, 'weight_grams': weightGrams};
}

@immutable
class GlobalNutrition {
  final int calories, protein, carbs, fat;
  const GlobalNutrition({required this.calories, required this.protein, required this.carbs, required this.fat});

  factory GlobalNutrition.fromMap(Map<String, dynamic> map) => GlobalNutrition(
    calories: _safeToInt(map['calories'] ?? 0),
    protein: _safeToInt(map['protein_g'] ?? map['protein'] ?? 0),
    carbs: _safeToInt(map['carbs_g'] ?? map['carbs'] ?? 0),
    fat: _safeToInt(map['fat_g'] ?? map['fat'] ?? 0),
  );

  factory GlobalNutrition.fromScannerMap(Map<String, dynamic> map) => GlobalNutrition(
    calories: _safeToInt(map['calories_kcal'] ?? map['calories'] ?? 0),
    protein: _safeToInt(map['protein_g'] ?? map['protein'] ?? 0),
    carbs: _safeToInt(map['carbohydrates_g'] ?? map['carbs_g'] ?? map['carbs'] ?? 0),
    fat: _safeToInt(map['fat_g'] ?? map['fat'] ?? 0),
  );
}

@immutable
class GeminiBarcodeInfo {
  final bool detected;
  final String? symbology;
  final String? value;
  final bool checksumValid;
  final bool productFound;
  final String? productName;
  final String? brand;

  const GeminiBarcodeInfo({
    required this.detected,
    this.symbology,
    this.value,
    required this.checksumValid,
    required this.productFound,
    this.productName,
    this.brand,
  });

  factory GeminiBarcodeInfo.fromMap(Map<String, dynamic> map) => GeminiBarcodeInfo(
    detected: map['detected'] == true,
    symbology: map['symbology']?.toString(),
    value: map['value']?.toString(),
    checksumValid: map['checksum_valid'] != false,
    productFound: map['product_found'] == true,
    productName: map['product_name']?.toString(),
    brand: map['brand']?.toString(),
  );
}

@immutable
class GeminiProfileFlag {
  final String type;
  final String message;

  const GeminiProfileFlag({required this.type, required this.message});

  factory GeminiProfileFlag.fromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return GeminiProfileFlag(
        type: value['type']?.toString() ?? 'info',
        message: value['message']?.toString() ?? '',
      );
    }

    return GeminiProfileFlag(
      type: 'info',
      message: value?.toString() ?? '',
    );
  }
}

Map<String, dynamic>? _selectNutritionBlock(Map<String, dynamic> map) {
  final userPortion = map['nutrition_user_portion'];
  if (userPortion is Map<String, dynamic> && userPortion.isNotEmpty) {
    return userPortion;
  }

  final perServing = map['nutrition_per_serving'];
  if (perServing is Map<String, dynamic> && perServing.isNotEmpty) {
    return perServing;
  }

  final per100g = map['nutrition_per_100g'];
  if (per100g is Map<String, dynamic> && per100g.isNotEmpty) {
    return per100g;
  }

  return null;
}

/// Safe conversion from various numeric types to int
int _safeToInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}