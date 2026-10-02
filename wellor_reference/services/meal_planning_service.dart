import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'hybrid_meal_engine.dart';
import 'multi_ai_service.dart';
import 'claude_medical_ai_service.dart';
import '../providers/user_profile_provider.dart';
import '../models/family_plan_models.dart';
import '../models/subscription_tier.dart';

// ============================================
// MEAL PLAN MODELS
// ============================================

/// Main MealPlan class representing a complete meal plan
class MealPlan {
  final String id;
  final int days;
  final String cuisine;
  final String diet;
  final List<MealDay> mealDays;
  final List<String> groceryList;
  final BudgetSummary budget;
  final String country;
  final DateTime createdAt;

  const MealPlan({
    required this.id,
    required this.days,
    required this.cuisine,
    required this.diet,
    required this.mealDays,
    required this.groceryList,
    required this.budget,
    required this.country,
    required this.createdAt,
  });

  /// Alias for budget to support legacy code
  BudgetSummary get budgetSummary => budget;

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      days: json['days'] ?? 1,
      cuisine: json['cuisine'] ?? 'Universal',
      diet: json['diet'] ?? 'Balanced',
      mealDays: (json['mealDays'] as List?)?.map((d) => MealDay.fromJson(d)).toList() ??
          (json['plan'] as List?)?.map((d) => MealDay.fromJson(d)).toList() ??
          [],
      groceryList: List<String>.from(json['groceryList'] ?? json['grocery_list'] ?? []),
      budget: BudgetSummary.fromJson(json['budget'] ?? json['budget_summary'] ?? {}),
      country: json['country'] ?? 'Global',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'days': days,
    'cuisine': cuisine,
    'diet': diet,
    'mealDays': mealDays.map((d) => d.toJson()).toList(),
    'groceryList': groceryList,
    'budget': budget.toJson(),
    'country': country,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Represents a single day in a meal plan
class MealDay {
  final int dayNumber;
  final List<Meal> meals;
  final double totalCalories;
  final double totalCost;

  const MealDay({
    required this.dayNumber,
    required this.meals,
    this.totalCalories = 0,
    this.totalCost = 0,
  });

  factory MealDay.fromJson(Map<String, dynamic> json) {
    final meals = (json['meals'] as List?)?.map((m) => Meal.fromJson(m)).toList() ?? [];
    return MealDay(
      dayNumber: json['dayNumber'] ?? json['day_number'] ?? json['day'] ?? 1,
      meals: meals,
      totalCalories: Meal._toDouble(json['totalCalories'] ?? json['total_calories']) > 0
          ? Meal._toDouble(json['totalCalories'] ?? json['total_calories'])
          : meals.fold<double>(0, (sum, m) => sum + m.calories),
      totalCost: Meal._toDouble(json['totalCost'] ?? json['total_cost']) > 0
          ? Meal._toDouble(json['totalCost'] ?? json['total_cost'])
          : meals.fold<double>(0, (sum, m) => sum + m.estimatedCost),
    );
  }

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'meals': meals.map((m) => m.toJson()).toList(),
    'totalCalories': totalCalories,
    'totalCost': totalCost,
  };
}

/// Represents a single meal
class Meal {
  final String type;
  final String name;
  final String localName;
  final String recipe;
  final List<MealIngredient> ingredients;
  final List<String> steps;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int glycemicIndex;
  final String prepTime;
  final String servingSize;
  final double estimatedCost;
  final String youtubeLink;

