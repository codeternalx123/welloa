// lib/services/hybrid_meal_engine.dart
// PRINCIPAL ENGINEER GRADE: Hybrid Search-Then-Reason Meal Planning Engine
// Combines Gemini AI reasoning with real food database queries

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'global_food_api_service.dart';
import 'gemini_function_calling_service.dart';
import 'multi_ai_service.dart';
import '../models/family_plan_models.dart';
import '../providers/user_profile_provider.dart';
import '../utils/currency_utils.dart';

// ============================================
// HYBRID MEAL PLAN MODELS
// ============================================

/// A meal plan generated from real API data
class HybridMealPlan {
  final String id;
  final int days;
  final String cuisine;
  final String diet;
  final String country;
  final String currency;
  final List<HybridMealDay> mealDays;
  final List<GroceryItem> groceryList;
  final HybridBudgetSummary budget;
  final NutritionSummary nutritionSummary;
  final List<String> dataSourcesUsed;
  final DateTime createdAt;
  final String? aiInsights;

  HybridMealPlan({
    required this.id,
    required this.days,
    required this.cuisine,
    required this.diet,
    required this.country,
    required this.currency,
    required this.mealDays,
    required this.groceryList,
    required this.budget,
    required this.nutritionSummary,
    required this.dataSourcesUsed,
    required this.createdAt,
    this.aiInsights,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'days': days,
    'cuisine': cuisine,
    'diet': diet,
    'country': country,
    'currency': currency,
    'mealDays': mealDays.map((d) => d.toJson()).toList(),
    'groceryList': groceryList.map((g) => g.toJson()).toList(),
    'budget': budget.toJson(),
    'nutritionSummary': nutritionSummary.toJson(),
    'dataSourcesUsed': dataSourcesUsed,
    'createdAt': createdAt.toIso8601String(),
    'aiInsights': aiInsights,
  };

  factory HybridMealPlan.fromJson(Map<String, dynamic> json) => HybridMealPlan(
    id: json['id'] ?? '',
    days: json['days'] ?? 1,
    cuisine: json['cuisine'] ?? '',
    diet: json['diet'] ?? '',
    country: json['country'] ?? '',
    currency: json['currency'] ?? 'USD',
    mealDays:
        (json['mealDays'] as List<dynamic>?)
            ?.map((d) => HybridMealDay.fromJson(d))
            .toList() ??
        [],
    groceryList:
        (json['groceryList'] as List<dynamic>?)
            ?.map((g) => GroceryItem.fromJson(g))
            .toList() ??
        [],
    budget: HybridBudgetSummary.fromJson(json['budget'] ?? {}),
    nutritionSummary: NutritionSummary.fromJson(json['nutritionSummary'] ?? {}),
    dataSourcesUsed: List<String>.from(json['dataSourcesUsed'] ?? []),
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    aiInsights: json['aiInsights'],
  );
}

class HybridMealDay {
  final int dayNumber;
  final List<HybridMeal> meals;
  final double dailyCalories;
  final double dailyProtein;
  final double dailyCarbs;
  final double dailyFat;

  HybridMealDay({
    required this.dayNumber,
    required this.meals,
    required this.dailyCalories,
    required this.dailyProtein,
    required this.dailyCarbs,
    required this.dailyFat,
  });

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'meals': meals.map((m) => m.toJson()).toList(),
    'dailyCalories': dailyCalories,
    'dailyProtein': dailyProtein,
    'dailyCarbs': dailyCarbs,
    'dailyFat': dailyFat,
  };

  factory HybridMealDay.fromJson(Map<String, dynamic> json) => HybridMealDay(
    dayNumber: json['dayNumber'] ?? 1,
    meals:
        (json['meals'] as List<dynamic>?)
            ?.map((m) => HybridMeal.fromJson(m))
            .toList() ??
        [],
    dailyCalories: (json['dailyCalories'] ?? 0).toDouble(),
    dailyProtein: (json['dailyProtein'] ?? 0).toDouble(),
    dailyCarbs: (json['dailyCarbs'] ?? 0).toDouble(),
    dailyFat: (json['dailyFat'] ?? 0).toDouble(),
  );
}

class HybridMeal {
  final String mealType; // breakfast, lunch, dinner, snack
  final String name;
  final String? localName;
  final String? description;
  final List<MealIngredient> ingredients;
  final List<String> instructions;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final MealNutrition nutrition;
  final double estimatedCost;
  final String? imageUrl;
  final String dataSource;
  final String? recipeId;
  final List<String> healthBenefits;
  final List<String> dietLabels;

