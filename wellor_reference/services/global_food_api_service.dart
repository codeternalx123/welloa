// lib/services/global_food_api_service.dart
// PRINCIPAL ENGINEER GRADE: Multi-Source Global Food Intelligence Hub
// Connects to FatSecret, Spoonacular, Edamam, and Open Food Facts for millions of global foods

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/env_config.dart';
import 'package:http/http.dart' as http;

// ============================================
// DATA MODELS
// ============================================

/// Unified food item from any API source
class GlobalFoodItem {
  final String id;
  final String name;
  final String? localName; // Native/local name
  final String? brand;
  final String source; // API source
  final String? cuisine;
  final String? region;
  final NutritionInfo nutrition;
  final ServingInfo serving;
  final List<String> ingredients;
  final List<String> allergens;
  final String? imageUrl;
  final double? price; // Estimated price
  final String? currency;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final String? difficulty;
  final List<String> dietLabels;
  final List<String> healthLabels;
  final double? glycemicIndex;
  final Map<String, dynamic> raw; // Raw API response

  GlobalFoodItem({
    required this.id,
    required this.name,
    this.localName,
    this.brand,
    required this.source,
    this.cuisine,
    this.region,
    required this.nutrition,
    required this.serving,
    this.ingredients = const [],
    this.allergens = const [],
    this.imageUrl,
    this.price,
    this.currency,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.difficulty,
    this.dietLabels = const [],
    this.healthLabels = const [],
    this.glycemicIndex,
    this.raw = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'localName': localName,
    'brand': brand,
    'source': source,
    'cuisine': cuisine,
    'region': region,
    'nutrition': nutrition.toJson(),
    'serving': serving.toJson(),
    'ingredients': ingredients,
    'allergens': allergens,
    'imageUrl': imageUrl,
    'price': price,
    'currency': currency,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'difficulty': difficulty,
    'dietLabels': dietLabels,
    'healthLabels': healthLabels,
    'glycemicIndex': glycemicIndex,
  };

  factory GlobalFoodItem.fromJson(Map<String, dynamic> json) => GlobalFoodItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    localName: json['localName'],
    brand: json['brand'],
    source: json['source'] ?? 'unknown',
    cuisine: json['cuisine'],
    region: json['region'],
    nutrition: NutritionInfo.fromJson(json['nutrition'] ?? {}),
    serving: ServingInfo.fromJson(json['serving'] ?? {}),
    ingredients: List<String>.from(json['ingredients'] ?? []),
    allergens: List<String>.from(json['allergens'] ?? []),
    imageUrl: json['imageUrl'],
    price: json['price']?.toDouble(),
    currency: json['currency'],
    prepTimeMinutes: json['prepTimeMinutes'],
    cookTimeMinutes: json['cookTimeMinutes'],
    difficulty: json['difficulty'],
    dietLabels: List<String>.from(json['dietLabels'] ?? []),
    healthLabels: List<String>.from(json['healthLabels'] ?? []),
    glycemicIndex: json['glycemicIndex']?.toDouble(),
  );
}

/// Unified nutrition information
class NutritionInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double saturatedFat;
  final double cholesterol;
  final double potassium;
  final double calcium;
  final double iron;
  final double vitaminA;
  final double vitaminC;
  final double vitaminD;

  NutritionInfo({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.saturatedFat = 0,
    this.cholesterol = 0,
    this.potassium = 0,
    this.calcium = 0,
    this.iron = 0,
    this.vitaminA = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
  });

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sugar': sugar,
    'sodium': sodium,
    'saturatedFat': saturatedFat,
    'cholesterol': cholesterol,
    'potassium': potassium,
    'calcium': calcium,
    'iron': iron,
    'vitaminA': vitaminA,
    'vitaminC': vitaminC,
    'vitaminD': vitaminD,
  };

  factory NutritionInfo.fromJson(Map<String, dynamic> json) => NutritionInfo(
    calories: (json['calories'] ?? 0).toDouble(),
    protein: (json['protein'] ?? 0).toDouble(),
    carbs: (json['carbs'] ?? 0).toDouble(),
    fat: (json['fat'] ?? 0).toDouble(),
    fiber: (json['fiber'] ?? 0).toDouble(),
    sugar: (json['sugar'] ?? 0).toDouble(),
    sodium: (json['sodium'] ?? 0).toDouble(),
    saturatedFat: (json['saturatedFat'] ?? 0).toDouble(),
    cholesterol: (json['cholesterol'] ?? 0).toDouble(),
    potassium: (json['potassium'] ?? 0).toDouble(),
    calcium: (json['calcium'] ?? 0).toDouble(),
    iron: (json['iron'] ?? 0).toDouble(),
    vitaminA: (json['vitaminA'] ?? 0).toDouble(),
    vitaminC: (json['vitaminC'] ?? 0).toDouble(),
    vitaminD: (json['vitaminD'] ?? 0).toDouble(),
  );
}

/// Serving size information
class ServingInfo {
  final double amount;
  final String unit;
  final double grams;
  final String? description;