  const Meal({
    required this.type,
    required this.name,
    this.localName = '',
    this.recipe = '',
    required this.ingredients,
    required this.steps,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.glycemicIndex = 55,
    this.prepTime = '30 mins',
    this.servingSize = '1 serving',
    this.estimatedCost = 0,
    this.youtubeLink = '',
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    // Parse estimated cost with fallback logic
    double cost = _toDouble(json['estimatedCost'] ?? json['estimated_cost']);
    
    // Parse steps with fallback to default instructions if missing
    List<String> steps = [];
    if (json['steps'] != null && (json['steps'] as List).isNotEmpty) {
      steps = List<String>.from(json['steps']);
    } else if (json['instructions'] != null && (json['instructions'] as List).isNotEmpty) {
      steps = List<String>.from(json['instructions']);
    } else if (json['cooking_instructions'] != null && (json['cooking_instructions'] as List).isNotEmpty) {
      steps = List<String>.from(json['cooking_instructions']);
    } else {
      // AI failed to provide steps - generate basic cooking instructions
      final dishName = json['name'] ?? 'this dish';
      debugPrint('⚠️ WARNING: Meal "$dishName" has no steps - generating defaults');
      steps = _generateDefaultSteps(dishName, json['type']?.toString() ?? 'Meal');
    }
    
    // Debug logging for cost
    if (cost == 0) {
      debugPrint('⚠️ WARNING: Meal "${json['name']}" (${json['type']}) has estimated_cost = 0 or missing');
      // Set a minimal default cost based on meal type (using Kenya minimum budget as reference)
      final mealType = (json['type'] ?? '').toString().toLowerCase();
      if (mealType.contains('breakfast')) {
        cost = 40; // 20% of 200 KES daily minimum
      } else if (mealType.contains('lunch')) {
        cost = 80; // 40% of 200 KES daily minimum
      } else if (mealType.contains('dinner')) {
        cost = 80; // 40% of 200 KES daily minimum
      } else {
        cost = 70; // Generic default
      }
      debugPrint('   → Using default cost: $cost KES');
    }
    
    return Meal(
      type: json['type'] ?? json['mealType'] ?? 'Meal',
      name: json['name'] ?? 'Dish',
      localName: json['localName'] ?? json['local_name'] ?? '',
      recipe: json['recipe'] ?? json['description'] ?? '',
      ingredients: (json['ingredients'] as List?)
          ?.map((i) => i is String 
              ? MealIngredient(name: i, amount: 1, unit: '') 
              : MealIngredient.fromJson(i))
          .toList() ?? [],
      steps: steps,
      calories: _toInt(json['calories']),
      protein: _toDouble(json['protein'] ?? json['protein_g']),
      carbs: _toDouble(json['carbs'] ?? json['carbs_g']),
      fat: _toDouble(json['fat'] ?? json['fat_g']),
      fiber: _toDouble(json['fiber'] ?? json['fiber_g']),
      glycemicIndex: _toInt(json['glycemicIndex'] ?? json['gi'] ?? json['gi_index'] ?? 55),
      prepTime: json['prepTime'] ?? json['prep_time'] ?? '30 mins',
      servingSize: json['servingSize'] ?? json['serving_size'] ?? '1 serving',
      estimatedCost: cost,
      youtubeLink: json['youtubeLink'] ?? json['youtube_link'] ?? '',
    );
  }

  /// Safely convert any value to int
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Safely convert any value to double
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Generate default cooking steps when AI fails to provide them
  static List<String> _generateDefaultSteps(String dishName, String mealType) {
    // Generic cooking instructions that work for most dishes
    return [
      'Gather all ingredients listed above and prepare your cooking equipment (pans, pots, cutting board, knife).',
      'Wash and prepare fresh ingredients: rinse vegetables, dice onions, mince garlic, and cut proteins into appropriate sizes.',
      'Heat 2-3 tablespoons of cooking oil in a large pan over medium-high heat for 1-2 minutes until hot.',
      'Add aromatics (onions, garlic, ginger if available) and sauté for 2-3 minutes until fragrant and translucent.',
      'Add main ingredients and seasonings, then cook according to dish requirements (stir-fry for 8-10 minutes, simmer for 15-20 minutes, or bake at 180°C/350°F).',
      'Taste and adjust seasoning with salt, pepper, or spices as needed. Continue cooking until ingredients are tender and fully cooked through.',
      'Remove from heat, let rest for 2-3 minutes, then plate the dish. Garnish with fresh herbs if desired and serve hot.',
    ];
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'localName': localName,
    'recipe': recipe,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'glycemicIndex': glycemicIndex,
    'prepTime': prepTime,
    'servingSize': servingSize,
    'estimatedCost': estimatedCost,
    'youtubeLink': youtubeLink,
  };
}

/// Represents an ingredient in a meal
class MealIngredient {
  final String name;
  final double amount;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const MealIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  /// Alias for amount to support legacy code
  double get quantity => amount;

