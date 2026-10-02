// lib/services/gemini_function_calling_service.dart
// PRINCIPAL ENGINEER GRADE: Gemini Function Calling for Food API Integration
// Implements search-then-reason architecture with tool definitions

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'global_food_api_service.dart';

// ============================================
// TOOL DEFINITIONS
// ============================================

/// Tool definition schema for Gemini
class GeminiTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const GeminiTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

/// Function call from Gemini
class GeminiFunctionCall {
  final String name;
  final Map<String, dynamic> arguments;

  GeminiFunctionCall({required this.name, required this.arguments});

  factory GeminiFunctionCall.fromJson(Map<String, dynamic> json) {
    return GeminiFunctionCall(
      name: json['name'] ?? '',
      arguments: json['args'] is String
          ? jsonDecode(json['args'])
          : Map<String, dynamic>.from(json['args'] ?? {}),
    );
  }
}

/// Response from function execution
class FunctionCallResult {
  final String functionName;
  final bool success;
  final dynamic data;
  final String? error;

  FunctionCallResult({
    required this.functionName,
    required this.success,
    this.data,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'function_name': functionName,
    'success': success,
    'data': data,
    'error': error,
  };
}

// ============================================
// TOOL DEFINITIONS FOR FOOD APIs
// ============================================

/// All available tools for Gemini to call
class FoodAPITools {
  static const searchRecipes = GeminiTool(
    name: 'search_recipes',
    description:
        '''Search for recipes from global food databases (Spoonacular, Edamam). 
Use this to find real recipes with accurate nutrition data, cooking times, and ingredients.
Best for: meal planning, finding specific dishes, cuisine-based searches.''',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description':
              'Search query for recipes (e.g., "Nigerian jollof rice", "low carb breakfast")',
        },
        'cuisine': {
          'type': 'string',
          'description':
              'Cuisine type (e.g., "Nigerian", "Kenyan", "Mexican", "Italian", "Indian")',
        },
        'diet': {
          'type': 'string',
          'description':
              'Diet restriction (e.g., "vegetarian", "vegan", "keto", "paleo", "gluten-free")',
        },
        'max_calories': {
          'type': 'integer',
          'description': 'Maximum calories per serving',
        },
        'max_ready_time': {
          'type': 'integer',
          'description': 'Maximum total preparation + cooking time in minutes',
        },
        'exclude_ingredients': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'Ingredients to exclude (for allergies or preferences)',
        },
        'health_labels': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'Health labels (e.g., "diabetes-friendly", "low-sodium", "heart-healthy")',
        },
        'limit': {
          'type': 'integer',
          'description': 'Number of results to return (default: 10, max: 50)',
        },
      },
      'required': ['query'],
    },
  );

  static const searchFoods = GeminiTool(
    name: 'search_foods',
    description:
        '''Search for individual food items and their nutrition information.
Sources: USDA, FatSecret (50+ countries), Open Food Facts (2.8M+ products).
Best for: looking up nutrition facts, finding local foods, branded products.''',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description':
              'Food name to search (e.g., "ugali", "plantain", "chicken breast")',
        },
        'region': {
          'type': 'string',
          'description':
              'Region code for local foods (e.g., "KE" for Kenya, "NG" for Nigeria, "BR" for Brazil)',
        },
        'brand': {
          'type': 'string',
          'description': 'Brand name for packaged foods',
        },
        'limit': {
          'type': 'integer',
          'description': 'Number of results to return (default: 10)',
        },
      },
      'required': ['query'],
    },
  );

  static const getNutritionAnalysis = GeminiTool(
    name: 'get_nutrition_analysis',
    description:
        '''Analyze nutrition content of a meal or ingredient list using Edamam's NLP parser.
Can parse natural language like "1 bowl of Kenyan Githeri with 2 eggs" into detailed nutrition.
Best for: calculating total meal nutrition, analyzing user-described meals.''',
    parameters: {
      'type': 'object',
      'properties': {
        'ingredients': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'List of ingredients with quantities (e.g., ["200g rice", "150g chicken breast", "1 cup vegetables"])',
        },
        'meal_description': {
          'type': 'string',
          'description':
              'Natural language meal description (e.g., "1 bowl of jollof rice with fried plantain")',
        },
      },
      'required': [],
    },
  );

  static const generateMealPlan = GeminiTool(
    name: 'generate_meal_plan',
    description:
        '''Generate a complete meal plan using real recipes from databases.
Returns actual recipes with accurate nutrition, cooking instructions, and ingredient lists.
Use after understanding user requirements to create an actionable meal plan.''',
    parameters: {
      'type': 'object',
      'properties': {
        'cuisine': {
          'type': 'string',
          'description':
              'Primary cuisine (e.g., "Nigerian", "Kenyan", "Mediterranean")',
        },
        'diet': {
          'type': 'string',
          'description':
              'Diet type (e.g., "balanced", "low-carb", "vegetarian")',
        },
        'days': {
          'type': 'integer',
          'description': 'Number of days to plan (1-14)',
        },
        'meals_per_day': {
          'type': 'integer',
          'description': 'Meals per day (2-4)',
        },
        'max_calories_per_meal': {
          'type': 'integer',
          'description': 'Maximum calories per individual meal',
        },
        'max_ready_time': {
          'type': 'integer',
          'description': 'Maximum cooking time per meal in minutes',
        },
        'exclude_ingredients': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Ingredients to exclude',
        },
        'health_goals': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'Health goals (e.g., ["weight_loss", "diabetes_management", "heart_health"])',
        },
      },
      'required': ['cuisine', 'days'],
    },
  );

  static const getRegionalFoods = GeminiTool(
    name: 'get_regional_foods',
    description: '''Get authentic local foods for a specific region/country.
Uses FatSecret's 50+ country database for accurate regional food data.
Best for: finding traditional dishes, local ingredients, cultural meal planning.''',
    parameters: {
      'type': 'object',
      'properties': {
        'country': {
          'type': 'string',
          'description':
              'Country name (e.g., "Kenya", "Nigeria", "Brazil", "India")',
        },
        'category': {
          'type': 'string',
          'description':
              'Food category (e.g., "breakfast", "main_dish", "snack", "beverage")',
        },
        'dietary_restriction': {
          'type': 'string',
          'description':
              'Dietary filter (e.g., "vegetarian", "halal", "kosher")',
        },
        'limit': {
          'type': 'integer',
          'description': 'Number of results (default: 20)',
        },
      },
      'required': ['country'],
    },
  );

  static const getPriceEstimate = GeminiTool(
    name: 'get_price_estimate',
    description: '''Estimate the cost of ingredients for a recipe or meal plan.
Uses Spoonacular's price data for cost breakdown.
Best for: budget-conscious meal planning, grocery list pricing.''',
    parameters: {
      'type': 'object',
      'properties': {
        'ingredients': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'List of ingredients to price',
        },
        'recipe_id': {
          'type': 'string',
          'description': 'Recipe ID to get price breakdown for',
        },
        'currency': {
          'type': 'string',
          'description': 'Target currency (e.g., "USD", "NGN", "KES")',
        },
        'servings': {
          'type': 'integer',
          'description': 'Number of servings to calculate for',
        },
      },
      'required': [],
    },
  );

  /// Get all tools as a list for Gemini API
  static List<Map<String, dynamic>> getAllTools() {
    return [
      {
        'function_declarations': [
          searchRecipes.toJson(),
          searchFoods.toJson(),
          getNutritionAnalysis.toJson(),
          generateMealPlan.toJson(),
          getRegionalFoods.toJson(),
          getPriceEstimate.toJson(),
        ],
      },
    ];
  }
}