  ServingInfo({
    this.amount = 1,
    this.unit = 'serving',
    this.grams = 100,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'unit': unit,
    'grams': grams,
    'description': description,
  };

  factory ServingInfo.fromJson(Map<String, dynamic> json) => ServingInfo(
    amount: (json['amount'] ?? 1).toDouble(),
    unit: json['unit'] ?? 'serving',
    grams: (json['grams'] ?? 100).toDouble(),
    description: json['description'],
  );
}

/// Recipe from API
class GlobalRecipe {
  final String id;
  final String title;
  final String? localTitle;
  final String source;
  final String? sourceUrl;
  final String? imageUrl;
  final int servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? totalTimeMinutes;
  final String? cuisine;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final NutritionInfo nutritionPerServing;
  final double? pricePerServing;
  final String? currency;
  final List<String> dietLabels;
  final List<String> healthLabels;
  final List<String> allergens;
  final double? healthScore;
  final String? difficulty;
  final Map<String, dynamic> raw;

  GlobalRecipe({
    required this.id,
    required this.title,
    this.localTitle,
    required this.source,
    this.sourceUrl,
    this.imageUrl,
    this.servings = 4,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.totalTimeMinutes,
    this.cuisine,
    this.ingredients = const [],
    this.instructions = const [],
    required this.nutritionPerServing,
    this.pricePerServing,
    this.currency,
    this.dietLabels = const [],
    this.healthLabels = const [],
    this.allergens = const [],
    this.healthScore,
    this.difficulty,
    this.raw = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'localTitle': localTitle,
    'source': source,
    'sourceUrl': sourceUrl,
    'imageUrl': imageUrl,
    'servings': servings,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'totalTimeMinutes': totalTimeMinutes,
    'cuisine': cuisine,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'instructions': instructions,
    'nutritionPerServing': nutritionPerServing.toJson(),
    'pricePerServing': pricePerServing,
    'currency': currency,
    'dietLabels': dietLabels,
    'healthLabels': healthLabels,
    'allergens': allergens,
    'healthScore': healthScore,
    'difficulty': difficulty,
  };

  factory GlobalRecipe.fromJson(Map<String, dynamic> json) => GlobalRecipe(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    localTitle: json['localTitle'],
    source: json['source'] ?? 'unknown',
    sourceUrl: json['sourceUrl'],
    imageUrl: json['imageUrl'],
    servings: json['servings'] ?? 4,
    prepTimeMinutes: json['prepTimeMinutes'],
    cookTimeMinutes: json['cookTimeMinutes'],
    totalTimeMinutes: json['totalTimeMinutes'],
    cuisine: json['cuisine'],
    ingredients:
        (json['ingredients'] as List<dynamic>?)
            ?.map((i) => RecipeIngredient.fromJson(i))
            .toList() ??
        [],
    instructions: List<String>.from(json['instructions'] ?? []),
    nutritionPerServing: NutritionInfo.fromJson(
      json['nutritionPerServing'] ?? {},
    ),
    pricePerServing: json['pricePerServing']?.toDouble(),
    currency: json['currency'],
    dietLabels: List<String>.from(json['dietLabels'] ?? []),
    healthLabels: List<String>.from(json['healthLabels'] ?? []),
    allergens: List<String>.from(json['allergens'] ?? []),
    healthScore: json['healthScore']?.toDouble(),
    difficulty: json['difficulty'],
  );
}

/// Recipe ingredient
class RecipeIngredient {
  final String name;
  final double amount;
  final String unit;
  final String? localName;
  final NutritionInfo? nutrition;

  RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.localName,
    this.nutrition,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'localName': localName,
    'nutrition': nutrition?.toJson(),
  };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        name: json['name'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        unit: json['unit'] ?? '',
        localName: json['localName'],
        nutrition: json['nutrition'] != null
            ? NutritionInfo.fromJson(json['nutrition'])
            : null,
      );
}

/// Search parameters for API queries
class FoodSearchParams {
  final String query;
  final String? cuisine;
  final String? diet;
  final String? region;
  final int? maxCalories;
  final int? minProtein;
  final int? maxCarbs;
  final int? maxReadyTime;
  final double? maxPrice;
  final List<String> excludeIngredients;
  final List<String> includeIngredients;
  final List<String> healthLabels;
  final int limit;
  final int offset;

  FoodSearchParams({
    required this.query,
    this.cuisine,
    this.diet,
    this.region,
    this.maxCalories,
    this.minProtein,
    this.maxCarbs,
    this.maxReadyTime,
    this.maxPrice,
    this.excludeIngredients = const [],
    this.includeIngredients = const [],
    this.healthLabels = const [],
    this.limit = 20,
    this.offset = 0,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'cuisine': cuisine,
    'diet': diet,
    'region': region,
    'maxCalories': maxCalories,
    'minProtein': minProtein,
    'maxCarbs': maxCarbs,
    'maxReadyTime': maxReadyTime,
    'maxPrice': maxPrice,
    'excludeIngredients': excludeIngredients,
    'includeIngredients': includeIngredients,
    'healthLabels': healthLabels,
    'limit': limit,
    'offset': offset,
  };
}

/// API search result wrapper
class FoodSearchResult {
  final bool success;
  final List<GlobalFoodItem> foods;
  final List<GlobalRecipe> recipes;
  final String source;
  final int totalResults;
  final String? error;
  final Map<String, dynamic>? metadata;