  factory MealIngredient.fromJson(Map<String, dynamic> json) {
    return MealIngredient(
      name: json['name'] ?? 'Ingredient',
      amount: Meal._toDouble(json['amount'] ?? json['quantity'] ?? 1),
      unit: json['unit'] ?? 'g',
      calories: Meal._toDouble(json['calories']),
      protein: Meal._toDouble(json['protein']),
      carbs: Meal._toDouble(json['carbs']),
      fat: Meal._toDouble(json['fat']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

/// Budget summary for a meal plan
class BudgetSummary {
  final double totalCost;
  final double costPerDay;
  final double costPerMeal;
  final String currency;
  final String budgetRange;

  const BudgetSummary({
    this.totalCost = 0,
    this.costPerDay = 0,
    this.costPerMeal = 0,
    this.currency = 'USD',
    this.budgetRange = 'Not Set',
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      totalCost: Meal._toDouble(json['totalCost'] ?? json['total_cost']),
      costPerDay: Meal._toDouble(json['costPerDay'] ?? json['cost_per_day']),
      costPerMeal: Meal._toDouble(json['costPerMeal'] ?? json['cost_per_meal']),
      currency: json['currency'] ?? 'USD',
      budgetRange: json['budgetRange'] ?? json['budget_range'] ?? 'Not Set',
    );
  }

  Map<String, dynamic> toJson() => {
    'totalCost': totalCost,
    'costPerDay': costPerDay,
    'costPerMeal': costPerMeal,
    'currency': currency,
    'budgetRange': budgetRange,
  };

  /// Formatted total cost with currency symbol
  String get formattedTotalCost {
    return '${_getCurrencySymbol()}${totalCost.toStringAsFixed(2)}';
  }

  /// Formatted daily cost with currency symbol
  String get formattedDailyCost {
    return '${_getCurrencySymbol()}${costPerDay.toStringAsFixed(2)}';
  }

  /// Alias for backward compatibility (typo in UI)
  String get formattedDailyost => formattedDailyCost;

  /// Formatted per meal cost with currency symbol
  String get formattedPerMealCost {
    return '${_getCurrencySymbol()}${costPerMeal.toStringAsFixed(2)}';
  }

  String _getCurrencySymbol() {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'NGN':
        return '₦';
      case 'KES':
        return 'KSh';
      case 'GHS':
        return 'GH₵';
      case 'ZAR':
        return 'R';
      case 'INR':
        return '₹';
      case 'JPY':
      case 'CNY':
        return '¥';
      default:
        return '$currency ';
    }
  }
}

// ============================================
// CONCURRENT MEAL PLAN ORCHESTRATOR
// ============================================

/// Micro-request descriptor for a single Day×MealType slot.
class _MealSlot {
  final int day;
  final String mealType;
  _MealSlot(this.day, this.mealType);
}

/// Orchestrates parallel micro-requests (days × 3 meals) and
/// aggregates the results into a single [MealPlan] in under 15 seconds.
/// 
/// ⚠️ DEPRECATED APPROACH: This uses Gemini Flash for speed.
/// 
/// For production, use MealPlanningService.generateMealPlan() which uses
/// Claude 3.5 Sonnet exclusively for maximum safety and accuracy.
/// 
/// This orchestrator remains available for legacy compatibility but should
/// not be used for new implementations.
class ConcurrentMealOrchestrator {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _modelId = 'gemini-2.5-flash';

  static String get _apiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? '';

  // ── public entry point ──────────────────────────────────────────

  /// Build an array of [days]×3 [_MealSlot]s, fire them in parallel batches,
  /// and aggregate the JSON results into a finished [MealPlan].
  static Future<MealPlan> generate({
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    String? healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
  }) async {
    final sw = Stopwatch()..start();

    // 1. Build the micro-request descriptors (days × 3 meals)
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
    final slots = <_MealSlot>[
      for (int d = 1; d <= days; d++)
        for (final type in mealTypes) _MealSlot(d, type),
    ];

    // 2. Track used dish names across all batches to avoid repeats
    final usedNames = <String>{};

    // 3. Fire requests in small batches of 3 to avoid API rate limiting
    final allMeals = <String, Meal>{}; // key = "day:type"
    const batchSize = 3;
    for (int i = 0; i < slots.length; i += batchSize) {
      final batch = slots.sublist(i, (i + batchSize).clamp(0, slots.length));
      final batchResults = await Future.wait(
        batch.map((slot) => _generateSingleMeal(
          slot: slot,
          cuisine: cuisine,
          diet: diet,
          flavor: flavor,
          cookingTime: cookingTime,
          healthProfile: healthProfile,
          budgetConstraints: budgetConstraints,
          country: country,
          currency: currency,
          usedNames: usedNames,
        )),
      );
      for (final entry in batchResults) {
        if (entry != null) {
          allMeals[entry.key] = entry.value;
          usedNames.add(entry.value.name.toLowerCase());
        }
      }
    }

    // 4. Retry any failed meals once (in batches of 3)
    final failedSlots = slots.where(
      (s) => !allMeals.containsKey('${s.day}:${s.mealType}'),
    ).toList();
    if (failedSlots.isNotEmpty) {
      debugPrint('🔄 Retrying ${failedSlots.length} failed meals...');
      for (int i = 0; i < failedSlots.length; i += batchSize) {
        final batch = failedSlots.sublist(i, (i + batchSize).clamp(0, failedSlots.length));
        final retryResults = await Future.wait(
          batch.map((slot) => _generateSingleMeal(
            slot: slot,
            cuisine: cuisine,
            diet: diet,
            flavor: flavor,
            cookingTime: cookingTime,
            healthProfile: healthProfile,
            budgetConstraints: budgetConstraints,
            country: country,
            currency: currency,
            usedNames: usedNames,
          )),
        );
        for (final entry in retryResults) {
          if (entry != null) {
            allMeals[entry.key] = entry.value;
            usedNames.add(entry.value.name.toLowerCase());
          }
        }
      }
    }

    sw.stop();
    debugPrint(
      '⚡ Concurrent orchestrator: ${allMeals.length}/${slots.length} meals '
      'in ${sw.elapsedMilliseconds}ms',
    );

    // 4. Aggregate into final MealPlan
    return _aggregate(
      allMeals: allMeals,
      days: days,
      cuisine: cuisine,
      diet: diet,
      country: country,
      currency: currency,
      budgetConstraints: budgetConstraints,
    );
  }

  // ── micro-request: one meal ─────────────────────────────────────

  static Future<MapEntry<String, Meal>?> _generateSingleMeal({
    required _MealSlot slot,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    String? healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    required Set<String> usedNames,
  }) async {
    final key = '${slot.day}:${slot.mealType}';
    final avoidList =
        usedNames.isNotEmpty ? usedNames.take(30).join(', ') : 'none';

    final prompt = 'Generate ONE $cuisine ${slot.mealType.toLowerCase()} recipe. Diet: $diet.${flavor != null ? ' Flavor: $flavor.' : ''}${cookingTime != null ? ' Max time: $cookingTime.' : ''} Country: $country. Avoid: $avoidList. Return JSON: {"type":"${slot.mealType}","name":"...","local_name":"...","recipe":"...","ingredients":[{"name":"...","amount":2,"unit":"cups"}],"steps":["Step 1","Step 2"],"calories":350,"protein":15,"carbs":45,"fat":12,"fiber":5,"prepTime":"20m","estimatedCost":150,"youtubeLink":"https://www.youtube.com/results?search_query=Dish+Name+recipe"}';

    try {
      final url = Uri.parse('$_baseUrl/$_modelId:generateContent?key=$_apiKey');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.9,
                'topP': 0.95,
                'topK': 40,
                'maxOutputTokens': 2048,
                'response_mime_type': 'application/json',
              }
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        if (text.isEmpty) return null;

        Map<String, dynamic> mealJson;
        try {
          mealJson = jsonDecode(text) as Map<String, dynamic>;
        } on FormatException {
          // Repair truncated JSON from micro-request
          mealJson = jsonDecode(MealPlanningService._repairTruncatedJson(text)) as Map<String, dynamic>;
        }
        // Force the correct type in case the model changed it
        mealJson['type'] = slot.mealType;
        return MapEntry(key, Meal.fromJson(mealJson));
      } else {
        debugPrint('⚠️ Micro-request $key failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Micro-request $key error: $e');
      return null;
    }
  }

  // ── aggregator ──────────────────────────────────────────────────

  static MealPlan _aggregate({
    required Map<String, Meal> allMeals,
    required int days,
    required String cuisine,
    required String diet,
    required String country,
    required String currency,
    BudgetConstraints? budgetConstraints,
  }) {
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
    final mealDays = <MealDay>[];

    for (int d = 1; d <= days; d++) {
      final dayMeals = <Meal>[];
      for (final type in mealTypes) {
        final meal = allMeals['$d:$type'];
        if (meal != null) {
          dayMeals.add(meal);
        }
      }
      mealDays.add(MealDay(
        dayNumber: d,
        meals: dayMeals,
        totalCalories:
            dayMeals.fold<double>(0, (s, m) => s + m.calories),
        totalCost:
            dayMeals.fold<double>(0, (s, m) => s + m.estimatedCost),
      ));
    }

    // Build a de-duplicated grocery list from all ingredients
    final ingredientMap = <String, String>{}; // name → "amount unit"
    for (final meal in allMeals.values) {
      for (final ing in meal.ingredients) {
        final key = ing.name.toLowerCase();
        if (!ingredientMap.containsKey(key)) {
          ingredientMap[key] =
              '${ing.amount} ${ing.unit} ${ing.name}'.trim();
        }
      }
    }
    final groceryList = ingredientMap.values.toList()..sort();

    // Compute budget summary
    final totalCost =
        mealDays.fold<double>(0, (s, d) => s + d.totalCost);
    final costPerDay = days > 0 ? totalCost / days : 0.0;
    final totalMeals = mealDays.fold<int>(0, (s, d) => s + d.meals.length);
    final costPerMeal = totalMeals > 0 ? totalCost / totalMeals : 0.0;

    return MealPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      days: days,
      cuisine: cuisine,
      diet: diet,
      mealDays: mealDays,
      groceryList: groceryList,
      budget: BudgetSummary(
        totalCost: totalCost,
        costPerDay: costPerDay,
        costPerMeal: costPerMeal,
        currency: currency,
        budgetRange: budgetConstraints?.budgetLevel ?? _inferBudgetRange(costPerDay),
      ),
      country: country,
      createdAt: DateTime.now(),
    );
  }

  static String _inferBudgetRange(double costPerDay) {
    if (costPerDay < 10) return 'Low';
    if (costPerDay < 25) return 'Medium';
    return 'High';
  }
}

// ============================================
// MEAL PLANNING SERVICE
// ============================================

class MealPlanningService {
  static final HybridMealEngine _hybridEngine = HybridMealEngine();