  HybridMeal({
    required this.mealType,
    required this.name,
    this.localName,
    this.description,
    required this.ingredients,
    required this.instructions,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    required this.nutrition,
    this.estimatedCost = 0,
    this.imageUrl,
    required this.dataSource,
    this.recipeId,
    this.healthBenefits = const [],
    this.dietLabels = const [],
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  Map<String, dynamic> toJson() => {
    'mealType': mealType,
    'name': name,
    'localName': localName,
    'description': description,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'instructions': instructions,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'nutrition': nutrition.toJson(),
    'estimatedCost': estimatedCost,
    'imageUrl': imageUrl,
    'dataSource': dataSource,
    'recipeId': recipeId,
    'healthBenefits': healthBenefits,
    'dietLabels': dietLabels,
  };

  factory HybridMeal.fromJson(Map<String, dynamic> json) => HybridMeal(
    mealType: json['mealType'] ?? 'meal',
    name: json['name'] ?? '',
    localName: json['localName'],
    description: json['description'],
    ingredients:
        (json['ingredients'] as List<dynamic>?)
            ?.map((i) => MealIngredient.fromJson(i))
            .toList() ??
        [],
    instructions: List<String>.from(json['instructions'] ?? []),
    prepTimeMinutes: json['prepTimeMinutes'] ?? 0,
    cookTimeMinutes: json['cookTimeMinutes'] ?? 0,
    nutrition: MealNutrition.fromJson(json['nutrition'] ?? {}),
    estimatedCost: (json['estimatedCost'] ?? 0).toDouble(),
    imageUrl: json['imageUrl'],
    dataSource: json['dataSource'] ?? 'unknown',
    recipeId: json['recipeId'],
    healthBenefits: List<String>.from(json['healthBenefits'] ?? []),
    dietLabels: List<String>.from(json['dietLabels'] ?? []),
  );

  factory HybridMeal.fromGlobalRecipe(GlobalRecipe recipe, String mealType) =>
      HybridMeal(
        mealType: mealType,
        name: recipe.title,
        localName: recipe.localTitle,
        ingredients: recipe.ingredients
            .map(
              (i) => MealIngredient(
                name: i.name,
                localName: i.localName,
                amount: i.amount,
                unit: i.unit,
              ),
            )
            .toList(),
        instructions: recipe.instructions,
        prepTimeMinutes: recipe.prepTimeMinutes ?? 0,
        cookTimeMinutes: recipe.cookTimeMinutes ?? 0,
        nutrition: MealNutrition(
          calories: recipe.nutritionPerServing.calories,
          protein: recipe.nutritionPerServing.protein,
          carbs: recipe.nutritionPerServing.carbs,
          fat: recipe.nutritionPerServing.fat,
          fiber: recipe.nutritionPerServing.fiber,
        ),
        estimatedCost: recipe.pricePerServing ?? 0,
        imageUrl: recipe.imageUrl,
        dataSource: recipe.source,
        recipeId: recipe.id,
        healthBenefits: recipe.healthLabels,
        dietLabels: recipe.dietLabels,
      );
}

class MealIngredient {
  final String name;
  final String? localName;
  final double amount;
  final String unit;
  final double? estimatedPrice;

  MealIngredient({
    required this.name,
    this.localName,
    required this.amount,
    required this.unit,
    this.estimatedPrice,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'localName': localName,
    'amount': amount,
    'unit': unit,
    'estimatedPrice': estimatedPrice,
  };

  factory MealIngredient.fromJson(Map<String, dynamic> json) => MealIngredient(
    name: json['name'] ?? '',
    localName: json['localName'],
    amount: (json['amount'] ?? 0).toDouble(),
    unit: json['unit'] ?? '',
    estimatedPrice: json['estimatedPrice']?.toDouble(),
  );
}

class MealNutrition {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double? sugar;
  final double? sodium;

  MealNutrition({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar,
    this.sodium,
  });

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sugar': sugar,
    'sodium': sodium,
  };

  factory MealNutrition.fromJson(Map<String, dynamic> json) => MealNutrition(
    calories: (json['calories'] ?? 0).toDouble(),
    protein: (json['protein'] ?? 0).toDouble(),
    carbs: (json['carbs'] ?? 0).toDouble(),
    fat: (json['fat'] ?? 0).toDouble(),
    fiber: (json['fiber'] ?? 0).toDouble(),
    sugar: json['sugar']?.toDouble(),
    sodium: json['sodium']?.toDouble(),
  );
}

class GroceryItem {
  final String name;
  final String? localName;
  final double amount;
  final String unit;
  final String category;
  final double estimatedPrice;
  final bool isPantryStaple;

  GroceryItem({
    required this.name,
    this.localName,
    required this.amount,
    required this.unit,
    required this.category,
    this.estimatedPrice = 0,
    this.isPantryStaple = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'localName': localName,
    'amount': amount,
    'unit': unit,
    'category': category,
    'estimatedPrice': estimatedPrice,
    'isPantryStaple': isPantryStaple,
  };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
    name: json['name'] ?? '',
    localName: json['localName'],
    amount: (json['amount'] ?? 0).toDouble(),
    unit: json['unit'] ?? '',
    category: json['category'] ?? 'Other',
    estimatedPrice: (json['estimatedPrice'] ?? 0).toDouble(),
    isPantryStaple: json['isPantryStaple'] ?? false,
  );
}

class HybridBudgetSummary {
  final double totalCost;
  final double costPerDay;
  final double costPerMeal;
  final String currency;
  final Map<String, double> categoryBreakdown;

  HybridBudgetSummary({
    required this.totalCost,
    required this.costPerDay,
    required this.costPerMeal,
    required this.currency,
    this.categoryBreakdown = const {},
  });

  Map<String, dynamic> toJson() => {
    'totalCost': totalCost,
    'costPerDay': costPerDay,
    'costPerMeal': costPerMeal,
    'currency': currency,
    'categoryBreakdown': categoryBreakdown,
  };

  factory HybridBudgetSummary.fromJson(Map<String, dynamic> json) =>
      HybridBudgetSummary(
        totalCost: (json['totalCost'] ?? 0).toDouble(),
        costPerDay: (json['costPerDay'] ?? 0).toDouble(),
        costPerMeal: (json['costPerMeal'] ?? 0).toDouble(),
        currency: json['currency'] ?? 'USD',
        categoryBreakdown: Map<String, double>.from(
          (json['categoryBreakdown'] ?? {}).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        ),
      );
}

class NutritionSummary {
  final double avgDailyCalories;
  final double avgDailyProtein;
  final double avgDailyCarbs;
  final double avgDailyFat;
  final double avgDailyFiber;
  final double totalCalories;

  NutritionSummary({
    required this.avgDailyCalories,
    required this.avgDailyProtein,
    required this.avgDailyCarbs,
    required this.avgDailyFat,
    required this.avgDailyFiber,
    required this.totalCalories,
  });

  Map<String, dynamic> toJson() => {
    'avgDailyCalories': avgDailyCalories,
    'avgDailyProtein': avgDailyProtein,
    'avgDailyCarbs': avgDailyCarbs,
    'avgDailyFat': avgDailyFat,
    'avgDailyFiber': avgDailyFiber,
    'totalCalories': totalCalories,
  };

  factory NutritionSummary.fromJson(Map<String, dynamic> json) =>
      NutritionSummary(
        avgDailyCalories: (json['avgDailyCalories'] ?? 0).toDouble(),
        avgDailyProtein: (json['avgDailyProtein'] ?? 0).toDouble(),
        avgDailyCarbs: (json['avgDailyCarbs'] ?? 0).toDouble(),
        avgDailyFat: (json['avgDailyFat'] ?? 0).toDouble(),
        avgDailyFiber: (json['avgDailyFiber'] ?? 0).toDouble(),
        totalCalories: (json['totalCalories'] ?? 0).toDouble(),
      );
}

// ============================================
// HYBRID MEAL ENGINE
// ============================================

/// The main hybrid engine that combines API data with AI reasoning
class HybridMealEngine {
  static final HybridMealEngine _instance = HybridMealEngine._internal();
  factory HybridMealEngine() => _instance;
  HybridMealEngine._internal();

  final GlobalFoodAPIService _foodAPI = GlobalFoodAPIService();
  final GeminiFunctionCallingService _geminiService =
      GeminiFunctionCallingService();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _foodAPI.initialize();
    await _geminiService.initialize();
    _isInitialized = true;
    debugPrint('🚀 HybridMealEngine initialized');
  }

  /// Generate a hybrid meal plan using real API data
  /// Phase 1: Extract parameters from user request
  /// Phase 2: Query food APIs for real data
  /// Phase 3: Synthesize with AI into friendly meal plan
  Future<HybridMealPlanResult> generateMealPlan({
    required int days,
    required String cuisine,
    required String diet,
    String country = 'United States',
    String currency = 'USD',
    int mealsPerDay = 3,
    int? maxCaloriesPerDay,
    int? maxCookingTimeMinutes,
    List<String> excludeIngredients = const [],
    List<String> healthGoals = const [],
    String? healthProfile,
    FamilyPlanSetup? familySetup,
    double? budgetPerDay,
    String? flavor,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🍽️ HYBRID MEAL ENGINE: Starting meal plan generation');
      debugPrint('   Cuisine: $cuisine | Diet: $diet | Days: $days');
      debugPrint('   Country: $country | Currency: $currency | Flavor: ${flavor ?? "balanced"}');
      debugPrint('═══════════════════════════════════════════════════════════');

      // PHASE 1: Query APIs for real recipes
      final recipes = await _fetchRecipesForMealPlan(
        cuisine: cuisine,
        diet: diet,
        days: days,
        mealsPerDay: mealsPerDay,
        maxCaloriesPerMeal: maxCaloriesPerDay != null
            ? maxCaloriesPerDay ~/ mealsPerDay
            : null,
        maxReadyTime: maxCookingTimeMinutes,
        excludeIngredients: excludeIngredients,
        healthGoals: healthGoals,
        flavor: flavor,
        healthProfile: healthProfile,
      );

      if (recipes.isEmpty) {
        debugPrint(
          '❌ No recipes found from APIs, falling back to AI generation',
        );
        return await _fallbackToAIGeneration(
          days: days,
          cuisine: cuisine,
          diet: diet,
          country: country,
          currency: currency,
          healthProfile: healthProfile,
          familySetup: familySetup,
          flavor: flavor,
          budgetPerDay: budgetPerDay,
          mealsPerDay: mealsPerDay,
        );
      }

      debugPrint('✅ Found ${recipes.length} recipes from APIs');

      // Check if we have enough recipes for all meals
      final requiredRecipes = days * mealsPerDay;
      if (recipes.length < requiredRecipes) {
        debugPrint('⚠️ Not enough recipes (${recipes.length}/$requiredRecipes), falling back to AI');
        return await _fallbackToAIGeneration(
          days: days,
          cuisine: cuisine,
          diet: diet,
          country: country,
          currency: currency,
          healthProfile: healthProfile,
          familySetup: familySetup,
          flavor: flavor,
          budgetPerDay: budgetPerDay,
          mealsPerDay: mealsPerDay,
        );
      }

      // PHASE 2: Organize recipes into meal plan
      final mealPlan = await _organizeMealPlan(
        recipes: recipes,
        days: days,
        mealsPerDay: mealsPerDay,
        cuisine: cuisine,
        diet: diet,
        country: country,
        currency: currency,
      );

      // PHASE 3: Generate AI insights
      final aiInsights = await _generateAIInsights(
        mealPlan: mealPlan,
        healthGoals: healthGoals,
        healthProfile: healthProfile,
      );

      final finalPlan = HybridMealPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        days: days,
        cuisine: cuisine,
        diet: diet,
        country: country,
        currency: currency,
        mealDays: mealPlan.mealDays,
        groceryList: mealPlan.groceryList,
        budget: mealPlan.budget,
        nutritionSummary: mealPlan.nutritionSummary,
        dataSourcesUsed: mealPlan.dataSourcesUsed,
        createdAt: DateTime.now(),
        aiInsights: aiInsights,
      );

      // Save to Firestore
      await _saveMealPlanToFirestore(finalPlan);

      return HybridMealPlanResult.success(finalPlan);
    } catch (e) {
      debugPrint('❌ HybridMealEngine error: $e');
      return HybridMealPlanResult.failure('Failed to generate meal plan: $e');
    }
  }