  FoodSearchResult({
    required this.success,
    this.foods = const [],
    this.recipes = const [],
    required this.source,
    this.totalResults = 0,
    this.error,
    this.metadata,
  });

  factory FoodSearchResult.success({
    required List<GlobalFoodItem> foods,
    List<GlobalRecipe> recipes = const [],
    required String source,
    int? totalResults,
    Map<String, dynamic>? metadata,
  }) => FoodSearchResult(
    success: true,
    foods: foods,
    recipes: recipes,
    source: source,
    totalResults: totalResults ?? foods.length,
    metadata: metadata,
  );

  factory FoodSearchResult.failure(String error, String source) =>
      FoodSearchResult(success: false, source: source, error: error);
}

// ============================================
// MAIN SERVICE
// ============================================

/// Principal-grade multi-source food API orchestrator
/// Implements search-then-reason architecture for Gemini integration
class GlobalFoodAPIService {
  static final GlobalFoodAPIService _instance =
      GlobalFoodAPIService._internal();
  factory GlobalFoodAPIService() => _instance;
  GlobalFoodAPIService._internal();

  // API Configuration
  late final String _spoonacularApiKey;
  late final String _edamamAppId;
  late final String _edamamAppKey;
  late final String _fatSecretConsumerKey;
  late final String _fatSecretConsumerSecret;
  String? _fatSecretAccessToken;
  DateTime? _fatSecretTokenExpiry;

  bool _isInitialized = false;

  // Circuit breakers for each API
  final Map<String, _CircuitBreaker> _circuitBreakers = {};

  // Response cache (LRU)
  final Map<String, _CachedResponse> _cache = {};
  static const int _maxCacheSize = 500;
  static const Duration _cacheDuration = Duration(hours: 2);

  /// Initialize the service with API credentials
  Future<void> initialize() async {
    if (_isInitialized) return;

    _spoonacularApiKey = EnvConfig.get('SPOONACULAR_API_KEY');
    _edamamAppId = EnvConfig.get('EDAMAM_APP_ID');
    _edamamAppKey = EnvConfig.get('EDAMAM_APP_KEY');
    _fatSecretConsumerKey = EnvConfig.get('FATSECRET_CONSUMER_KEY');
    _fatSecretConsumerSecret = EnvConfig.get('FATSECRET_CONSUMER_SECRET');

    // Initialize circuit breakers
    _circuitBreakers['spoonacular'] = _CircuitBreaker('spoonacular');
    _circuitBreakers['edamam'] = _CircuitBreaker('edamam');
    _circuitBreakers['fatsecret'] = _CircuitBreaker('fatsecret');
    _circuitBreakers['openfoodfacts'] = _CircuitBreaker('openfoodfacts');

    _isInitialized = true;

    // Log API configuration status
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🌍 GLOBAL FOOD API SERVICE - INITIALIZATION');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint(
      '   Spoonacular: ${_spoonacularApiKey.isNotEmpty ? '✅ Configured' : '❌ Missing API Key'}',
    );
    debugPrint(
      '   Edamam: ${_edamamAppId.isNotEmpty && _edamamAppKey.isNotEmpty ? '✅ Configured' : '❌ Missing API Key'}',
    );
    debugPrint(
      '   FatSecret: ${_fatSecretConsumerKey.isNotEmpty && _fatSecretConsumerSecret.isNotEmpty ? '✅ Configured' : '⚠️ Not Configured (Optional - Using Other APIs)'}',
    );
    debugPrint('   OpenFoodFacts: ✅ Always Available (Free API)');
    debugPrint('═══════════════════════════════════════════════════════════');

    final configuredApis = <String>[];
    if (_spoonacularApiKey.isNotEmpty) configuredApis.add('Spoonacular');
    if (_edamamAppId.isNotEmpty && _edamamAppKey.isNotEmpty) configuredApis.add('Edamam');
    if (_fatSecretConsumerKey.isNotEmpty && _fatSecretConsumerSecret.isNotEmpty) configuredApis.add('FatSecret');
    configuredApis.add('OpenFoodFacts');

    if (configuredApis.length == 1) {
      debugPrint('⚠️ INFO: Only OpenFoodFacts is available.');
      debugPrint('   Consider adding Spoonacular or Edamam API keys for better results.');
    } else {
      debugPrint('✅ Active APIs: ${configuredApis.join(', ')}');
    }
  }

  // ============================================
  // UNIFIED SEARCH API
  // ============================================