  /// Generate a diverse meal plan using concurrent micro-requests,
  /// falling back to hybrid engine and then AI if needed.
  static Future<MealPlan> generateMealPlan({
    required UserProfile userProfile,
    FamilyPlanSetup? familyPlanSetup,
    BudgetConstraints? budgetConstraints,
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    String country = 'United States',
    String currency = 'USD',
    SubscriptionTier? userTier,
    int mealsPerDay = 3,
  }) async {
    try {
      debugPrint('🚀 Generating diverse meal plan: $cuisine, $diet, $days days');
      debugPrint('🎯 Flavor: $flavor, Cooking time: $cookingTime');
      
      // Build health profile from user data
      final healthProfile = _buildHealthProfile(userProfile);

      // ── PRIMARY: Direct AI generation (fastest, single request) ──
      // Monolithic AI generates the full plan in one call (~15s)
      // Retry up to 2 times before falling back to hybrid engine
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final aiPlan = await _generateWithAI(
            days: days,
            cuisine: cuisine,
            diet: diet,
            flavor: flavor,
            cookingTime: cookingTime,
            healthProfile: healthProfile,
            budgetConstraints: budgetConstraints,
            country: country,
            currency: currency,
            userTier: userTier,
            mealsPerDay: mealsPerDay,
          );
          return aiPlan;
        } catch (e) {
          debugPrint('⚠️ AI generation attempt $attempt/2 failed: $e');
          if (attempt < 2) {
            debugPrint('🔄 Retrying AI generation...');
          } else {
            debugPrint('⚠️ All AI attempts failed, trying hybrid engine...');
          }
        }
      }