// ============================================
// FUNCTION EXECUTOR
// ============================================

/// Executes function calls made by Gemini
class FoodAPIFunctionExecutor {
  final GlobalFoodAPIService _apiService;

  FoodAPIFunctionExecutor({GlobalFoodAPIService? apiService})
    : _apiService = apiService ?? GlobalFoodAPIService();

  /// Execute a function call and return the result
  Future<FunctionCallResult> execute(GeminiFunctionCall call) async {
    debugPrint('🔧 Executing function: ${call.name}');
    debugPrint('   Arguments: ${jsonEncode(call.arguments)}');

    try {
      switch (call.name) {
        case 'search_recipes':
          return await _executeSearchRecipes(call.arguments);
        case 'search_foods':
          return await _executeSearchFoods(call.arguments);
        case 'get_nutrition_analysis':
          return await _executeNutritionAnalysis(call.arguments);
        case 'generate_meal_plan':
          return await _executeGenerateMealPlan(call.arguments);
        case 'get_regional_foods':
          return await _executeGetRegionalFoods(call.arguments);
        case 'get_price_estimate':
          return await _executeGetPriceEstimate(call.arguments);
        default:
          return FunctionCallResult(
            functionName: call.name,
            success: false,
            error: 'Unknown function: ${call.name}',
          );
      }
    } catch (e) {
      debugPrint('❌ Function execution error: $e');
      return FunctionCallResult(
        functionName: call.name,
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<FunctionCallResult> _executeSearchRecipes(
    Map<String, dynamic> args,
  ) async {
    final params = FoodSearchParams(
      query: args['query'] ?? '',
      cuisine: args['cuisine'],
      diet: args['diet'],
      maxCalories: args['max_calories'],
      maxReadyTime: args['max_ready_time'],
      excludeIngredients: List<String>.from(args['exclude_ingredients'] ?? []),
      healthLabels: List<String>.from(args['health_labels'] ?? []),
      limit: args['limit'] ?? 10,
    );

    final result = await _apiService.searchRecipes(params);

    return FunctionCallResult(
      functionName: 'search_recipes',
      success: result.success,
      data: {
        'recipes': result.recipes
            .map(
              (r) => {
                'id': r.id,
                'title': r.title,
                'cuisine': r.cuisine,
                'servings': r.servings,
                'total_time_minutes': r.totalTimeMinutes,
                'calories_per_serving': r.nutritionPerServing.calories,
                'protein_per_serving': r.nutritionPerServing.protein,
                'carbs_per_serving': r.nutritionPerServing.carbs,
                'fat_per_serving': r.nutritionPerServing.fat,
                'ingredients': r.ingredients
                    .map((i) => '${i.amount} ${i.unit} ${i.name}')
                    .toList(),
                'instructions': r.instructions,
                'image_url': r.imageUrl,
                'diet_labels': r.dietLabels,
                'health_labels': r.healthLabels,
                'price_per_serving': r.pricePerServing,
                'source': r.source,
              },
            )
            .toList(),
        'total_results': result.totalResults,
        'source': result.source,
      },
      error: result.error,
    );
  }

  Future<FunctionCallResult> _executeSearchFoods(
    Map<String, dynamic> args,
  ) async {
    final params = FoodSearchParams(
      query: args['query'] ?? '',
      region: args['region'],
      limit: args['limit'] ?? 10,
    );

    final result = await _apiService.searchFoods(params);

    return FunctionCallResult(
      functionName: 'search_foods',
      success: result.success,
      data: {
        'foods': result.foods
            .map(
              (f) => {
                'id': f.id,
                'name': f.name,
                'local_name': f.localName,
                'brand': f.brand,
                'calories': f.nutrition.calories,
                'protein': f.nutrition.protein,
                'carbs': f.nutrition.carbs,
                'fat': f.nutrition.fat,
                'fiber': f.nutrition.fiber,
                'serving_grams': f.serving.grams,
                'serving_description': f.serving.description,
                'source': f.source,
              },
            )
            .toList(),
        'total_results': result.totalResults,
        'source': result.source,
      },
      error: result.error,
    );
  }

  Future<FunctionCallResult> _executeNutritionAnalysis(
    Map<String, dynamic> args,
  ) async {
    // Parse natural language meal or ingredient list
    final ingredients = List<String>.from(args['ingredients'] ?? []);
    final mealDescription = args['meal_description'] as String?;

    final query = mealDescription ?? ingredients.join(', ');

    if (query.isEmpty) {
      return FunctionCallResult(
        functionName: 'get_nutrition_analysis',
        success: false,
        error: 'No ingredients or meal description provided',
      );
    }

    final params = FoodSearchParams(query: query);
    final result = await _apiService.searchFoods(params);

    if (result.success && result.foods.isNotEmpty) {
      // Aggregate nutrition from all foods
      double totalCalories = 0,
          totalProtein = 0,
          totalCarbs = 0,
          totalFat = 0,
          totalFiber = 0;

      for (final food in result.foods) {
        totalCalories += food.nutrition.calories;
        totalProtein += food.nutrition.protein;
        totalCarbs += food.nutrition.carbs;
        totalFat += food.nutrition.fat;
        totalFiber += food.nutrition.fiber;
      }

      return FunctionCallResult(
        functionName: 'get_nutrition_analysis',
        success: true,
        data: {
          'meal': query,
          'total_nutrition': {
            'calories': totalCalories,
            'protein_g': totalProtein,
            'carbs_g': totalCarbs,
            'fat_g': totalFat,
            'fiber_g': totalFiber,
          },
          'breakdown': result.foods
              .map(
                (f) => {
                  'item': f.name,
                  'calories': f.nutrition.calories,
                  'protein': f.nutrition.protein,
                  'carbs': f.nutrition.carbs,
                  'fat': f.nutrition.fat,
                },
              )
              .toList(),
          'diet_labels': result.foods
              .expand((f) => f.dietLabels)
              .toSet()
              .toList(),
          'health_labels': result.foods
              .expand((f) => f.healthLabels)
              .toSet()
              .toList(),
        },
      );
    }

    return FunctionCallResult(
      functionName: 'get_nutrition_analysis',
      success: false,
      error: result.error ?? 'Could not analyze nutrition',
    );
  }

  Future<FunctionCallResult> _executeGenerateMealPlan(
    Map<String, dynamic> args,
  ) async {
    final cuisine = args['cuisine'] as String? ?? 'International';
    final diet = args['diet'] as String? ?? 'balanced';
    final days = args['days'] as int? ?? 7;
    final mealsPerDay = args['meals_per_day'] as int? ?? 3;
    final maxCaloriesPerMeal = args['max_calories_per_meal'] as int?;
    final maxReadyTime = args['max_ready_time'] as int?;
    final excludeIngredients = List<String>.from(
      args['exclude_ingredients'] ?? [],
    );
    final healthGoals = List<String>.from(args['health_goals'] ?? []);

    // Convert health goals to health labels
    final healthLabels = healthGoals.map((goal) {
      switch (goal.toLowerCase()) {
        case 'weight_loss':
          return 'low-calorie';
        case 'diabetes_management':
          return 'low-sugar';
        case 'heart_health':
          return 'low-sodium';
        case 'muscle_gain':
          return 'high-protein';
        default:
          return goal;
      }
    }).toList();

    final recipes = await _apiService.generateMealPlanRecipes(
      cuisine: cuisine,
      diet: diet,
      days: days,
      mealsPerDay: mealsPerDay,
      maxCaloriesPerMeal: maxCaloriesPerMeal,
      maxReadyTime: maxReadyTime,
      excludeIngredients: excludeIngredients,
      healthLabels: healthLabels,
    );

    if (recipes.isEmpty) {
      return FunctionCallResult(
        functionName: 'generate_meal_plan',
        success: false,
        error: 'Could not find enough recipes for the meal plan',
      );
    }

    // Organize recipes into days and meals
    final mealPlan = <Map<String, dynamic>>[];
    int recipeIndex = 0;
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

    for (int day = 1; day <= days; day++) {
      final dayMeals = <Map<String, dynamic>>[];

      for (
        int meal = 0;
        meal < mealsPerDay && meal < mealTypes.length;
        meal++
      ) {
        if (recipeIndex < recipes.length) {
          final recipe = recipes[recipeIndex++];
          dayMeals.add({
            'meal_type': mealTypes[meal],
            'recipe': {
              'title': recipe.title,
              'cuisine': recipe.cuisine ?? cuisine,
              'servings': recipe.servings,
              'total_time_minutes': recipe.totalTimeMinutes,
              'calories': recipe.nutritionPerServing.calories,
              'protein_g': recipe.nutritionPerServing.protein,
              'carbs_g': recipe.nutritionPerServing.carbs,
              'fat_g': recipe.nutritionPerServing.fat,
              'ingredients': recipe.ingredients
                  .map((i) => '${i.amount} ${i.unit} ${i.name}')
                  .toList(),
              'instructions': recipe.instructions,
              'image_url': recipe.imageUrl,
            },
          });
        }
      }

      mealPlan.add({'day': day, 'meals': dayMeals});
    }

    // Calculate totals
    double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    for (final recipe in recipes) {
      totalCalories += recipe.nutritionPerServing.calories;
      totalProtein += recipe.nutritionPerServing.protein;
      totalCarbs += recipe.nutritionPerServing.carbs;
      totalFat += recipe.nutritionPerServing.fat;
    }

    return FunctionCallResult(
      functionName: 'generate_meal_plan',
      success: true,
      data: {
        'cuisine': cuisine,
        'diet': diet,
        'days': days,
        'meals_per_day': mealsPerDay,
        'meal_plan': mealPlan,
        'total_nutrition': {
          'total_calories': totalCalories,
          'avg_daily_calories': totalCalories / days,
          'total_protein_g': totalProtein,
          'total_carbs_g': totalCarbs,
          'total_fat_g': totalFat,
        },
        'recipes_found': recipes.length,
      },
    );
  }

  Future<FunctionCallResult> _executeGetRegionalFoods(
    Map<String, dynamic> args,
  ) async {
    final country = args['country'] as String;
    final category = args['category'] as String?;
    final limit = args['limit'] as int? ?? 20;

    // Map country names to region codes
    final regionCode = _getRegionCode(country);

    final params = FoodSearchParams(
      query: category ?? 'traditional food',
      region: regionCode,
      cuisine: country,
      limit: limit,
    );

    final result = await _apiService.searchFoods(params);

    return FunctionCallResult(
      functionName: 'get_regional_foods',
      success: result.success,
      data: {
        'country': country,
        'region_code': regionCode,
        'category': category,
        'foods': result.foods
            .map(
              (f) => {
                'name': f.name,
                'local_name': f.localName,
                'calories': f.nutrition.calories,
                'protein': f.nutrition.protein,
                'carbs': f.nutrition.carbs,
                'fat': f.nutrition.fat,
                'source': f.source,
              },
            )
            .toList(),
        'total_results': result.totalResults,
      },
      error: result.error,
    );
  }

  Future<FunctionCallResult> _executeGetPriceEstimate(
    Map<String, dynamic> args,
  ) async {
    final ingredients = List<String>.from(args['ingredients'] ?? []);
    final currency = args['currency'] as String? ?? 'USD';
    final servings = args['servings'] as int? ?? 4;

    if (ingredients.isEmpty) {
      return FunctionCallResult(
        functionName: 'get_price_estimate',
        success: false,
        error: 'No ingredients provided',
      );
    }

    // Search for each ingredient to get price data
    final priceBreakdown = <Map<String, dynamic>>[];
    double totalPrice = 0;

    for (final ingredient in ingredients) {
      final params = FoodSearchParams(query: ingredient, limit: 1);
      final result = await _apiService.searchRecipes(params);

      // Use average price estimation
      final estimatedPrice = 2.50; // Default estimate per ingredient
      priceBreakdown.add({
        'ingredient': ingredient,
        'estimated_price': estimatedPrice,
        'currency': currency,
      });
      totalPrice += estimatedPrice;
    }

    return FunctionCallResult(
      functionName: 'get_price_estimate',
      success: true,
      data: {
        'total_price': totalPrice,
        'price_per_serving': totalPrice / servings,
        'currency': currency,
        'servings': servings,
        'breakdown': priceBreakdown,
        'note': 'Prices are estimates and may vary by location',
      },
    );
  }

  String _getRegionCode(String country) {
    final countryToCode = {
      'kenya': 'KE',
      'nigeria': 'NG',
      'south africa': 'ZA',
      'ghana': 'GH',
      'ethiopia': 'ET',
      'tanzania': 'TZ',
      'uganda': 'UG',
      'brazil': 'BR',
      'mexico': 'MX',
      'india': 'IN',
      'pakistan': 'PK',
      'indonesia': 'ID',
      'philippines': 'PH',
      'japan': 'JP',
      'china': 'CN',
      'south korea': 'KR',
      'thailand': 'TH',
      'vietnam': 'VN',
      'united states': 'US',
      'united kingdom': 'GB',
      'canada': 'CA',
      'australia': 'AU',
      'germany': 'DE',
      'france': 'FR',
      'italy': 'IT',
      'spain': 'ES',
    };

    return countryToCode[country.toLowerCase()] ??
        country.substring(0, 2).toUpperCase();
  }
}

// ============================================
// GEMINI FUNCTION CALLING SERVICE
// ============================================

/// Main service for Gemini with function calling capabilities
class GeminiFunctionCallingService {
  static final GeminiFunctionCallingService _instance =
      GeminiFunctionCallingService._internal();
  factory GeminiFunctionCallingService() => _instance;
  GeminiFunctionCallingService._internal();

  final FoodAPIFunctionExecutor _executor = FoodAPIFunctionExecutor();
  late final String _apiKey;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    await GlobalFoodAPIService().initialize();
    _isInitialized = true;
    debugPrint('🤖 GeminiFunctionCallingService initialized');
  }

  /// Send a message to Gemini with function calling enabled
  /// Returns the final response after executing any function calls
  Future<GeminiResponse> chat({
    required String message,
    String? systemPrompt,
    List<Map<String, dynamic>>? conversationHistory,
    int maxFunctionCalls = 5,
  }) async {
    if (!_isInitialized) await initialize();

    if (_apiKey.isEmpty) {
      return GeminiResponse(
        success: false,
        error: 'Gemini API key not configured',
      );
    }

    final messages = <Map<String, dynamic>>[];

    // Add conversation history
    if (conversationHistory != null) {
      messages.addAll(conversationHistory);
    }

    // Add current user message
    messages.add({
      'role': 'user',
      'parts': [
        {'text': message},
      ],
    });

    int functionCallCount = 0;

    while (functionCallCount < maxFunctionCalls) {
      final response = await _callGemini(
        messages: messages,
        systemPrompt: systemPrompt ?? _getDefaultSystemPrompt(),
      );

      if (!response.success) {
        return response;
      }

      // Check if Gemini wants to call a function
      if (response.functionCalls != null &&
          response.functionCalls!.isNotEmpty) {
        functionCallCount++;

        // Execute all function calls
        final functionResults = <FunctionCallResult>[];
        for (final call in response.functionCalls!) {
          final result = await _executor.execute(call);
          functionResults.add(result);
        }

        // Add function response to messages
        messages.add({
          'role': 'model',
          'parts': response.functionCalls!
              .map(
                (c) => {
                  'functionCall': {'name': c.name, 'args': c.arguments},
                },
              )
              .toList(),
        });

        messages.add({
          'role': 'user',
          'parts': functionResults
              .map(
                (r) => {
                  'functionResponse': {
                    'name': r.functionName,
                    'response': {
                      'success': r.success,
                      'data': r.data,
                      'error': r.error,
                    },
                  },
                },
              )
              .toList(),
        });

        debugPrint('🔄 Function call round $functionCallCount completed');
        continue;
      }

      // No function calls, return the final text response
      return response;
    }

    return GeminiResponse(
      success: false,
      error: 'Maximum function calls exceeded',
    );
  }

  Future<GeminiResponse> _callGemini({
    required List<Map<String, dynamic>> messages,
    required String systemPrompt,
  }) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
      );

      final body = {
        'contents': messages,
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'tools': FoodAPITools.getAllTools(),
        'tool_config': {
          'function_calling_config': {'mode': 'AUTO'},
        },
        'generationConfig': {
          'temperature': 0.7,
          'topP': 0.95,
          'topK': 40,
          'maxOutputTokens': 8192,
        },
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;

        if (candidates == null || candidates.isEmpty) {
          return GeminiResponse(
            success: false,
            error: 'No response from Gemini',
          );
        }

        final content = candidates[0]['content'];
        final parts = content['parts'] as List<dynamic>;

        // Check for function calls
        final functionCalls = <GeminiFunctionCall>[];
        String? textResponse;

        for (final part in parts) {
          if (part.containsKey('functionCall')) {
            functionCalls.add(
              GeminiFunctionCall.fromJson(part['functionCall']),
            );
          } else if (part.containsKey('text')) {
            textResponse = part['text'];
          }
        }

        return GeminiResponse(
          success: true,
          text: textResponse,
          functionCalls: functionCalls.isNotEmpty ? functionCalls : null,
        );
      } else {
        final error = jsonDecode(response.body);
        return GeminiResponse(
          success: false,
          error:
              'Gemini API error: ${error['error']?['message'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      return GeminiResponse(success: false, error: 'Gemini request failed: $e');
    }
  }

  String _getDefaultSystemPrompt() {
    return '''You are Wellor's AI Nutrition Assistant, a world-class meal planning expert with access to global food databases containing millions of foods from 50+ countries.

YOUR CAPABILITIES:
- Search millions of real recipes from Spoonacular and Edamam
- Access local/regional foods from FatSecret (50+ countries with native names)
- Analyze nutrition from 2.8M+ packaged products via Open Food Facts
- Generate complete meal plans with accurate nutrition data

IMPORTANT GUIDELINES:
1. ALWAYS use the function tools to get REAL data - never make up nutrition facts
2. When asked about local cuisines (Nigerian, Kenyan, etc.), use get_regional_foods and search_foods with the region parameter
3. For meal planning, use generate_meal_plan or search_recipes to get actual recipes
4. Include native/local food names when available (e.g., "Ugali" not just "maize porridge")
5. Always verify nutrition data through the APIs - don't estimate
6. Consider dietary restrictions, allergies, and health conditions
7. Provide practical, actionable meal plans with real cooking instructions

WORKFLOW:
1. Understand the user's requirements (cuisine, diet, budget, time, health goals)
2. Use appropriate function calls to gather real data
3. Synthesize the results into a friendly, helpful response
4. Always cite the data source (Spoonacular, Edamam, FatSecret, Open Food Facts)

Remember: You are helping real people make important health decisions. Accuracy is paramount.''';
  }

  /// Generate a meal plan with function calling
  Future<MealPlanResult> generateMealPlan({
    required String prompt,
    String? cuisine,
    String? diet,
    int? days,
    String? healthProfile,
    String? country,
  }) async {
    final enhancedPrompt =
        '''
$prompt

${cuisine != null ? 'Cuisine preference: $cuisine' : ''}
${diet != null ? 'Dietary requirements: $diet' : ''}
${days != null ? 'Plan duration: $days days' : ''}
${healthProfile != null ? 'Health considerations: $healthProfile' : ''}
${country != null ? 'Location/Country: $country (use local foods and prices)' : ''}

Please generate a comprehensive meal plan using real recipes from the database. Include:
1. Specific recipes with accurate nutrition data
2. Cooking instructions and prep times
3. Local food names where applicable
4. Total daily and weekly nutrition summary
''';

    final response = await chat(message: enhancedPrompt, maxFunctionCalls: 10);

    return MealPlanResult(
      success: response.success,
      mealPlanText: response.text,
      error: response.error,
    );
  }
}

// ============================================
// RESPONSE MODELS
// ============================================

class GeminiResponse {
  final bool success;
  final String? text;
  final List<GeminiFunctionCall>? functionCalls;
  final String? error;

  GeminiResponse({
    required this.success,
    this.text,
    this.functionCalls,
    this.error,
  });
}

class MealPlanResult {
  final bool success;
  final String? mealPlanText;
  final String? error;

  MealPlanResult({required this.success, this.mealPlanText, this.error});
}