  /// Multi-source search with intelligent fallback
  /// Returns foods from the best available source based on query
  Future<FoodSearchResult> searchFoods(FoodSearchParams params) async {
    if (!_isInitialized) await initialize();

    final cacheKey = _generateCacheKey('foods', params);
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    // Determine best API based on query characteristics
    final apis = _selectAPIsForQuery(params);

    for (final api in apis) {
      if (_circuitBreakers[api]?.isOpen ?? false) continue;

      try {
        FoodSearchResult? result;

        switch (api) {
          case 'edamam':
            result = await _searchEdamam(params);
            break;
          case 'spoonacular':
            result = await _searchSpoonacular(params);
            break;
          case 'fatsecret':
            result = await _searchFatSecret(params);
            break;
          case 'openfoodfacts':
            result = await _searchOpenFoodFacts(params);
            break;
        }

        if (result != null && result.success && result.foods.isNotEmpty) {
          _addToCache(cacheKey, result);
          _circuitBreakers[api]?.recordSuccess();
          return result;
        }
      } catch (e) {
        debugPrint('❌ $api search failed: $e');
        _circuitBreakers[api]?.recordFailure();
      }
    }

    return FoodSearchResult.failure(
      'All food APIs failed or returned no results',
      'multi-source',
    );
  }

  /// Search specifically for recipes
  Future<FoodSearchResult> searchRecipes(FoodSearchParams params) async {
    if (!_isInitialized) await initialize();

    final cacheKey = _generateCacheKey('recipes', params);
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    // Spoonacular is best for recipes
    if (_spoonacularApiKey.isNotEmpty &&
        !(_circuitBreakers['spoonacular']?.isOpen ?? false)) {
      try {
        final result = await _searchSpoonacularRecipes(params);
        if (result.success) {
          _addToCache(cacheKey, result);
          _circuitBreakers['spoonacular']?.recordSuccess();
          return result;
        }
      } catch (e) {
        debugPrint('❌ Spoonacular recipe search failed: $e');
        _circuitBreakers['spoonacular']?.recordFailure();
      }
    }

    // Fallback to Edamam recipes
    if (_edamamAppId.isNotEmpty &&
        !(_circuitBreakers['edamam']?.isOpen ?? false)) {
      try {
        final result = await _searchEdamamRecipes(params);
        if (result.success) {
          _addToCache(cacheKey, result);
          _circuitBreakers['edamam']?.recordSuccess();
          return result;
        }
      } catch (e) {
        debugPrint('❌ Edamam recipe search failed: $e');
        _circuitBreakers['edamam']?.recordFailure();
      }
    }

    return FoodSearchResult.failure('Recipe search failed', 'multi-source');
  }

  /// Generate a complete meal plan using real recipe data
  Future<List<GlobalRecipe>> generateMealPlanRecipes({
    required String cuisine,
    required String diet,
    required int days,
    int mealsPerDay = 3,
    int? maxCaloriesPerMeal,
    int? maxReadyTime,
    List<String> excludeIngredients = const [],
    List<String> healthLabels = const [],
  }) async {
    if (!_isInitialized) await initialize();

    final recipes = <GlobalRecipe>[];
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final usedRecipeIds = <String>{};

    for (int day = 0; day < days; day++) {
      for (
        int meal = 0;
        meal < mealsPerDay && meal < mealTypes.length;
        meal++
      ) {
        final mealType = mealTypes[meal];

        final params = FoodSearchParams(
          query: '$cuisine $mealType',
          cuisine: cuisine,
          diet: diet,
          maxCalories: maxCaloriesPerMeal,
          maxReadyTime: maxReadyTime,
          excludeIngredients: excludeIngredients,
          healthLabels: healthLabels,
          limit: 10,
        );

        final result = await searchRecipes(params);

        if (result.success && result.recipes.isNotEmpty) {
          // Find a recipe not yet used
          for (final recipe in result.recipes) {
            if (!usedRecipeIds.contains(recipe.id)) {
              recipes.add(recipe);
              usedRecipeIds.add(recipe.id);
              break;
            }
          }
        }
      }
    }

    return recipes;
  }

  // ============================================
  // SPOONACULAR API
  // ============================================

  Future<FoodSearchResult> _searchSpoonacular(FoodSearchParams params) async {
    if (_spoonacularApiKey.isEmpty) {
      return FoodSearchResult.failure(
        'Spoonacular API key not configured',
        'spoonacular',
      );
    }

    final queryParams = <String, String>{
      'apiKey': _spoonacularApiKey,
      'query': params.query,
      'number': params.limit.toString(),
      'offset': params.offset.toString(),
    };

    if (params.cuisine != null) queryParams['cuisine'] = params.cuisine!;
    if (params.diet != null) queryParams['diet'] = params.diet!;
    if (params.maxCalories != null)
      queryParams['maxCalories'] = params.maxCalories.toString();
    if (params.minProtein != null)
      queryParams['minProtein'] = params.minProtein.toString();

    final uri = Uri.parse(
      'https://api.spoonacular.com/food/ingredients/search',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final foods = <GlobalFoodItem>[];

      for (final item in data['results'] ?? []) {
        foods.add(
          GlobalFoodItem(
            id: 'spoon_${item['id']}',
            name: item['name'] ?? '',
            source: 'spoonacular',
            nutrition:
                NutritionInfo(), // Would need additional API call for full nutrition
            serving: ServingInfo(),
            imageUrl: item['image'] != null
                ? 'https://spoonacular.com/cdn/ingredients_250x250/${item['image']}'
                : null,
            raw: item,
          ),
        );
      }

      return FoodSearchResult.success(
        foods: foods,
        source: 'spoonacular',
        totalResults: data['totalResults'] ?? foods.length,
      );
    }

    return FoodSearchResult.failure(
      'Spoonacular API error: ${response.statusCode}',
      'spoonacular',
    );
  }