      // ── FALLBACK: Hybrid engine (API + AI) ──────────────────────
      try {
        int? maxCookingMinutes;
        if (cookingTime != null) {
          final timeMatch = RegExp(r'(\d+)').firstMatch(cookingTime);
          if (timeMatch != null) {
            maxCookingMinutes = int.tryParse(timeMatch.group(1) ?? '');
          }
        }
        
        final hybridResult = await _hybridEngine.generateMealPlan(
          days: days,
          cuisine: cuisine,
          diet: diet,
          flavor: flavor,
          maxCookingTimeMinutes: maxCookingMinutes,
          country: country,
          currency: currency,
          budgetPerDay: budgetConstraints?.dailyBudget,
          healthProfile: healthProfile,
          mealsPerDay: mealsPerDay,
        );
        
        if (hybridResult.success && hybridResult.mealPlan != null) {
          final plan = hybridResult.mealPlan!;
          debugPrint('✅ Hybrid engine succeeded with ${plan.dataSourcesUsed.join(", ")}');
          return _convertHybridToMealPlan(plan);
        } else if (hybridResult.isFallback && hybridResult.aiResponse != null) {
          debugPrint('✅ Hybrid engine AI fallback — parsing response directly');
          dynamic decoded;
          try {
            decoded = jsonDecode(hybridResult.aiResponse!);
          } on FormatException {
            debugPrint('⚠️ Hybrid AI JSON truncated, attempting repair...');
            decoded = jsonDecode(_repairTruncatedJson(hybridResult.aiResponse!));
          }
          final Map<String, dynamic> json = decoded is List
              ? {'days': decoded, 'grocery_list': [], 'budget_summary': {}}
              : decoded as Map<String, dynamic>;
          return _parseAIResponse(json, days, cuisine, diet, country, currency);
        } else {
          throw Exception(hybridResult.error ?? 'Unknown hybrid engine error');
        }
      } catch (e) {
        debugPrint('⚠️ Hybrid engine failed: $e');
        throw Exception('Failed to generate meal plan: $e');
      }
    } catch (e) {
      debugPrint('❌ All generation methods failed: $e');
      throw Exception('Failed to generate meal plan: $e');
    }
  }