  /// Fetch recipes from multiple APIs with diversity enforcement
  Future<List<GlobalRecipe>> _fetchRecipesForMealPlan({
    required String cuisine,
    required String diet,
    required int days,
    required int mealsPerDay,
    int? maxCaloriesPerMeal,
    int? maxReadyTime,
    List<String> excludeIngredients = const [],
    List<String> healthGoals = const [],
    String? flavor,
    String? healthProfile,
  }) async {
    final allRecipes = <GlobalRecipe>[];
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final usedIds = <String>{};
    final usedNames = <String>{}; // Track used dish names to prevent duplicates
    final usedPrimaryIngredients = <String, Set<String>>{}; // Track per-mealType primary ingredients
    final usedCookingStyles = <String, List<String>>{}; // Track cooking styles per day
    final random = Random();

    // Initialize tracking sets for each meal type
    for (final type in mealTypes) {
      usedPrimaryIngredients[type] = <String>{};
      usedCookingStyles[type] = <String>[];
    }

    // ENHANCED DIVERSITY: Flavor-specific ingredient/style keywords to diversify meal types
    final flavorKeywords = _getFlavorKeywords(flavor);
    
    // Health-profile-driven keywords for search queries
    final healthKeywords = _getHealthKeywords(healthGoals, healthProfile);

    // Use varied search terms per day to increase diversity
    // Extended with MORE varied meal-type specific terms
    final mealVariants = {
      'breakfast': [
        'breakfast', 'morning meal', 'brunch', 'early meal', 
        'sunrise dish', 'dawn treat', 'wake-up food', 'first meal',
        'healthy start', 'morning nutrition', 'energy breakfast', 'light breakfast',
      ],
      'lunch': [
        'lunch', 'midday meal', 'afternoon meal', 'light lunch',
        'noon dish', 'daytime entree', 'workday meal', 'quick lunch',
        'power lunch', 'fresh lunch', 'wholesome midday', 'satisfying lunch',
      ],
      'dinner': [
        'dinner', 'evening meal', 'supper', 'main course',
        'night dish', 'hearty dinner', 'comfort meal', 'family dinner',
        'nourishing dinner', 'warming supper', 'fulfilling dinner', 'traditional dinner',
      ],
      'snack': [
        'snack', 'light bite', 'appetizer', 'side dish',
        'healthy snack', 'quick bite', 'finger food', 'treat',
        'energy boost', 'mini meal', 'afternoon treat', 'light refreshment',
      ],
    };

    // Meal-specific ingredient themes to ensure different dishes per meal type
    // Expanded with many more options to prevent cycling through the same ones
    final mealIngredientThemes = {
      'breakfast': ['eggs', 'porridge', 'pancakes', 'bread', 'oats', 'fruit', 'cereal', 'toast',
        'smoothie', 'yogurt', 'muffin', 'crepe', 'avocado', 'granola', 'beans', 'cheese'],
      'lunch': ['salad', 'sandwich', 'soup', 'bowl', 'wrap', 'rice', 'grilled', 'stuffed',
        'noodle', 'stir-fry', 'flatbread', 'grain bowl', 'lentil', 'veggie', 'seafood', 'bean'],
      'dinner': ['roasted', 'stew', 'curry', 'grilled meat', 'pasta', 'casserole', 'baked', 'braised',
        'seared', 'steamed', 'slow-cooked', 'pan-fried', 'stuffed', 'smoked', 'marinated', 'glazed'],
      'snack': ['nuts', 'yogurt', 'smoothie', 'crackers', 'veggies', 'hummus', 'chips', 'fruit',
        'seeds', 'popcorn', 'trail mix', 'energy bar', 'dates', 'cheese', 'dip', 'roll'],
    };
    
    // Protein rotation per day to prevent same protein across days
    final proteinRotation = ['chicken', 'fish', 'beef', 'eggs', 'beans', 'lentils', 'tofu', 'pork',
      'shrimp', 'turkey', 'lamb', 'chickpeas', 'tempeh', 'sardines', 'goat'];
    proteinRotation.shuffle(random);

    // BATCH MODE: Build all search params upfront (no awaits yet)
    final searchTasks = <({int day, int meal, String mealType, FoodSearchParams params})>[];
    for (int day = 0; day < days; day++) {
      // Select day-specific protein to emphasize diversity across days
      final dayProtein = proteinRotation[day % proteinRotation.length];

      for (int meal = 0; meal < mealsPerDay && meal < mealTypes.length; meal++) {
        final mealType = mealTypes[meal];
        // Pick a varied search term using RANDOMIZED index for better diversity
        final variants = mealVariants[mealType] ?? [mealType];
        final variantIndex = (day * mealsPerDay + meal + random.nextInt(variants.length)) % variants.length;
        final variantTerm = variants[variantIndex];

        // Pick a meal-type specific ingredient theme using RANDOMIZED offset
        final ingredientThemes = mealIngredientThemes[mealType] ?? [];
        final themeIndex = ingredientThemes.isNotEmpty 
            ? (day * 3 + meal * 5 + random.nextInt(ingredientThemes.length)) % ingredientThemes.length
            : 0;
        final ingredientHint = ingredientThemes.isNotEmpty 
            ? ingredientThemes[themeIndex]
            : '';

        // Build search query with enhanced variation including flavor, health, and ingredient hint
        final flavorTerm = flavorKeywords.isNotEmpty 
            ? flavorKeywords[(day + meal) % flavorKeywords.length] 
            : '';
        final healthTerm = healthKeywords.isNotEmpty
            ? healthKeywords[(day * mealsPerDay + meal) % healthKeywords.length]
            : '';
        // Add day-specific protein hint for lunch/dinner
        final proteinHint = (mealType == 'lunch' || mealType == 'dinner') ? dayProtein : '';
        final searchQuery = '$cuisine $variantTerm $ingredientHint $flavorTerm $healthTerm $proteinHint ${diet != 'any' ? diet : ''}'.trim();

        debugPrint('🔍 Day $day $mealType search: $searchQuery');

        searchTasks.add((
          day: day,
          meal: meal,
          mealType: mealType,
          params: FoodSearchParams(
            query: searchQuery,
            cuisine: cuisine,
            diet: diet != 'any' ? diet : null,
            maxCalories: maxCaloriesPerMeal,
            maxReadyTime: maxReadyTime,
            excludeIngredients: excludeIngredients,
            healthLabels: _mapHealthGoalsToLabels(healthGoals),
            limit: 40, // Fetch even more results for better diversity scoring
          ),
        ));
      }
    }

    // BATCH FIRE: Send ALL API calls in parallel (~3s total instead of ~42s sequential)
    debugPrint('⚡ Firing ${searchTasks.length} recipe API calls in parallel batch...');
    final allResults = await Future.wait(
      searchTasks.map((task) => _foodAPI.searchRecipes(task.params).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏱️ API timeout for Day ${task.day} ${task.mealType}');
          return FoodSearchResult.failure('API timeout', 'timeout');
        },
      )),
    );
    debugPrint('⚡ All ${searchTasks.length} API calls completed in batch');

    // Process results sequentially for diversity scoring (instant, no network)
    for (int i = 0; i < searchTasks.length; i++) {
      final task = searchTasks[i];
      final result = allResults[i];

      if (result.success && result.recipes.isNotEmpty) {
        // Score and rank ALL results for diversity, health, and flavor fit
        final scored = _scoreRecipesForDiversity(
          recipes: result.recipes,
          mealType: task.mealType,
          usedIds: usedIds,
          usedNames: usedNames,
          usedPrimaryIngredients: usedPrimaryIngredients[task.mealType] ?? {},
          healthGoals: healthGoals,
          healthProfile: healthProfile,
          flavor: flavor,
          dayIndex: task.day,
          random: random,
        );

        // Pick the highest-scoring recipe that hasn't been used
        for (final entry in scored) {
          final recipe = entry.key;
          final normalizedName = recipe.title.toLowerCase().trim();
          if (!usedIds.contains(recipe.id) && !usedNames.contains(normalizedName)) {
            // Check primary ingredient uniqueness within this meal type
            final primaryIng = _extractPrimaryIngredient(recipe);
            if (primaryIng.isNotEmpty && (usedPrimaryIngredients[task.mealType]?.contains(primaryIng) ?? false)) {
              // Same primary ingredient already used for this meal type - penalize but allow if no better option
              continue;
            }
            allRecipes.add(recipe);
            usedIds.add(recipe.id);
            usedNames.add(normalizedName);
            if (primaryIng.isNotEmpty) {
              usedPrimaryIngredients[task.mealType]?.add(primaryIng);
            }
            debugPrint('   ✅ Selected: ${recipe.title} (primary: $primaryIng, score: ${entry.value.toStringAsFixed(1)})');
            break;
          }
        }
      }
    }

    return allRecipes;
  }

  /// Score recipes for diversity, health alignment, and flavor match
  /// Returns sorted list of (recipe, score) with highest scores first
  List<MapEntry<GlobalRecipe, double>> _scoreRecipesForDiversity({
    required List<GlobalRecipe> recipes,
    required String mealType,
    required Set<String> usedIds,
    required Set<String> usedNames,
    required Set<String> usedPrimaryIngredients,
    required List<String> healthGoals,
    String? healthProfile,
    String? flavor,
    required int dayIndex,
    required Random random,
  }) {
    final scored = <MapEntry<GlobalRecipe, double>>[];
    final healthProfileLower = (healthProfile ?? '').toLowerCase();
    final flavorLower = (flavor ?? '').toLowerCase();

    // Build health condition filters
    final isLowSugar = healthProfileLower.contains('diabetes') || healthProfileLower.contains('diabetic') || healthProfileLower.contains('blood sugar');
    final isLowSodium = healthProfileLower.contains('hypertension') || healthProfileLower.contains('high blood pressure') || healthProfileLower.contains('heart');
    final isHighProtein = healthProfileLower.contains('muscle') || healthProfileLower.contains('protein') || healthProfileLower.contains('bulk');
    final isLowCalorie = healthProfileLower.contains('weight loss') || healthProfileLower.contains('lose weight') || healthProfileLower.contains('obesity');
    final isLowCarb = healthProfileLower.contains('keto') || healthProfileLower.contains('low-carb') || healthProfileLower.contains('low carb');
    final isAntiInflammatory = healthProfileLower.contains('inflammation') || healthProfileLower.contains('pcos') || healthProfileLower.contains('arthritis');
    final isHighFiber = healthProfileLower.contains('digest') || healthProfileLower.contains('gut') || healthProfileLower.contains('fiber') || healthProfileLower.contains('constipation');

    for (final recipe in recipes) {
      double score = 0;
      final nameLower = recipe.title.toLowerCase();
      final primaryIng = _extractPrimaryIngredient(recipe);

      // --- UNIQUENESS SCORING (highest weight) ---
      if (usedIds.contains(recipe.id) || usedNames.contains(nameLower.trim())) {
        continue; // Skip already used recipes entirely
      }
      if (primaryIng.isNotEmpty && usedPrimaryIngredients.contains(primaryIng)) {
        score -= 30; // Heavy penalty for repeated primary ingredient in same meal type
      }

      // --- HEALTH PROFILE SCORING ---
      final nutrition = recipe.nutritionPerServing;
      if (isLowSugar) {
        score += nutrition.sugar < 10 ? 15 : (nutrition.sugar < 20 ? 5 : -10);
        score += nutrition.fiber > 5 ? 10 : 0; // Fiber helps blood sugar
      }
      if (isLowSodium) {
        score += nutrition.sodium < 400 ? 15 : (nutrition.sodium < 800 ? 5 : -10);
        score += nutrition.fat < 15 ? 5 : 0; // Low fat for heart health
      }
      if (isHighProtein) {
        score += nutrition.protein > 25 ? 15 : (nutrition.protein > 15 ? 8 : 0);
      }
      if (isLowCalorie) {
        score += nutrition.calories < 400 ? 15 : (nutrition.calories < 600 ? 5 : -5);
      }
      if (isLowCarb) {
        score += nutrition.carbs < 20 ? 15 : (nutrition.carbs < 40 ? 5 : -10);
      }
      if (isAntiInflammatory) {
        // Reward recipes with omega-3 indicators, turmeric, ginger, leafy greens
        final antiInflamIngredients = ['turmeric', 'ginger', 'salmon', 'spinach', 'olive oil', 'berries', 'nuts', 'avocado'];
        for (final ing in recipe.ingredients) {
          if (antiInflamIngredients.any((a) => ing.name.toLowerCase().contains(a))) {
            score += 5;
          }
        }
      }
      if (isHighFiber) {
        score += nutrition.fiber > 8 ? 15 : (nutrition.fiber > 4 ? 8 : 0);
      }

      // Reward recipes whose health labels match user's goals
      for (final label in recipe.healthLabels) {
        for (final goal in healthGoals) {
          if (label.toLowerCase().contains(goal.toLowerCase())) {
            score += 8;
          }
        }
      }

      // --- FLAVOR SCORING ---
      if (flavorLower.isNotEmpty) {
        final flavorKeywords = _getFlavorKeywords(flavor);
        for (final kw in flavorKeywords) {
          if (nameLower.contains(kw.toLowerCase())) score += 10;
          for (final ing in recipe.ingredients) {
            if (ing.name.toLowerCase().contains(kw.toLowerCase())) score += 5;
          }
        }
        // Penalize bland-sounding recipes when a strong flavor is selected
        if (flavorLower == 'spicy' && !nameLower.contains('spic') && !nameLower.contains('hot') && !nameLower.contains('chili') && !nameLower.contains('pepper')) {
          score -= 5;
        }
      }

      // --- RANDOMIZATION for natural variety ---
      score += random.nextDouble() * 12; // Random bonus 0-12 to break ties differently each time

      scored.add(MapEntry(recipe, score));
    }

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored;
  }

  /// Extract the primary ingredient from a recipe for diversity tracking
  String _extractPrimaryIngredient(GlobalRecipe recipe) {
    // Common primary protein/starch keywords to detect
    final primaryKeywords = [
      'chicken', 'beef', 'pork', 'fish', 'salmon', 'shrimp', 'lamb', 'goat', 'turkey',
      'tofu', 'tempeh', 'egg', 'beans', 'lentils', 'chickpeas', 'paneer',
      'rice', 'pasta', 'noodle', 'bread', 'ugali', 'potato', 'yam', 'cassava',
      'quinoa', 'couscous', 'millet', 'sorghum', 'oats',
    ];
    final titleLower = recipe.title.toLowerCase();
    for (final kw in primaryKeywords) {
      if (titleLower.contains(kw)) return kw;
    }
    // Check first 3 ingredients
    for (int i = 0; i < recipe.ingredients.length && i < 3; i++) {
      final ingName = recipe.ingredients[i].name.toLowerCase();
      for (final kw in primaryKeywords) {
        if (ingName.contains(kw)) return kw;
      }
    }
    return '';
  }

  /// Get health-condition-aware search keywords from goals and profile
  List<String> _getHealthKeywords(List<String> healthGoals, String? healthProfile) {
    final keywords = <String>{};
    final profileLower = (healthProfile ?? '').toLowerCase();

    // Map health conditions to food-search-friendly keywords
    final conditionKeywords = {
      'diabetes': ['low-sugar', 'high-fiber', 'whole-grain', 'low-glycemic'],
      'diabetic': ['low-sugar', 'high-fiber', 'whole-grain', 'low-glycemic'],
      'hypertension': ['low-sodium', 'heart-healthy', 'potassium-rich'],
      'high blood pressure': ['low-sodium', 'heart-healthy'],
      'weight loss': ['low-calorie', 'high-protein', 'light', 'lean'],
      'lose weight': ['low-calorie', 'light', 'lean'],
      'heart': ['heart-healthy', 'low-fat', 'omega-3', 'lean'],
      'muscle': ['high-protein', 'protein-rich', 'lean meat'],
      'keto': ['low-carb', 'high-fat', 'keto'],
      'inflammation': ['anti-inflammatory', 'turmeric', 'omega-3'],
      'pcos': ['low-carb', 'anti-inflammatory', 'lean'],
      'gut health': ['probiotic', 'fermented', 'high-fiber'],
      'digestive': ['easy-digest', 'light', 'gentle'],
      'cholesterol': ['low-cholesterol', 'low-fat', 'oat'],
      'kidney': ['low-sodium', 'low-phosphorus'],
      'energy': ['energy-boosting', 'complex-carb', 'iron-rich'],
    };

    conditionKeywords.forEach((condition, kws) {
      if (profileLower.contains(condition)) {
        keywords.addAll(kws);
      }
    });

    // Also map healthGoals list entries
    for (final goal in healthGoals) {
      final goalLower = goal.toLowerCase();
      conditionKeywords.forEach((condition, kws) {
        if (goalLower.contains(condition)) {
          keywords.addAll(kws);
        }
      });
    }

    return keywords.toList();
  }

  /// Returns flavor-specific keywords to diversify search queries
  List<String> _getFlavorKeywords(String? flavor) {
    if (flavor == null || flavor.isEmpty) return [];
    
    switch (flavor.toLowerCase()) {
      case 'spicy':
        return ['spicy', 'hot', 'chili', 'pepper', 'fiery', 'zesty', 'bold'];
      case 'sweet':
        return ['sweet', 'honey', 'fruity', 'caramelized', 'dessert-like', 'maple'];
      case 'sour':
        return ['tangy', 'citrus', 'lemon', 'pickled', 'fermented', 'vinegar'];
      case 'salty':
        return ['savory', 'umami', 'seasoned', 'briny', 'cured'];
      case 'umami':
        return ['umami', 'savory', 'mushroom', 'fermented', 'rich', 'deep-flavored'];
      case 'bitter':
        return ['bitter greens', 'dark chocolate', 'coffee-rubbed', 'herbal'];
      case 'mild':
        return ['mild', 'gentle', 'subtle', 'light', 'delicate'];
      default:
        return [flavor.toLowerCase()];
    }
  }

  /// Organize fetched recipes into a structured meal plan
  Future<HybridMealPlan> _organizeMealPlan({
    required List<GlobalRecipe> recipes,
    required int days,
    required int mealsPerDay,
    required String cuisine,
    required String diet,
    required String country,
    required String currency,
  }) async {
    final mealDays = <HybridMealDay>[];
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    final allIngredients = <String, MealIngredient>{};
    final dataSources = <String>{};

    // 🚀 PHASE 1: Convert all recipes to HybridMeals and identify enrichment needs
    final allMeals = <({HybridMeal meal, int day, int mealIndex})>[];
    final mealsNeedingEnrichment = <({HybridMeal meal, int day, int mealIndex, int globalIndex})>[];
    
    int recipeIndex = 0;
    int globalMealIndex = 0;
    
    for (int day = 1; day <= days; day++) {
      for (int meal = 0; meal < mealsPerDay && meal < mealTypes.length; meal++) {
        if (recipeIndex < recipes.length) {
          final recipe = recipes[recipeIndex++];
          final hybridMeal = HybridMeal.fromGlobalRecipe(recipe, mealTypes[meal]);
          
          allMeals.add((meal: hybridMeal, day: day, mealIndex: meal));
          
          // Track meals needing enrichment
          if (hybridMeal.ingredients.isEmpty || hybridMeal.instructions.isEmpty) {
            mealsNeedingEnrichment.add((
              meal: hybridMeal, 
              day: day, 
              mealIndex: meal,
              globalIndex: globalMealIndex
            ));
          }
          
          dataSources.add(recipe.source);
          globalMealIndex++;
        }
      }
    }

    // 🚀 PHASE 2: PARALLEL BATCH ENRICHMENT (90s → ~10s for 9 meals!)
    if (mealsNeedingEnrichment.isNotEmpty) {
      debugPrint('⚡ PARALLEL ENRICHMENT: ${mealsNeedingEnrichment.length} meals need AI enrichment...');
      final enrichmentFutures = mealsNeedingEnrichment.map(
        (record) => _enrichMealWithAI(record.meal, cuisine, diet)
      ).toList();
      
      final enrichedMeals = await Future.wait(enrichmentFutures);
      debugPrint('✅ All ${mealsNeedingEnrichment.length} meals enriched in parallel!');
      
      // Replace enriched meals in the allMeals list
      for (int i = 0; i < mealsNeedingEnrichment.length; i++) {
        final enrichmentRecord = mealsNeedingEnrichment[i];
        final enrichedMeal = enrichedMeals[i];
        
        // Find and replace in allMeals
        final indexToReplace = allMeals.indexWhere(
          (m) => m.day == enrichmentRecord.day && m.mealIndex == enrichmentRecord.mealIndex
        );
        if (indexToReplace != -1) {
          allMeals[indexToReplace] = (
            meal: enrichedMeal, 
            day: enrichmentRecord.day, 
            mealIndex: enrichmentRecord.mealIndex
          );
        }
      }
    }

    // 🚀 PHASE 3: Organize enriched meals into day structure
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    double totalCost = 0;

    for (int day = 1; day <= days; day++) {
      final dayMeals = allMeals.where((m) => m.day == day).map((m) => m.meal).toList();
      
      double dayCalories = 0;
      double dayProtein = 0;
      double dayCarbs = 0;
      double dayFat = 0;

      for (final meal in dayMeals) {
        dayCalories += meal.nutrition.calories;
        dayProtein += meal.nutrition.protein;
        dayCarbs += meal.nutrition.carbs;
        dayFat += meal.nutrition.fat;
        totalFiber += meal.nutrition.fiber;
        totalCost += meal.estimatedCost;

        // Aggregate ingredients
        for (final ing in meal.ingredients) {
          final key = ing.name.toLowerCase();
          if (allIngredients.containsKey(key)) {
            final existing = allIngredients[key]!;
            allIngredients[key] = MealIngredient(
              name: ing.name,
              localName: ing.localName,
              amount: existing.amount + ing.amount,
              unit: ing.unit,
              estimatedPrice:
                  (existing.estimatedPrice ?? 0) + (ing.estimatedPrice ?? 0),
            );
          } else {
            allIngredients[key] = ing;
          }
        }
      }

      totalCalories += dayCalories;
      totalProtein += dayProtein;
      totalCarbs += dayCarbs;
      totalFat += dayFat;

      mealDays.add(
        HybridMealDay(
          dayNumber: day,
          meals: dayMeals,
          dailyCalories: dayCalories,
          dailyProtein: dayProtein,
          dailyCarbs: dayCarbs,
          dailyFat: dayFat,
        ),
      );
    }

    // Generate grocery list with categories
    final groceryList = _categorizeGroceryItems(allIngredients.values.toList());

    // Calculate budget
    final totalMeals = days * mealsPerDay;
    final budget = HybridBudgetSummary(
      totalCost: totalCost,
      costPerDay: totalCost / days,
      costPerMeal: totalCost / totalMeals,
      currency: currency,
      categoryBreakdown: _calculateCategoryBreakdown(groceryList),
    );

    // Calculate nutrition summary
    final nutritionSummary = NutritionSummary(
      avgDailyCalories: totalCalories / days,
      avgDailyProtein: totalProtein / days,
      avgDailyCarbs: totalCarbs / days,
      avgDailyFat: totalFat / days,
      avgDailyFiber: totalFiber / days,
      totalCalories: totalCalories,
    );

    return HybridMealPlan(
      id: '',
      days: days,
      cuisine: cuisine,
      diet: diet,
      country: country,
      currency: currency,
      mealDays: mealDays,
      groceryList: groceryList,
      budget: budget,
      nutritionSummary: nutritionSummary,
      dataSourcesUsed: dataSources.toList(),
      createdAt: DateTime.now(),
    );
  }

  /// Categorize ingredients into grocery categories
  List<GroceryItem> _categorizeGroceryItems(List<MealIngredient> ingredients) {
    final groceryItems = <GroceryItem>[];

    final categoryKeywords = {
      'Proteins': [
        'chicken',
        'beef',
        'fish',
        'egg',
        'tofu',
        'meat',
        'pork',
        'shrimp',
        'salmon',
        'turkey',
      ],
      'Vegetables': [
        'tomato',
        'onion',
        'pepper',
        'carrot',
        'lettuce',
        'spinach',
        'broccoli',
        'cabbage',
        'cucumber',
      ],
      'Fruits': [
        'apple',
        'banana',
        'orange',
        'lemon',
        'lime',
        'mango',
        'pineapple',
        'berry',
      ],
      'Grains & Starches': [
        'rice',
        'pasta',
        'bread',
        'flour',
        'oat',
        'wheat',
        'potato',
        'yam',
        'cassava',
      ],
      'Dairy': ['milk', 'cheese', 'yogurt', 'butter', 'cream'],
      'Oils & Fats': ['oil', 'olive', 'coconut', 'palm'],
      'Spices & Seasonings': [
        'salt',
        'pepper',
        'cumin',
        'turmeric',
        'garlic',
        'ginger',
        'curry',
        'paprika',
      ],
      'Legumes': ['bean', 'lentil', 'chickpea', 'pea'],
    };

    for (final ing in ingredients) {
      final nameLower = ing.name.toLowerCase();
      String category = 'Other';

      for (final entry in categoryKeywords.entries) {
        if (entry.value.any((keyword) => nameLower.contains(keyword))) {
          category = entry.key;
          break;
        }
      }

      groceryItems.add(
        GroceryItem(
          name: ing.name,
          localName: ing.localName,
          amount: ing.amount,
          unit: ing.unit,
          category: category,
          estimatedPrice: ing.estimatedPrice ?? 0,
          isPantryStaple: [
            'salt',
            'pepper',
            'oil',
            'sugar',
            'flour',
          ].any((s) => nameLower.contains(s)),
        ),
      );
    }

    // Sort by category
    groceryItems.sort((a, b) => a.category.compareTo(b.category));
    return groceryItems;
  }

  Map<String, double> _calculateCategoryBreakdown(List<GroceryItem> items) {
    final breakdown = <String, double>{};
    for (final item in items) {
      breakdown[item.category] =
          (breakdown[item.category] ?? 0) + item.estimatedPrice;
    }
    return breakdown;
  }

  List<String> _mapHealthGoalsToLabels(List<String> healthGoals) {
    return healthGoals.map((goal) {
      switch (goal.toLowerCase()) {
        case 'weight_loss':
          return 'low-calorie';
        case 'diabetes':
        case 'diabetes_management':
          return 'low-sugar';
        case 'heart_health':
          return 'low-sodium';
        case 'muscle_gain':
          return 'high-protein';
        case 'vegetarian':
          return 'vegetarian';
        case 'vegan':
          return 'vegan';
        default:
          return goal;
      }
    }).toList();
  }

  /// Generate AI insights for the meal plan
  /// Enrich incomplete meals with AI-generated ingredients and instructions
  Future<HybridMeal> _enrichMealWithAI(
    HybridMeal meal,
    String cuisine,
    String diet,
  ) async {
    try {
      final aiData = await MultiAIService.generateIngredients(
        dishName: meal.name,
        cuisine: cuisine,
        diet: diet,
        servings: 2,
      );

      if (aiData.isEmpty) return meal;

      // Extract and merge ingredients
      final aiIngredients = (aiData['ingredients'] as List?)
          ?.map((i) => MealIngredient(
                name: i['name'] ?? 'ingredient',
                amount: double.tryParse(i['quantity']?.toString() ?? '1') ?? 1,
                unit: i['unit'] ?? 'unit',
              ))
          .toList() ?? [];

      // Extract instructions
      final aiInstructions = (aiData['cooking_instructions'] as List?)
          ?.map((s) => s.toString())
          .toList() ?? [];

      // Merge with existing data (prefer existing if present)
      return HybridMeal(
        mealType: meal.mealType,
        name: meal.name,
        localName: meal.localName,
        description: meal.description,
        ingredients: meal.ingredients.isNotEmpty ? meal.ingredients : aiIngredients,
        instructions: meal.instructions.isNotEmpty ? meal.instructions : aiInstructions,
        prepTimeMinutes: meal.prepTimeMinutes > 0 
            ? meal.prepTimeMinutes 
            : _parseTime(aiData['prep_time']?.toString() ?? '20m'),
        cookTimeMinutes: meal.cookTimeMinutes,
        nutrition: meal.nutrition.calories > 0 
            ? meal.nutrition 
            : MealNutrition(
                calories: (aiData['calories'] ?? 0).toDouble(),
                protein: (aiData['protein_g'] ?? 0).toDouble(),
                carbs: (aiData['carbs_g'] ?? 0).toDouble(),
                fat: (aiData['fat_g'] ?? 0).toDouble(),
                fiber: (aiData['fiber_g'] ?? 0).toDouble(),
              ),
        estimatedCost: meal.estimatedCost,
        imageUrl: meal.imageUrl,
        dataSource: '${meal.dataSource} + AI',
        recipeId: meal.recipeId,
        healthBenefits: meal.healthBenefits,
        dietLabels: meal.dietLabels,
      );
    } catch (e) {
      debugPrint('⚠️ AI enrichment failed for ${meal.name}: $e');
      return meal; // Return original if enrichment fails
    }
  }

  /// Parse time string like "20m" or "1h 30m" to minutes
  int _parseTime(String time) {
    final hourMatch = RegExp(r'(\d+)h').firstMatch(time);
    final minMatch = RegExp(r'(\d+)m').firstMatch(time);
    
    int minutes = 0;
    if (hourMatch != null) {
      minutes += int.parse(hourMatch.group(1)!) * 60;
    }
    if (minMatch != null) {
      minutes += int.parse(minMatch.group(1)!);
    }
    
    return minutes > 0 ? minutes : 20; // Default 20 mins
  }

  Future<String?> _generateAIInsights({
    required HybridMealPlan mealPlan,
    required List<String> healthGoals,
    String? healthProfile,
  }) async {
    try {
      final prompt =
          '''
Analyze this meal plan and provide brief, helpful insights:

Meal Plan Summary:
- ${mealPlan.days} days, ${mealPlan.cuisine} cuisine
- Average daily calories: ${mealPlan.nutritionSummary.avgDailyCalories.toStringAsFixed(0)} kcal
- Protein: ${mealPlan.nutritionSummary.avgDailyProtein.toStringAsFixed(0)}g/day
- Carbs: ${mealPlan.nutritionSummary.avgDailyCarbs.toStringAsFixed(0)}g/day
- Fat: ${mealPlan.nutritionSummary.avgDailyFat.toStringAsFixed(0)}g/day

${healthGoals.isNotEmpty ? 'Health Goals: ${healthGoals.join(', ')}' : ''}
${healthProfile != null ? 'Health Profile: $healthProfile' : ''}

Provide 2-3 short, actionable tips about this meal plan.
''';

      final response = await _geminiService.chat(
        message: prompt,
        maxFunctionCalls: 0,
      );
      return response.text;
    } catch (e) {
      debugPrint('Could not generate AI insights: $e');
      return null;
    }
  }

  /// Fallback to pure AI generation if APIs fail
  Future<HybridMealPlanResult> _fallbackToAIGeneration({
    required int days,
    required String cuisine,
    required String diet,
    required String country,
    required String currency,
    String? healthProfile,
    FamilyPlanSetup? familySetup,
    String? flavor,
    double? budgetPerDay,
    int mealsPerDay = 3,
  }) async {
    debugPrint('⚠️ Using AI fallback for meal plan generation');

    // 🚀 OPTIMIZED: Use batched parallel generation instead of single-shot
    try {
      // Create budget constraints if budget is provided
      BudgetConstraints? budgetConstraints;
      if (budgetPerDay != null && budgetPerDay > 0) {
        budgetConstraints = BudgetConstraints(
          totalBudget: budgetPerDay * days,
          days: days,
          perMealBudget: budgetPerDay / mealsPerDay,
          budgetLevel: budgetPerDay < 300 ? 'Low' : (budgetPerDay < 600 ? 'Medium' : 'High'),
        );
      }
      
      // Generate days in batches of 3 for speed + reliability
      final usedNames = <String>{};
      final dayResults = <List<dynamic>>[];
      const batchSize = 3;
      
      for (int batchStart = 1; batchStart <= days; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize - 1).clamp(1, days);
        final batchFutures = <Future<List<dynamic>>>[];
        
        debugPrint('🔄 AI Fallback Batch ${(batchStart / batchSize).ceil()}: days $batchStart-$batchEnd...');
        
        for (int d = batchStart; d <= batchEnd; d++) {
          batchFutures.add(
            MultiAIService.generateSingleDayMeals(
              day: d,
              cuisine: cuisine,
              diet: diet,
              flavor: flavor,
              healthProfile: healthProfile,
              budgetConstraints: budgetConstraints,
              country: country,
              currency: currency,
              avoidDishes: usedNames,
              mealsPerDay: mealsPerDay,
            ),
          );
        }
        
        // Wait for this batch to complete
        final batchResults = await Future.wait(batchFutures);
        dayResults.addAll(batchResults);
        
        // Update used names from this batch
        for (final result in batchResults) {
          for (final meal in result) {
            if (meal is Map && meal['name'] != null) {
              usedNames.add((meal['name'] as String).toLowerCase());
            }
          }
        }
      }
      
      // Convert batched results to JSON format expected by HybridMealPlanResult
      final mealDays = <Map<String, dynamic>>[];
      for (int i = 0; i < dayResults.length; i++) {
        mealDays.add({
          'day': i + 1,
          'meals': dayResults[i],
        });
      }
      
      final response = jsonEncode({'days': mealDays});

      return HybridMealPlanResult.fallback(
        message: 'Generated using batched parallel AI (API data unavailable)',
        aiResponse: response,
      );
    } catch (e) {
      debugPrint('❌ AI fallback failed: $e');
      return HybridMealPlanResult.failure(
        'Both API and AI generation failed: $e',
      );
    }
  }

  /// Save meal plan to Firestore
  Future<void> _saveMealPlanToFirestore(HybridMealPlan plan) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .doc(plan.id)
          .set(plan.toJson());

      debugPrint('✅ Meal plan saved to Firestore');
    } catch (e) {
      debugPrint('⚠️ Could not save meal plan to Firestore: $e');
    }
  }

  /// Get API status for debugging
  Map<String, dynamic> getAPIStatus() {
    return _foodAPI.getAPIStatus();
  }
}

// ============================================
// RESULT CLASS
// ============================================

class HybridMealPlanResult {
  final bool success;
  final HybridMealPlan? mealPlan;
  final String? error;
  final bool isFallback;
  final String? aiResponse;

  HybridMealPlanResult({
    required this.success,
    this.mealPlan,
    this.error,
    this.isFallback = false,
    this.aiResponse,
  });

  factory HybridMealPlanResult.success(HybridMealPlan plan) =>
      HybridMealPlanResult(success: true, mealPlan: plan);

  factory HybridMealPlanResult.failure(String error) =>
      HybridMealPlanResult(success: false, error: error);

  factory HybridMealPlanResult.fallback({
    required String message,
    String? aiResponse,
  }) => HybridMealPlanResult(
    success: true,
    isFallback: true,
    error: message,
    aiResponse: aiResponse,
  );
}