  Future<FoodSearchResult> _searchSpoonacularRecipes(
    FoodSearchParams params,
  ) async {
    if (_spoonacularApiKey.isEmpty) {
      return FoodSearchResult.failure(
        'Spoonacular API key not configured',
        'spoonacular',
      );
    }

    final queryParams = <String, String>{
      'apiKey': _spoonacularApiKey,
      'query': params.query,
      'number': params.limit.toString(),
      'offset': params.offset.toString(),
      'addRecipeNutrition': 'true',
      'fillIngredients': 'true',
      'addRecipeInstructions': 'true',
    };

    if (params.cuisine != null) queryParams['cuisine'] = params.cuisine!;
    if (params.diet != null) queryParams['diet'] = params.diet!;
    if (params.maxCalories != null)
      queryParams['maxCalories'] = params.maxCalories.toString();
    if (params.maxReadyTime != null)
      queryParams['maxReadyTime'] = params.maxReadyTime.toString();
    if (params.excludeIngredients.isNotEmpty) {
      queryParams['excludeIngredients'] = params.excludeIngredients.join(',');
    }

    final uri = Uri.parse(
      'https://api.spoonacular.com/recipes/complexSearch',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final recipes = <GlobalRecipe>[];

      for (final item in data['results'] ?? []) {
        final nutrition = item['nutrition'];
        final nutrients = nutrition?['nutrients'] as List<dynamic>? ?? [];

        double getNutrient(String name) {
          final n = nutrients.firstWhere(
            (n) => n['name'] == name,
            orElse: () => {'amount': 0},
          );
          return (n['amount'] ?? 0).toDouble();
        }

        final ingredients = <RecipeIngredient>[];
        for (final ing in item['extendedIngredients'] ?? []) {
          ingredients.add(
            RecipeIngredient(
              name: ing['name'] ?? '',
              amount: (ing['amount'] ?? 0).toDouble(),
              unit: ing['unit'] ?? '',
            ),
          );
        }

        final instructions = <String>[];
        final analyzedInstructions =
            item['analyzedInstructions'] as List<dynamic>? ?? [];
        for (final instruction in analyzedInstructions) {
          for (final step in instruction['steps'] ?? []) {
            instructions.add(step['step'] ?? '');
          }
        }

        recipes.add(
          GlobalRecipe(
            id: 'spoon_${item['id']}',
            title: item['title'] ?? '',
            source: 'spoonacular',
            sourceUrl: item['sourceUrl'],
            imageUrl: item['image'],
            servings: item['servings'] ?? 4,
            prepTimeMinutes: item['preparationMinutes'],
            cookTimeMinutes: item['cookingMinutes'],
            totalTimeMinutes: item['readyInMinutes'],
            cuisine: params.cuisine,
            ingredients: ingredients,
            instructions: instructions,
            nutritionPerServing: NutritionInfo(
              calories: getNutrient('Calories'),
              protein: getNutrient('Protein'),
              carbs: getNutrient('Carbohydrates'),
              fat: getNutrient('Fat'),
              fiber: getNutrient('Fiber'),
              sugar: getNutrient('Sugar'),
              sodium: getNutrient('Sodium'),
            ),
            pricePerServing: item['pricePerServing']?.toDouble(),
            currency: 'USD',
            dietLabels: List<String>.from(item['diets'] ?? []),
            healthScore: item['healthScore']?.toDouble(),
            raw: item,
          ),
        );
      }

      return FoodSearchResult.success(
        foods: [],
        recipes: recipes,
        source: 'spoonacular',
        totalResults: data['totalResults'] ?? recipes.length,
      );
    }

    return FoodSearchResult.failure(
      'Spoonacular recipe API error: ${response.statusCode}',
      'spoonacular',
    );
  }

  // ============================================
  // EDAMAM API
  // ============================================

  Future<FoodSearchResult> _searchEdamam(FoodSearchParams params) async {
    if (_edamamAppId.isEmpty || _edamamAppKey.isEmpty) {
      return FoodSearchResult.failure('Edamam API not configured', 'edamam');
    }

    final queryParams = <String, String>{
      'app_id': _edamamAppId,
      'app_key': _edamamAppKey,
      'ingr': params.query,
      'nutrition-type': 'cooking',
    };

    final uri = Uri.parse(
      'https://api.edamam.com/api/nutrition-data',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final totalNutrients = data['totalNutrients'] ?? {};

      double getNutrient(String key) {
        return (totalNutrients[key]?['quantity'] ?? 0).toDouble();
      }

      final food = GlobalFoodItem(
        id: 'edamam_${params.query.hashCode}',
        name: params.query,
        source: 'edamam',
        nutrition: NutritionInfo(
          calories: getNutrient('ENERC_KCAL'),
          protein: getNutrient('PROCNT'),
          carbs: getNutrient('CHOCDF'),
          fat: getNutrient('FAT'),
          fiber: getNutrient('FIBTG'),
          sugar: getNutrient('SUGAR'),
          sodium: getNutrient('NA'),
          saturatedFat: getNutrient('FASAT'),
          cholesterol: getNutrient('CHOLE'),
          potassium: getNutrient('K'),
          calcium: getNutrient('CA'),
          iron: getNutrient('FE'),
          vitaminA: getNutrient('VITA_RAE'),
          vitaminC: getNutrient('VITC'),
          vitaminD: getNutrient('VITD'),
        ),
        serving: ServingInfo(grams: (data['totalWeight'] ?? 100).toDouble()),
        dietLabels: List<String>.from(data['dietLabels'] ?? []),
        healthLabels: List<String>.from(data['healthLabels'] ?? []),
        raw: data,
      );

      return FoodSearchResult.success(foods: [food], source: 'edamam');
    }

    return FoodSearchResult.failure(
      'Edamam API error: ${response.statusCode}',
      'edamam',
    );
  }