  /// Build health profile string from user profile
  static String _buildHealthProfile(UserProfile userProfile) {
    final parts = <String>[];
    
    if (userProfile.weight != null) parts.add('Weight: ${userProfile.weight}kg');
    if (userProfile.height != null) parts.add('Height: ${userProfile.height}cm');
    if (userProfile.age != null) parts.add('Age: ${userProfile.age}');
    if (userProfile.gender != null) parts.add('Gender: ${userProfile.gender}');
    if (userProfile.activityLevel != null) parts.add('Activity: ${userProfile.activityLevel}');
    if (userProfile.healthGoals?.isNotEmpty == true) {
      parts.add('Goals: ${userProfile.healthGoals!.join(", ")}');
    }
    final diseases = userProfile.diseases;
    if (diseases.isNotEmpty) {
      parts.add('Conditions: ${diseases.join(", ")}');
      final glycemicFocus = diseases.any(
        (x) =>
            x.toLowerCase().contains('diabet') ||
            x.toLowerCase().contains('insulin') ||
            x.toLowerCase().contains('glucose'),
      );
      if (glycemicFocus) {
        parts.add(
          'Metabolic meal-plan focus: favor lower-GI foods, steady complex carbs with fiber, '
          'lean protein each meal, avoid extreme single-meal carb loads; practical portions for glucose stability.',
        );
      }
    }

    return parts.isEmpty ? 'General healthy adult' : parts.join('; ');
  }

  /// Convert HybridMealPlan to MealPlan
  static MealPlan _convertHybridToMealPlan(HybridMealPlan hybrid) {
    return MealPlan(
      id: hybrid.id,
      days: hybrid.days,
      cuisine: hybrid.cuisine,
      diet: hybrid.diet,
      country: hybrid.country,
      createdAt: hybrid.createdAt,
      mealDays: hybrid.mealDays.map((hd) => MealDay(
        dayNumber: hd.dayNumber,
        meals: hd.meals.map((hm) => Meal(
          type: hm.mealType,
          name: hm.name,
          localName: hm.localName ?? '',
          recipe: hm.description ?? '',
          ingredients: hm.ingredients.map((hi) => MealIngredient(
            name: hi.name,
            amount: hi.amount,
            unit: hi.unit,
          )).toList(),
          steps: hm.instructions,
          calories: hm.nutrition.calories.toInt(),
          protein: hm.nutrition.protein,
          carbs: hm.nutrition.carbs,
          fat: hm.nutrition.fat,
          fiber: hm.nutrition.fiber,
          glycemicIndex: 55, // Default GI value
          prepTime: '${hm.prepTimeMinutes} mins',
          servingSize: '1 serving',
          estimatedCost: hm.estimatedCost,
          youtubeLink: _generateYoutubeLink(hm.name, hybrid.cuisine),
        )).toList(),
        totalCalories: hd.dailyCalories,
        totalCost: hd.meals.fold<double>(0, (sum, m) => sum + m.estimatedCost),
      )).toList(),
      groceryList: hybrid.groceryList.map((g) => '${g.amount} ${g.unit} ${g.name}').toList(),
      budget: BudgetSummary(
        totalCost: hybrid.budget.totalCost,
        costPerDay: hybrid.budget.costPerDay,
        costPerMeal: hybrid.budget.costPerMeal,
        currency: hybrid.currency,
        budgetRange: _inferBudgetRange(hybrid.budget.costPerDay),
      ),
    );
  }

  /// Infer budget range from cost per day
  static String _inferBudgetRange(double costPerDay) {
    if (costPerDay < 10) return 'Low';
    if (costPerDay < 25) return 'Medium';
    return 'High';
  }