  Future<FoodSearchResult> _searchEdamamRecipes(FoodSearchParams params) async {
    if (_edamamAppId.isEmpty || _edamamAppKey.isEmpty) {
      return FoodSearchResult.failure('Edamam API not configured', 'edamam');
    }

    final queryParams = <String, String>{
      'app_id': _edamamAppId,
      'app_key': _edamamAppKey,
      'q': params.query,
      'type': 'public',
      'from': params.offset.toString(),
      'to': (params.offset + params.limit).toString(),
    };

    if (params.diet != null) queryParams['diet'] = params.diet!;
    if (params.cuisine != null) queryParams['cuisineType'] = params.cuisine!;
    if (params.maxCalories != null)
      queryParams['calories'] = '0-${params.maxCalories}';
    if (params.maxReadyTime != null)
      queryParams['time'] = '0-${params.maxReadyTime}';
    if (params.healthLabels.isNotEmpty) {
      queryParams['health'] = params.healthLabels.first;
    }

    final uri = Uri.parse(
      'https://api.edamam.com/api/recipes/v2',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final recipes = <GlobalRecipe>[];

      for (final hit in data['hits'] ?? []) {
        final recipe = hit['recipe'];
        final totalNutrients = recipe['totalNutrients'] ?? {};

        double getNutrient(String key) {
          return (totalNutrients[key]?['quantity'] ?? 0).toDouble();
        }

        final servings = recipe['yield']?.toInt() ?? 4;

        final ingredients = <RecipeIngredient>[];
        for (final ing in recipe['ingredients'] ?? []) {
          ingredients.add(
            RecipeIngredient(
              name: ing['food'] ?? '',
              amount: (ing['quantity'] ?? 0).toDouble(),
              unit: ing['measure'] ?? '',
            ),
          );
        }

        recipes.add(
          GlobalRecipe(
            id: 'edamam_${recipe['uri']?.hashCode ?? DateTime.now().millisecondsSinceEpoch}',
            title: recipe['label'] ?? '',
            source: 'edamam',
            sourceUrl: recipe['url'],
            imageUrl: recipe['image'],
            servings: servings,
            totalTimeMinutes: recipe['totalTime']?.toInt(),
            cuisine: (recipe['cuisineType'] as List<dynamic>?)?.firstOrNull,
            ingredients: ingredients,
            instructions: [], // Edamam doesn't provide instructions
            nutritionPerServing: NutritionInfo(
              calories: getNutrient('ENERC_KCAL') / servings,
              protein: getNutrient('PROCNT') / servings,
              carbs: getNutrient('CHOCDF') / servings,
              fat: getNutrient('FAT') / servings,
              fiber: getNutrient('FIBTG') / servings,
              sugar: getNutrient('SUGAR') / servings,
              sodium: getNutrient('NA') / servings,
            ),
            dietLabels: List<String>.from(recipe['dietLabels'] ?? []),
            healthLabels: List<String>.from(recipe['healthLabels'] ?? []),
            allergens: List<String>.from(recipe['cautions'] ?? []),
            raw: recipe,
          ),
        );
      }

      return FoodSearchResult.success(
        foods: [],
        recipes: recipes,
        source: 'edamam',
        totalResults: data['count'] ?? recipes.length,
      );
    }

    return FoodSearchResult.failure(
      'Edamam recipe API error: ${response.statusCode}',
      'edamam',
    );
  }

  // ============================================
  // FATSECRET API (OAuth 2.0)
  // ============================================

  Future<FoodSearchResult> _searchFatSecret(FoodSearchParams params) async {
    if (_fatSecretConsumerKey.isEmpty || _fatSecretConsumerSecret.isEmpty) {
      return FoodSearchResult.failure(
        'FatSecret API not configured',
        'fatsecret',
      );
    }

    // Get access token if needed
    if (_fatSecretAccessToken == null ||
        _fatSecretTokenExpiry == null ||
        DateTime.now().isAfter(_fatSecretTokenExpiry!)) {
      final tokenObtained = await _getFatSecretAccessToken();
      if (!tokenObtained) {
        return FoodSearchResult.failure(
          'FatSecret authentication failed',
          'fatsecret',
        );
      }
    }

    final body = {
      'method': 'foods.search',
      'search_expression': params.query,
      'format': 'json',
      'max_results': params.limit.toString(),
      'page_number': (params.offset ~/ params.limit).toString(),
    };

    // Add region for local foods
    if (params.region != null) {
      body['region'] = params.region!;
    }

    final response = await http
        .post(
          Uri.parse('https://platform.fatsecret.com/rest/server.api'),
          headers: {
            'Authorization': 'Bearer $_fatSecretAccessToken',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final foods = <GlobalFoodItem>[];

      final foodsData = data['foods']?['food'];
      if (foodsData != null) {
        final foodList = foodsData is List ? foodsData : [foodsData];

        for (final item in foodList) {
          // Parse nutrition from description string (e.g., "Calories: 150kcal | Fat: 8g | ...")
          final nutritionDesc = item['food_description'] ?? '';
          final nutrition = _parseFatSecretNutrition(nutritionDesc);

          foods.add(
            GlobalFoodItem(
              id: 'fatsecret_${item['food_id']}',
              name: item['food_name'] ?? '',
              brand: item['brand_name'],
              source: 'fatsecret',
              nutrition: nutrition,
              serving: ServingInfo(description: item['serving_description']),
              raw: item,
            ),
          );
        }
      }

      return FoodSearchResult.success(
        foods: foods,
        source: 'fatsecret',
        totalResults:
            int.tryParse(data['foods']?['total_results']?.toString() ?? '0') ??
            foods.length,
        metadata: {'region': params.region},
      );
    }

    return FoodSearchResult.failure(
      'FatSecret API error: ${response.statusCode}',
      'fatsecret',
    );
  }

  Future<bool> _getFatSecretAccessToken() async {
    try {
      final credentials = base64Encode(
        utf8.encode('$_fatSecretConsumerKey:$_fatSecretConsumerSecret'),
      );

      final response = await http
          .post(
            Uri.parse('https://oauth.fatsecret.com/connect/token'),
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: 'grant_type=client_credentials&scope=basic',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _fatSecretAccessToken = data['access_token'];
        final expiresIn = data['expires_in'] ?? 86400;
        _fatSecretTokenExpiry = DateTime.now().add(
          Duration(seconds: expiresIn - 60),
        );
        debugPrint('🔐 FatSecret access token obtained');
        return true;
      }

      debugPrint('❌ FatSecret token error: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ FatSecret auth error: $e');
      return false;
    }
  }

  NutritionInfo _parseFatSecretNutrition(String description) {
    // Parse format: "Per 100g - Calories: 150kcal | Fat: 8.00g | Carbs: 15.00g | Protein: 5.00g"
    double calories = 0, fat = 0, carbs = 0, protein = 0;

    final calMatch = RegExp(r'Calories:\s*([\d.]+)').firstMatch(description);
    final fatMatch = RegExp(r'Fat:\s*([\d.]+)').firstMatch(description);
    final carbMatch = RegExp(r'Carbs:\s*([\d.]+)').firstMatch(description);
    final protMatch = RegExp(r'Protein:\s*([\d.]+)').firstMatch(description);

    if (calMatch != null) calories = double.tryParse(calMatch.group(1)!) ?? 0;
    if (fatMatch != null) fat = double.tryParse(fatMatch.group(1)!) ?? 0;
    if (carbMatch != null) carbs = double.tryParse(carbMatch.group(1)!) ?? 0;
    if (protMatch != null) protein = double.tryParse(protMatch.group(1)!) ?? 0;

    return NutritionInfo(
      calories: calories,
      fat: fat,
      carbs: carbs,
      protein: protein,
    );
  }

  // ============================================
  // OPEN FOOD FACTS API
  // ============================================

  Future<FoodSearchResult> _searchOpenFoodFacts(FoodSearchParams params) async {
    final queryParams = <String, String>{
      'search_terms': params.query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': params.limit.toString(),
      'page': ((params.offset ~/ params.limit) + 1).toString(),
    };

    final uri = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl',
    ).replace(queryParameters: queryParams);

    final response = await http
        .get(
          uri,
          headers: {'User-Agent': 'Wellor-Pro/3.0.0 (clinical-nutrition-ai)'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final foods = <GlobalFoodItem>[];

      for (final product in data['products'] ?? []) {
        final nutriments = product['nutriments'] ?? {};

        foods.add(
          GlobalFoodItem(
            id: 'off_${product['code'] ?? product['_id']}',
            name:
                product['product_name'] ?? product['generic_name'] ?? 'Unknown',
            brand: product['brands'],
            source: 'openfoodfacts',
            imageUrl: product['image_url'],
            nutrition: NutritionInfo(
              calories:
                  (nutriments['energy-kcal_100g'] ??
                          nutriments['energy-kcal'] ??
                          0)
                      .toDouble(),
              protein: (nutriments['proteins_100g'] ?? 0).toDouble(),
              carbs: (nutriments['carbohydrates_100g'] ?? 0).toDouble(),
              fat: (nutriments['fat_100g'] ?? 0).toDouble(),
              fiber: (nutriments['fiber_100g'] ?? 0).toDouble(),
              sugar: (nutriments['sugars_100g'] ?? 0).toDouble(),
              sodium:
                  (nutriments['sodium_100g'] ?? 0).toDouble() *
                  1000, // Convert to mg
              saturatedFat: (nutriments['saturated-fat_100g'] ?? 0).toDouble(),
            ),
            serving: ServingInfo(
              grams:
                  (product['serving_size']?.toString()?.replaceAll(
                            RegExp(r'[^0-9.]'),
                            '',
                          ) ??
                          '100')
                      .isEmpty
                  ? 100
                  : double.tryParse(
                          product['serving_size']?.toString().replaceAll(
                                RegExp(r'[^0-9.]'),
                                '',
                              ) ??
                              '100',
                        ) ??
                        100,
              description: product['serving_size'],
            ),
            ingredients: (product['ingredients_text'] ?? '')
                .toString()
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
            allergens: List<String>.from(product['allergens_tags'] ?? []),
            raw: product,
          ),
        );
      }

      return FoodSearchResult.success(
        foods: foods,
        source: 'openfoodfacts',
        totalResults: data['count'] ?? foods.length,
      );
    }

    return FoodSearchResult.failure(
      'Open Food Facts API error: ${response.statusCode}',
      'openfoodfacts',
    );
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Select best APIs based on query type
  List<String> _selectAPIsForQuery(FoodSearchParams params) {
    final apis = <String>[];

    // Natural language parsing → Edamam first
    if (params.query.contains(' ') && params.query.split(' ').length > 2) {
      if (_edamamAppId.isNotEmpty && _edamamAppKey.isNotEmpty) {
        apis.add('edamam');
      }
    }

    // Regional/local foods → FatSecret first (only if configured)
    if ((params.region != null || params.cuisine != null) && 
        _fatSecretConsumerKey.isNotEmpty && _fatSecretConsumerSecret.isNotEmpty) {
      apis.add('fatsecret');
    }

    // Packaged/branded foods → Open Food Facts first
    if (params.query.toLowerCase().contains('brand') ||
        RegExp(r'\d{8,13}').hasMatch(params.query)) {
      apis.add('openfoodfacts');
    }

    // Default order for general queries - only add configured APIs
    if (!apis.contains('spoonacular') && _spoonacularApiKey.isNotEmpty) {
      apis.add('spoonacular');
    }
    if (!apis.contains('edamam') && _edamamAppId.isNotEmpty && _edamamAppKey.isNotEmpty) {
      apis.add('edamam');
    }
    // Skip FatSecret if not configured
    if (!apis.contains('fatsecret') && 
        _fatSecretConsumerKey.isNotEmpty && _fatSecretConsumerSecret.isNotEmpty) {
      apis.add('fatsecret');
    }
    if (!apis.contains('openfoodfacts')) {
      apis.add('openfoodfacts'); // Always available
    }

    return apis;
  }

  String _generateCacheKey(String type, FoodSearchParams params) {
    return '$type:${params.query}:${params.cuisine}:${params.diet}:${params.region}:${params.limit}:${params.offset}';
  }

  FoodSearchResult? _getFromCache(String key) {
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      debugPrint('📦 Cache hit for: $key');
      return cached.result;
    }
    _cache.remove(key);
    return null;
  }

  void _addToCache(String key, FoodSearchResult result) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CachedResponse(
      result: result,
      expiry: DateTime.now().add(_cacheDuration),
    );
  }