  /// Generate meal plan using AI
  static Future<MealPlan> _generateWithAI({
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    required String healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    SubscriptionTier? userTier,
    int mealsPerDay = 3,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint('⚡ Generating meal plan with FAST batched parallel AI ($days days, $mealsPerDay meals/day)...');

    // 🚀 OPTIMIZED: Process in batches of 3 days for speed + reliability
    // Prevents API rate limits and ensures sub-15 second generation
    final usedNames = <String>{};
    final dayResults = <List<dynamic>>[];
    const batchSize = 3;
    
    for (int batchStart = 1; batchStart <= days; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize - 1).clamp(1, days);
      final batchFutures = <Future<List<dynamic>>>[];
      
      debugPrint('🔄 Batch ${(batchStart / batchSize).ceil()}: Generating days $batchStart-$batchEnd in parallel...');
      
      for (int d = batchStart; d <= batchEnd; d++) {
        batchFutures.add(
          MultiAIService.generateSingleDayMeals(
            day: d,
            cuisine: cuisine,
            diet: diet,
            flavor: flavor,
            cookingTime: cookingTime,
            healthProfile: healthProfile,
            budgetConstraints: budgetConstraints,
            country: country,
            currency: currency,
            avoidDishes: usedNames,
            userTier: userTier,
            mealsPerDay: mealsPerDay,
          ),
        );
      }
      
      // Wait for this batch to complete before starting next
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
      
      debugPrint('✅ Batch complete: ${batchResults.length} days in ${sw.elapsedMilliseconds}ms');
    }

    // Aggregate into MealDays
    final mealTypes = SubscriptionQuotas.mealTypesForCount(mealsPerDay);
    final mealDays = <MealDay>[];
    for (int i = 0; i < dayResults.length; i++) {
      final rawMeals = dayResults[i];
      final meals = <Meal>[];
      
      for (int j = 0; j < mealTypes.length; j++) {
        if (j < rawMeals.length) {
          final m = Map<String, dynamic>.from(rawMeals[j] as Map<String, dynamic>);
          // Force correct meal type by position
          m['type'] = mealTypes[j];
          meals.add(Meal.fromJson(m));
        } else {
          // AI returned fewer meals — fill with placeholder
          meals.add(Meal(
            type: mealTypes[j],
            name: '${mealTypes[j]} - Day ${i + 1}',
            localName: '',
            ingredients: const [],
            steps: const ['Recipe not generated'],
            calories: mealTypes[j] == 'Breakfast' ? 300 : 500,
            protein: 15,
            carbs: 40,
            fat: 10,
            fiber: 3,
            glycemicIndex: 55,
            estimatedCost: budgetConstraints != null
                ? (mealTypes[j] == 'Breakfast'
                    ? budgetConstraints.dailyBudget * 0.20
                    : budgetConstraints.dailyBudget * 0.40)
                : 100,
          ));
        }
      }
      
      for (final m in meals) {
        usedNames.add(m.name.toLowerCase());
      }
      mealDays.add(MealDay(
        dayNumber: i + 1,
        meals: meals,
        totalCalories: meals.fold<double>(0, (s, m) => s + m.calories),
        totalCost: meals.fold<double>(0, (s, m) => s + m.estimatedCost),
      ));
    }

    // Build grocery list from all ingredients
    final ingredientMap = <String, String>{};
    for (final day in mealDays) {
      for (final meal in day.meals) {
        for (final ing in meal.ingredients) {
          final key = ing.name.toLowerCase();
          if (!ingredientMap.containsKey(key)) {
            ingredientMap[key] = '${ing.amount} ${ing.unit} ${ing.name}'.trim();
          }
        }
      }
    }
    final groceryList = ingredientMap.values.toList()..sort();

    // Compute budget — use the user's actual budget if available, not AI-generated costs
    final double totalCost;
    final double costPerDay;
    final double costPerMeal;
    if (budgetConstraints != null) {
      // Use user's budget: totalBudget is already (weekly/7)*days from planner_screen
      totalCost = budgetConstraints.totalBudget;
      costPerDay = budgetConstraints.dailyBudget;
      costPerMeal = budgetConstraints.perMealBudget;
    } else {
      // No budget set — compute from AI-generated estimated_cost values
      totalCost = mealDays.fold<double>(0, (s, d) => s + d.totalCost);
      costPerDay = days > 0 ? totalCost / days : 0.0;
      final totalMeals = mealDays.fold<int>(0, (s, d) => s + d.meals.length);
      costPerMeal = totalMeals > 0 ? totalCost / totalMeals : 0.0;
    }
    final totalMeals = mealDays.fold<int>(0, (s, d) => s + d.meals.length);

    sw.stop();
    debugPrint('✅ Parallel AI completed: ${mealDays.length} days, '
        '${totalMeals} meals in ${sw.elapsedMilliseconds}ms');

    return MealPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      days: days,
      cuisine: cuisine,
      diet: diet,
      mealDays: mealDays,
      groceryList: groceryList,
      budget: BudgetSummary(
        totalCost: totalCost,
        costPerDay: costPerDay,
        costPerMeal: costPerMeal,
        currency: currency,
        budgetRange: budgetConstraints?.budgetLevel ?? _inferBudgetRange(costPerDay),
      ),
      country: country,
      createdAt: DateTime.now(),
    );
  }

  /// Repair truncated JSON by closing unclosed strings, arrays, and objects
  /// Uses a stack to ensure correct nesting order.
  static String _repairTruncatedJson(String json) {
    var repaired = json.trimRight();
    
    // Remove trailing comma if present
    if (repaired.endsWith(',')) {
      repaired = repaired.substring(0, repaired.length - 1);
    }

    // Use a stack to track the correct closing order
    final stack = <String>[]; // will contain '{' or '['
    bool inString = false;
    bool escaped = false;
    
    for (int i = 0; i < repaired.length; i++) {
      final c = repaired[i];
      if (escaped) { escaped = false; continue; }
      if (c == '\\') { escaped = true; continue; }
      if (c == '"') { inString = !inString; continue; }
      if (inString) continue;
      if (c == '{') stack.add('{');
      else if (c == '[') stack.add('[');
      else if (c == '}' && stack.isNotEmpty && stack.last == '{') stack.removeLast();
      else if (c == ']' && stack.isNotEmpty && stack.last == '[') stack.removeLast();
    }
    
    // If we're inside a string, close it
    if (inString) {
      repaired += '"';
    }
    
    // Truncate at the last complete key-value pair
    // Find and remove any dangling incomplete value after the last complete one
    final danglingPatterns = [
      RegExp(r',\s*"[^"]*"\s*:\s*$'),           // "key":
      RegExp(r',\s*"[^"]*"\s*$'),               // ,"key"
      RegExp(r',\s*"[^"]*$'),                    // ,"incompl
      RegExp(r',\s*$'),                            // trailing comma
    ];
    for (final pattern in danglingPatterns) {
      repaired = repaired.replaceFirst(pattern, '');
    }
    
    repaired = repaired.trimRight();
    if (repaired.endsWith(',')) {
      repaired = repaired.substring(0, repaired.length - 1);
    }
    
    // Close unclosed brackets and braces in correct reverse order
    // Re-scan after truncation to get accurate stack
    final closeStack = <String>[];
    inString = false;
    escaped = false;
    for (int i = 0; i < repaired.length; i++) {
      final c = repaired[i];
      if (escaped) { escaped = false; continue; }
      if (c == '\\') { escaped = true; continue; }
      if (c == '"') { inString = !inString; continue; }
      if (inString) continue;
      if (c == '{') closeStack.add('}');
      else if (c == '[') closeStack.add(']');
      else if (c == '}' && closeStack.isNotEmpty && closeStack.last == '}') closeStack.removeLast();
      else if (c == ']' && closeStack.isNotEmpty && closeStack.last == ']') closeStack.removeLast();
    }
    
    // Close in reverse order (innermost first)
    final closers = closeStack.reversed.join();
    repaired += closers;
    
    debugPrint('✅ JSON repaired (appended: $closers)');
    return repaired;
  }

  /// Parse AI response to MealPlan
  static MealPlan _parseAIResponse(
    Map<String, dynamic> json,
    int days,
    String cuisine,
    String diet,
    String country,
    String currency,
  ) {
    final daysData = json['days'] as List? ?? [];
    final List<MealDay> mealDays = [];
    
    for (int i = 0; i < daysData.length; i++) {
      final dayJson = daysData[i];
      final mealsJson = dayJson['meals'] as List? ?? [];
      final List<Meal> meals = [];
      
      for (final mealJson in mealsJson) {
        meals.add(Meal.fromJson(mealJson));
      }
      
      mealDays.add(MealDay(
        dayNumber: dayJson['day'] ?? (i + 1),
        meals: meals,
        totalCalories: meals.fold<double>(0, (sum, m) => sum + m.calories),
        totalCost: meals.fold<double>(0, (sum, m) => sum + m.estimatedCost),
      ));
    }
    
    // Parse grocery list
    final groceryJson = json['grocery_list'] as List? ?? [];
    final groceryList = groceryJson.map((g) {
      if (g is String) return g;
      if (g is Map) {
        final item = g['item'] ?? g['name'] ?? 'Item';
        final qty = g['quantity'] ?? 1;
        final unit = g['unit'] ?? '';
        return '$qty $unit $item'.trim();
      }
      return g.toString();
    }).toList();
    
    // Parse budget
    final budgetJson = json['budget_summary'] ?? {};
    final budget = BudgetSummary(
      totalCost: (budgetJson['total_cost'] ?? 0).toDouble(),
      costPerDay: (budgetJson['cost_per_day'] ?? 0).toDouble(),
      costPerMeal: (budgetJson['cost_per_meal'] ?? 0).toDouble(),
      currency: budgetJson['currency'] ?? currency,
      budgetRange: budgetJson['budget_range'] ?? 'AI Generated',
    );
    
    return MealPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      days: days,
      cuisine: cuisine,
      diet: diet,
      mealDays: mealDays,
      groceryList: groceryList.cast<String>(),
      budget: budget,
      country: country,
      createdAt: DateTime.now(),
    );
  }

  /// Generate YouTube search link for a meal
  static String _generateYoutubeLink(String mealName, String cuisine) {
    final cleanName = mealName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final searchQuery = '$cleanName $cuisine recipe'.replaceAll(' ', '+');
    return 'https://youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}';
  }
}