  /// Get API status for debugging
  Map<String, dynamic> getAPIStatus() {
    return {
      'spoonacular': {
        'configured': _spoonacularApiKey.isNotEmpty,
        'circuitOpen': _circuitBreakers['spoonacular']?.isOpen ?? false,
      },
      'edamam': {
        'configured': _edamamAppId.isNotEmpty && _edamamAppKey.isNotEmpty,
        'circuitOpen': _circuitBreakers['edamam']?.isOpen ?? false,
      },
      'fatsecret': {
        'configured': _fatSecretConsumerKey.isNotEmpty,
        'circuitOpen': _circuitBreakers['fatsecret']?.isOpen ?? false,
        'hasToken': _fatSecretAccessToken != null,
      },
      'openfoodfacts': {
        'configured': true, // No API key needed
        'circuitOpen': _circuitBreakers['openfoodfacts']?.isOpen ?? false,
      },
      'cacheSize': _cache.length,
    };
  }
}

// ============================================
// HELPER CLASSES
// ============================================

class _CircuitBreaker {
  final String name;
  int _failureCount = 0;
  DateTime? _openedAt;
  static const int _threshold = 3;
  static const Duration _resetDuration = Duration(minutes: 1);

  _CircuitBreaker(this.name);

  bool get isOpen {
    if (_openedAt == null) return false;
    if (DateTime.now().difference(_openedAt!) > _resetDuration) {
      _reset();
      return false;
    }
    return true;
  }

  void recordSuccess() {
    _failureCount = 0;
    _openedAt = null;
  }

  void recordFailure() {
    _failureCount++;
    if (_failureCount >= _threshold) {
      _openedAt = DateTime.now();
      debugPrint('🚨 Circuit breaker OPEN for $name');
    }
  }

  void _reset() {
    _failureCount = 0;
    _openedAt = null;
    debugPrint('✅ Circuit breaker RESET for $name');
  }
}

class _CachedResponse {
  final FoodSearchResult result;
  final DateTime expiry;

  _CachedResponse({required this.result, required this.expiry});
}
