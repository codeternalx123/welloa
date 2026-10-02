import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../models/family_plan_models.dart';
import '../models/subscription_tier.dart';
import 'claude_medical_ai_service.dart';

/// UNICORN GRADE: AI Cognitive Orchestrator for Meal Planning.
/// 
/// 🎯 TIER-BASED AI ROUTING:
/// - FREE tier: Gemini 2.5 Flash (cost-effective, good for testing)
/// - STARTER/PREMIUM/ULTRA tiers: Claude Sonnet 3.5 (clinical-grade, ±3-5% accuracy)
/// 
/// WHY THE SPLIT:
/// - Gemini: Fast, cheap, good for casual users exploring the app
/// - Claude: Medical-grade accuracy for paid subscribers who need clinical precision
/// 
/// 🔒 MEDICAL SAFETY (Claude only):
/// - Input validation for contraindications
/// - Audit logging for all meal generations
/// - Evidence-based nutrition guidelines
/// - Drug-food interaction checking
/// 
/// ⚡ SPEED OPTIMIZATIONS (Target: <15 seconds for 7-day plans):
/// 1. Batched parallel processing: 3 days at a time instead of all at once
/// 2. Increased tokens: 6144 per day, 12288 for full plans (faster completion)
/// 3. Optimized temperature: 0.7 (reduced from 0.85) for faster generation
/// 4. Realistic timeouts: 45s for single day (fast model), 90s for full plans (complex model)
/// 5. Parallel API fetching: 3s timeout per API (was 10s sequential)
/// 
/// 🎯 RECOMMENDED USAGE:
/// - Use generateSingleDayMeals() in batches for fastest results (target: 12-15s per batch of 3 days)
/// - Use generateMealPlan() only for single-shot full plans (slower, 90s timeout)
/// 
/// ⏱️ EXPECTED TIMING:
/// - 3-day plan: ~12-15 seconds (1 batch of 3 days in parallel)
/// - 5-day plan: ~20-25 seconds (2 batches: 3 days + 2 days)
/// - 7-day plan: ~25-30 seconds (3 batches: 3 days + 3 days + 1 day)
/// 
/// Features: Native JSON Mode, Comprehensive Health Safety, Evidence-Based Nutrition
class MultiAIService {
  static final MultiAIService _instance = MultiAIService._internal();
  factory MultiAIService() => _instance;
  MultiAIService._internal();

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _modelId = 'gemini-2.5-flash';
  static const String _complexModelId = 'gemini-2.5-flash';
  
  String get _apiKey => EnvConfig.geminiApiKey;
  String get _spoonacularKey => EnvConfig.get('SPOONACULAR_API_KEY');

  // ============================================
  // MAIN MEAL PLAN GENERATION
  // ============================================

  /// Generate a complete meal plan
  /// 
  /// 🎯 TIER-BASED ROUTING:
  /// - FREE tier → Gemini 2.5 Flash (cost-effective)
  /// - STARTER/PREMIUM/ULTRA → Claude Sonnet 3.5 (clinical-grade)
  /// 
  /// MEDICAL SAFETY (Claude): Input validation, audit logging, contraindication checking
  static Future<String> generateMealPlan({
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    String? healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    String? userId,
    SubscriptionTier? userTier, // NEW: Required for routing
  }) async {
    // ═══════════════════════════════════════════════════════════════
    // 🎯 TIER-BASED AI ROUTING
    // ═══════════════════════════════════════════════════════════════
    
    final effectiveTier = userTier ?? SubscriptionTier.free;

    if (_shouldUseClaudeForMeals(effectiveTier)) {
      return await _generateMealPlanWithClaude(
        days: days,
        cuisine: cuisine,
        diet: diet,
        flavor: flavor,
        cookingTime: cookingTime,
        healthProfile: healthProfile ?? 'General healthy adult',
        budgetConstraints: budgetConstraints,
        country: country,
        currency: currency,
        userId: userId,
        tier: effectiveTier,
      );
    }

    final service = MultiAIService();
    if (!EnvConfig.hasGeminiKey) {
      throw Exception(
        'No AI provider available for meal planning. '
        'Add ANTHROPIC_API_KEY or GEMINI_API_KEY to your .env file.',
      );
    }

    debugPrint('🆓 FREE TIER: Using Gemini 2.5 Flash for meal planning');
    debugPrint('💡 Upgrade to Starter (\$9.99) for clinical-grade Claude AI');

    try {
      return await service._generateMealPlanWithGemini(
        days: days,
        cuisine: cuisine,
        diet: diet,
        flavor: flavor,
        cookingTime: cookingTime,
        healthProfile: healthProfile ?? 'General healthy adult',
        budgetConstraints: budgetConstraints,
        country: country,
        currency: currency,
      );
    } catch (e) {
      if (ClaudeMedicalAIService().isAvailable) {
        debugPrint('⚠️ Gemini meal plan failed, falling back to Claude: $e');
        return await _generateMealPlanWithClaude(
          days: days,
          cuisine: cuisine,
          diet: diet,
          flavor: flavor,
          cookingTime: cookingTime,
          healthProfile: healthProfile ?? 'General healthy adult',
          budgetConstraints: budgetConstraints,
          country: country,
          currency: currency,
          userId: userId,
          tier: effectiveTier,
        );
      }
      rethrow;
    }
  }

  static Future<String> _generateMealPlanWithClaude({
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    required String healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    String? userId,
    required SubscriptionTier tier,
  }) async {
    if (!ClaudeMedicalAIService().isAvailable) {
      throw Exception(
        'Claude API is required for meal planning. '
        'Add ANTHROPIC_API_KEY to your .env file. '
        'Get your API key from: https://console.anthropic.com/',
      );
    }

    final tierName = tier == SubscriptionTier.starter
        ? 'STARTER'
        : tier == SubscriptionTier.premium
            ? 'PREMIUM'
            : tier == SubscriptionTier.ultra
                ? 'ULTRA'
                : 'FREE (Claude fallback)';
    debugPrint('🏥 $tierName: Using ${EnvConfig.anthropicModel} for meal planning');

    return await ClaudeMedicalAIService.generateHealthAwareMealPlan(
      days: days,
      cuisine: cuisine,
      diet: diet,
      flavor: flavor,
      cookingTime: cookingTime,
      healthProfile: healthProfile,
      budgetConstraints: budgetConstraints,
      country: country,
      currency: currency,
      userId: userId,
    );
  }

  static bool _shouldUseClaudeForMeals(SubscriptionTier tier) {
    if (tier != SubscriptionTier.free) return true;
    return !EnvConfig.hasGeminiKey && EnvConfig.hasAnthropicKey;
  }



  /// Generate 3 meals (Breakfast, Lunch, Dinner) for a single day.
  /// Designed for parallel execution — one call per day.
  /// 
  /// 🎯 TIER-BASED ROUTING:
  /// - FREE tier → Gemini 2.5 Flash
  /// - STARTER/PREMIUM/ULTRA → Claude Sonnet 3.5
  static Future<List<dynamic>> generateSingleDayMeals({
    required int day,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    String? healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    Set<String>? avoidDishes,
    String? userId,
    SubscriptionTier? userTier, // NEW: Required for routing
    int mealsPerDay = 3,
  }) async {
    // ═══════════════════════════════════════════════════════════════
    // 🎯 TIER-BASED AI ROUTING
    // ═══════════════════════════════════════════════════════════════
    
    final effectiveTier = userTier ?? SubscriptionTier.free;

    if (_shouldUseClaudeForMeals(effectiveTier)) {
      return await _generateDayMealsWithClaude(
        day: day,
        cuisine: cuisine,
        diet: diet,
        flavor: flavor,
        cookingTime: cookingTime,
        healthProfile: healthProfile ?? 'General healthy adult',
        budgetConstraints: budgetConstraints,
        country: country,
        currency: currency,
        avoidDishes: avoidDishes,
        userId: userId,
        tier: effectiveTier,
        mealsPerDay: mealsPerDay,
      );
    }

    final service = MultiAIService();
    if (!EnvConfig.hasGeminiKey) {
      throw Exception(
        'No AI provider available for meal planning. '
        'Add ANTHROPIC_API_KEY or GEMINI_API_KEY to your .env file.',
      );
    }

    debugPrint('🆓 FREE Day $day: Using Gemini 2.5 Flash ($mealsPerDay meals)');

    try {
      return await service._generateSingleDayWithGemini(
        day: day,
        cuisine: cuisine,
        diet: diet,
        flavor: flavor,
        cookingTime: cookingTime,
        healthProfile: healthProfile ?? 'General healthy adult',
        budgetConstraints: budgetConstraints,
        country: country,
        currency: currency,
        avoidDishes: avoidDishes,
        mealsPerDay: mealsPerDay,
      );
    } catch (e) {
      if (ClaudeMedicalAIService().isAvailable) {
        debugPrint('⚠️ Gemini day $day failed, falling back to Claude: $e');
        return await _generateDayMealsWithClaude(
          day: day,
          cuisine: cuisine,
          diet: diet,
          flavor: flavor,
          cookingTime: cookingTime,
          healthProfile: healthProfile ?? 'General healthy adult',
          budgetConstraints: budgetConstraints,
          country: country,
          currency: currency,
          avoidDishes: avoidDishes,
          userId: userId,
          tier: effectiveTier,
          mealsPerDay: mealsPerDay,
        );
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> _generateDayMealsWithClaude({
    required int day,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    required String healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    Set<String>? avoidDishes,
    String? userId,
    required SubscriptionTier tier,
    int mealsPerDay = 3,
  }) async {
    if (!ClaudeMedicalAIService().isAvailable) {
      throw Exception(
        'Claude API is required for meal planning. '
        'Add ANTHROPIC_API_KEY to your .env file.',
      );
    }

    final tierName = tier == SubscriptionTier.starter
        ? 'STARTER'
        : tier == SubscriptionTier.premium
            ? 'PREMIUM'
            : tier == SubscriptionTier.ultra
                ? 'ULTRA'
                : 'FREE (Claude fallback)';
    debugPrint('🏥 $tierName Day $day: Using ${EnvConfig.anthropicModel} ($mealsPerDay meals)');

    return await ClaudeMedicalAIService.generateHealthAwareDayMeals(
      day: day,
      cuisine: cuisine,
      diet: diet,
      flavor: flavor,
      cookingTime: cookingTime,
      healthProfile: healthProfile,
      budgetConstraints: budgetConstraints,
      country: country,
      currency: currency,
      avoidDishes: avoidDishes,
      userId: userId,
      mealsPerDay: mealsPerDay,
    );
  }

  /// Generate ingredients using AI when API recipes lack details
  static Future<Map<String, dynamic>> generateIngredients({
    required String dishName,
    required String cuisine,
    String? diet,
    int servings = 2,
  }) async {
    final service = MultiAIService();
    final prompt = '''
Generate ingredients and cooking instructions for: "$dishName" ($cuisine cuisine${diet != null ? ', $diet diet' : ''}, $servings servings).

JSON format:
{"ingredients":[{"name":"item","quantity":"2","unit":"cups"}],"cooking_instructions":["Step 1","Step 2"],"prep_time":"20m","calories":450,"protein_g":20,"carbs_g":50,"fat_g":15}''';

    try {
      final response = await service._executeComplexTask(
        prompt: prompt,
        maxTokens: 1024,
        temperature: 0.7,
        useFastModel: true,
      );
      
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('⚠️ AI ingredient generation failed: $e');
      return {};
    }
  }

  /// Fetch real recipe data from Spoonacular API
  /// 🚀 OPTIMIZED: Parallel fetching with short timeout to avoid blocking
  Future<String> _fetchRecipeDataFromAPIs({
    required String cuisine,
    required String diet,
    required int days,
    String? flavor,
  }) async {
    if (_spoonacularKey.isEmpty) {
      return _getFallbackRecipeContext(cuisine);
    }

    final recipes = <Map<String, dynamic>>[];
    final mealTypes = ['breakfast', 'main course', 'dinner'];
    
    // 🚀 OPTIMIZED: Fetch all meal types in PARALLEL instead of sequential
    final apiFutures = mealTypes.map((mealType) async {
      try {
        final queryParams = {
          'apiKey': _spoonacularKey,
          'cuisine': cuisine,
          'type': mealType,
          'number': '${days * 2}', // Get extra for variety
          'addRecipeInformation': 'true',
          'fillIngredients': 'true',
        };
        
        if (diet.toLowerCase() != 'regular') {
          queryParams['diet'] = diet.toLowerCase();
        }
        
        if (flavor != null && flavor.isNotEmpty && flavor.toLowerCase() != 'balanced') {
          queryParams['query'] = flavor;
        }

        final uri = Uri.parse('https://api.spoonacular.com/recipes/complexSearch')
            .replace(queryParameters: queryParams);
        
        // 🚀 REDUCED timeout from 10s to 3s to prevent blocking
        final response = await http.get(uri).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? [];
          return results.map((recipe) => {
            'title': recipe['title'],
            'readyInMinutes': recipe['readyInMinutes'],
            'servings': recipe['servings'],
            'healthScore': recipe['healthScore'],
            'mealType': mealType,
          }).toList();
        }
      } catch (e) {
        debugPrint('⚠️ Spoonacular API fetch failed for $mealType: $e');
      }
      return <Map<String, dynamic>>[];
    });
    
    // Wait for all API calls to complete in parallel
    final apiResults = await Future.wait(apiFutures);
    for (final result in apiResults) {
      recipes.addAll(result);
    }

    if (recipes.isEmpty) {
      return _getFallbackRecipeContext(cuisine);
    }

    // Build context from API data
    final buffer = StringBuffer();
    buffer.writeln('=== REAL RECIPE DATA FROM FOOD DATABASE ===');
    buffer.writeln('Use these authentic $cuisine recipes as inspiration:\n');
    
    for (final recipe in recipes) {
      buffer.writeln('- ${recipe['title']} (${recipe['mealType']}, ${recipe['readyInMinutes']} mins, Health Score: ${recipe['healthScore']})');
    }
    
    return buffer.toString();
  }

  /// Fallback recipe context when APIs are unavailable
  String _getFallbackRecipeContext(String cuisine) {
    return '''
=== AI KNOWLEDGE BASE MODE ===
No API data available. Generate authentic $cuisine meals using your extensive culinary knowledge.
Ensure each meal is unique, culturally accurate, and nutritionally balanced.
''';
  }

  /// Build the comprehensive meal plan prompt with diversity enforcement
  String _buildMealPlanPrompt({
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    String? healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    required String apiRecipeContext,
  }) {
    final random = Random();
    final diversitySeed = random.nextInt(999999);
    
    // Meal style themes for variety
    final mealStyleThemes = [
      'comfort food', 'street food', 'home-style', 'traditional feast',
      'light and fresh', 'hearty and filling', 'quick and easy', 'slow-cooked',
    ];
    mealStyleThemes.shuffle(random);
    final selectedTheme = mealStyleThemes.first;

    // Extract health goals and conditions for differentiation
    final healthGoals = healthProfile?.contains('Goal:') == true 
        ? healthProfile!.split('Goal:').last.split('\n').first.trim().toLowerCase()
        : 'general health';
    final hasConditions = healthProfile?.toLowerCase().contains('condition') ?? false;

    // Calculate budget allocation for examples
    final dailyBudgetExample = budgetConstraints?.dailyBudget.toStringAsFixed(0) ?? '450';
    final breakfastCostExample = budgetConstraints != null ? (budgetConstraints.dailyBudget * 0.20).toStringAsFixed(0) : '150';
    final lunchCostExample = budgetConstraints != null ? (budgetConstraints.dailyBudget * 0.40).toStringAsFixed(0) : '150';
    final dinnerCostExample = budgetConstraints != null ? (budgetConstraints.dailyBudget * 0.40).toStringAsFixed(0) : '150';

    return '''
Generate a $days-day $cuisine meal plan ($diet diet).${flavor != null ? ' Flavor: $flavor.' : ''}${healthProfile != null ? ' Health: $healthProfile.' : ''}${budgetConstraints != null ? '\\n\\nBUDGET CONSTRAINTS (MUST BE STRICTLY ENFORCED):' : ''}
${budgetConstraints != null ? '- Daily Budget: ${budgetConstraints.dailyBudget.toStringAsFixed(0)} $currency/day' : ''}
${budgetConstraints != null ? '- Per Meal Average: ${budgetConstraints.perMealBudget.toStringAsFixed(0)} $currency/meal' : ''}
${budgetConstraints != null ? '- Breakfast: ~$breakfastCostExample $currency (20%), Lunch: ~$lunchCostExample $currency (40%), Dinner: ~$dinnerCostExample $currency (40%)' : ''}
${budgetConstraints != null ? '- Total Budget for $days days: ${budgetConstraints.totalBudget.toStringAsFixed(0)} $currency' : ''}
${budgetConstraints != null ? '- CRITICAL: Use these EXACT values in estimated_cost fields and daily totals!' : ''}

CRITICAL RULES:
1. Return ONLY valid JSON (no markdown, no explanations)
2. Recipe description: max 12 words explaining the dish
3. Cooking steps: MUST include 3-5 detailed steps with specific cooking actions (heat, mix, cook, etc.)
4. All numbers must be numeric (not strings)
5. Budget_summary is REQUIRED for every plan and MUST use the exact budget values provided above
6. Include ALL $days days with 3 meals each (Breakfast, Lunch, Dinner)
7. NO repeated dishes across all days
8. ALL ingredients must have quantity and unit
9. ENFORCE BUDGET: Each meal's estimated_cost must match the budget targets (Breakfast 20%, Lunch 40%, Dinner 40% of daily budget)
10. Daily total_cost MUST equal the daily budget specified above

JSON STRUCTURE EXAMPLE:
{
  "days": [
    {
      "day": 1,
      "meals": [
        {
          "type": "Breakfast",
          "name": "Scrambled Eggs with Toast",
          "local_name": "Native Name in $cuisine",
          "recipe": "Fluffy scrambled eggs served with buttered whole wheat toast",
          "ingredients": [
            {"name": "eggs", "quantity": "3", "unit": "pieces"},
            {"name": "butter", "quantity": "1", "unit": "tbsp"},
            {"name": "whole wheat bread", "quantity": "2", "unit": "slices"}
          ],
          "steps": [
            "Crack 3 large eggs into a medium mixing bowl, add a pinch of salt and 1 tablespoon of milk, then whisk vigorously for 30 seconds until mixture is completely uniform and slightly frothy with no streaks of white",
            "Place a 9-inch non-stick pan over medium-low heat and add 1 tablespoon of butter, swirling the pan to coat the bottom evenly as butter melts and foams (about 1 minute), being careful not to let it brown",
            "Pour the whisked eggs into the pan and let them sit undisturbed for 20 seconds until edges just begin to set, then use a silicone spatula to gently push and fold the eggs from the edges toward the center, creating soft curds",
            "Continue cooking and folding gently for 2-3 minutes, removing pan from heat when eggs are still slightly wet and glossy (they will continue cooking from residual heat), resulting in creamy, fluffy curds",
            "While eggs cook, place 2 slices of whole wheat bread in a toaster on medium-high setting and toast for 2-3 minutes until golden brown and crisp, then immediately spread 1/2 tablespoon of softened butter on each slice while hot",
            "Transfer the scrambled eggs to a warm plate, arrange the buttered toast alongside or underneath, garnish with freshly cracked black pepper and chopped chives if desired, and serve immediately while hot and fluffy"
          ],
          "calories": 350,
          "protein_g": 18,
          "carbs_g": 28,
          "fat_g": 16,
          "fiber_g": 4,
          "prep_time": "10m",
          "estimated_cost": $breakfastCostExample,
          "youtube_link": "https://www.youtube.com/results?search_query=Scrambled+Eggs+recipe"
        }
      ],
      "total_calories": 1800,
      "total_cost": $dailyBudgetExample
    }
  ],
  "grocery_list": [
    {"name": "eggs", "quantity": "18 pieces", "estimated_cost": 300}
  ],
  "budget_summary": {
    "total_cost": ${budgetConstraints != null ? budgetConstraints.totalBudget.toStringAsFixed(0) : '${days * 450}'},
    "cost_per_day": ${budgetConstraints != null ? (budgetConstraints.totalBudget / days).toStringAsFixed(0) : '450'},
    "cost_per_meal": ${budgetConstraints != null ? budgetConstraints.perMealBudget.toStringAsFixed(0) : '150'},
    "currency": "$currency",
    "budget_range": "${budgetConstraints?.budgetLevel ?? 'Medium'}"
  }
}

🔥 CRITICAL COOKING STEPS REQUIREMENTS (NEVER COMPROMISE ON THIS):
- Each meal MUST have 5-7 HIGHLY DETAILED cooking steps (NOT 3-4, minimum is 5)
- EVERY step MUST include ALL of the following:
  ✓ Specific action verbs (heat, dice, chop, sauté, simmer, boil, bake, fry, stir, fold, whisk, etc.)
  ✓ Exact measurements ("2 tablespoons", "1-inch cubes", "medium-sized pieces")
  ✓ Precise timing ("3-4 minutes", "until golden, about 5 minutes", "for 15-20 minutes")
  ✓ Temperature specifications ("medium-high heat", "180°C/350°F", "until bubbling")
  ✓ Visual/sensory cues ("until translucent", "until fragrant", "golden brown", "tender when pierced with fork")
  ✓ Equipment details ("large non-stick pan", "10-inch skillet", "medium saucepan", "mixing bowl")
  ✓ Technique descriptions ("stirring occasionally", "whisking constantly", "folding gently", "turning halfway")

- Steps should cover: ingredient prep → heating/cooking setup → main cooking process → finishing touches → plating/serving
- Each step should be detailed enough that a beginner cook can follow without confusion
- MINIMUM 20 words per step to ensure adequate detail (aim for 25-35 words per step)

Generate authentic $cuisine recipes with professional-level, restaurant-quality cooking instructions that anyone can follow.
''';
  }

  /// Get health goal-specific meal guidance
  String _getHealthGoalSpecificGuidance(String healthGoals, bool hasConditions, String? healthProfile) {
    if (healthGoals.contains('weight loss') || healthGoals.contains('lose weight')) {
      return 'High protein (25g+), low cal (<500), low-GI carbs, lean proteins, no frying';
    } else if (healthGoals.contains('muscle gain') || healthGoals.contains('build muscle')) {
      return 'High protein (35g+), cal surplus (700+), complete proteins, complex carbs, healthy fats';
    } else if (healthGoals.contains('diabetes') || hasConditions && healthGoals.contains('diabetic')) {
      return 'Low-GI only (GI<55), high fiber (10g+), no refined sugars, whole grains, balanced macros';
    } else if (healthGoals.contains('heart') || healthProfile?.contains('cardiovascular') == true) {
      return 'Low sodium (<600mg), omega-3 fish, high fiber, no fried foods, herbs not salt';
    } else if (healthGoals.contains('energy') || healthGoals.contains('performance')) {
      return 'Balanced macros, complex carbs, B-vitamins, iron-rich foods, moderate protein';
    } else {
      return 'Balanced nutrition, variety, whole foods, moderate portions';
    }
  }

  /// Get budget-specific ingredient guidance
  String _getBudgetSpecificGuidance(String budgetLevel) {
    switch (budgetLevel.toLowerCase()) {
      case 'low':
      case 'budget':
        return 'Use rice, beans, eggs, seasonal veggies, chicken, local produce';
      case 'medium':
      case 'moderate':
        return 'Mix affordable + premium, fresh + frozen, mid-range proteins';
      case 'high':
      case 'premium':
        return 'Premium ingredients: organic, grass-fed, wild-caught, specialty items';
      default:
        return 'Cost-effective local ingredients';
    }
  }

  /// Execute a complex task with fast or pro model
  Future<String> _executeComplexTask({
    required String prompt,
    int maxTokens = 8192,
    double temperature = 0.7,
    bool useFastModel = false, // Toggle between fast (gemini-2.5-flash) and pro (gemini-2.5-flash)
  }) async {
    final modelId = useFastModel ? _modelId : _complexModelId;
    final url = Uri.parse('$_baseUrl/$modelId:generateContent?key=$_apiKey');

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'topP': 0.9,
        'topK': 40,
        'maxOutputTokens': maxTokens,
        'response_mime_type': 'application/json',
        // Structured JSON generation doesn't benefit from chain-of-thought.
        // Disabling "thinking" on Gemini 2.5 Flash cuts billed tokens and
        // latency (idle prompts were burning ~300 thinking tokens each).
        'thinkingConfig': {'thinkingBudget': 0},
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: useFastModel ? 45 : 90)); // 🚀 INCREASED: 45s for fast model (more realistic), 90s for complex

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        debugPrint('✅ AI Generation Complete (Model: ${useFastModel ? "Fast" : "Pro"}, Tokens: $maxTokens)');
        return text;
      } else {
        debugPrint('❌ AI Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI generation failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ AI Critical Error: $e');
      rethrow;
    }
  }

  // ============================================
  // CHAT COMPLETION METHODS
  // ============================================

  /// Standard chat completion for search bar widget
  Future<String> chatCompletion({required String prompt}) async {
    final url = Uri.parse('$_baseUrl/$_modelId:generateContent?key=$_apiKey');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'parts': [{'text': prompt}]}],
        'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 
             'I could not process that request.';
    }
    throw Exception('Chat completion failed: ${response.statusCode}');
  }

  /// Chat completion with system instruction for Gluco Coach
  Future<String> chatCompletionText({
    required String prompt,
    String? systemInstruction,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final url = Uri.parse('$_baseUrl/$_modelId:generateContent?key=$_apiKey');
    
    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };

    // Add system instruction if provided
    if (systemInstruction != null) {
      payload['system_instruction'] = {
        'parts': [{'text': systemInstruction}]
      };
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 
             'I could not process that request.';
    }
    throw Exception('Chat completion failed: ${response.statusCode}');
  }

  /// Execute structured task returning JSON
  Future<Map<String, dynamic>> executeStructuredTask({
    required String prompt,
    String? systemInstruction,
    double temperature = 0.2,
    int maxTokens = 2048,
  }) async {
    final url = Uri.parse('$_baseUrl/$_modelId:generateContent?key=$_apiKey');

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'topP': 0.8,
        'topK': 40,
        'maxOutputTokens': maxTokens,
        'response_mime_type': 'application/json',
        // Structured extraction needs no chain-of-thought; skip billed
        // "thinking" tokens on Gemini 2.5 Flash.
        'thinkingConfig': {'thinkingBudget': 0},
      }
    };

    if (systemInstruction != null) {
      payload['system_instruction'] = {
        'parts': [{'text': systemInstruction}]
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse = data['candidates'][0]['content']['parts'][0]['text'];
        try {
          return jsonDecode(textResponse);
        } on FormatException {
          // Attempt to repair truncated JSON
          final repaired = _repairStructuredJson(textResponse);
          return jsonDecode(repaired);
        }
      } else {
        throw Exception('Structured task failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Structured Task Error: $e');
      rethrow;
    }
  }

  /// Repair truncated JSON from structured AI tasks
  static String _repairStructuredJson(String json) {
    var repaired = json.trimRight();
    if (repaired.endsWith(',')) {
      repaired = repaired.substring(0, repaired.length - 1);
    }

    // Track nesting with a stack
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < repaired.length; i++) {
      final c = repaired[i];
      if (escaped) { escaped = false; continue; }
      if (c == '\\') { escaped = true; continue; }
      if (c == '"') { inString = !inString; continue; }
    }
    if (inString) repaired += '"';

    // Remove dangling incomplete values
    final danglingPatterns = [
      RegExp(r',\s*"[^"]*"\s*:\s*$'),
      RegExp(r',\s*"[^"]*"\s*$'),
      RegExp(r',\s*$'),
    ];
    for (final pattern in danglingPatterns) {
      repaired = repaired.replaceFirst(pattern, '');
    }

    // Close unclosed brackets/braces in correct order
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
    repaired += closeStack.reversed.join();
    return repaired;
  }

  // ============================================
  // GEMINI IMPLEMENTATION (TESTING MODE)
  // 🧪 These methods use Gemini for development
  // ⚠️ TODO: Remove when switching to Claude in production
  // ============================================

  /// Generate complete meal plan using Gemini API
  /// 
  /// 🧪 TESTING ONLY: This method will be removed when switching to Claude
  Future<String> _generateMealPlanWithGemini({
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    required String healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
  }) async {
    debugPrint('🧪 TESTING: Generating $days-day meal plan with Gemini 2.5 Flash');
    debugPrint('📝 Cuisine: $cuisine | Diet: $diet | Country: $country');

    try {
      // 🚀 OPTIMIZED: Skip API recipe fetch for fast generation (not worth the delay)
      const apiRecipeContext = '';

      // Build comprehensive prompt
      final prompt = _buildMealPlanPrompt(
        days: days,
        cuisine: cuisine,
        diet: diet,
        flavor: flavor,
        cookingTime: cookingTime,
        healthProfile: healthProfile,
        budgetConstraints: budgetConstraints,
        country: country,
        currency: currency,
        apiRecipeContext: apiRecipeContext,
      );

      // Execute with Gemini (OPTIMIZED for speed)
      final response = await _executeComplexTask(
        prompt: prompt,
        maxTokens: 8192, // 🚀 OPTIMIZED: Reduced for faster generation
        temperature: 0.85, // 🚀 OPTIMIZED: Higher temp = faster generation
        useFastModel: false, // 🚀 Use COMPLEX model with longer timeout (60s) for full plans
      );

      debugPrint('✅ TESTING: Gemini meal plan generated successfully');
      return response;

    } catch (e) {
      debugPrint('❌ TESTING: Gemini meal plan generation failed: $e');
      rethrow;
    }
  }

  /// Generate single day meals using Gemini API
  /// 
  /// 🧪 TESTING ONLY: This method will be removed when switching to Claude
  Future<List<dynamic>> _generateSingleDayWithGemini({
    required int day,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    required String healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    Set<String>? avoidDishes,
    int mealsPerDay = 3,
  }) async {
    debugPrint('🧪 TESTING: Generating Day $day meals with Gemini (FAST MODE, $mealsPerDay meals)');

    try {
      final mealTypes = SubscriptionQuotas.mealTypesForCount(mealsPerDay);
      final mealTypeList = mealTypes.join(', ');
      final avoidInstruction = avoidDishes != null && avoidDishes.isNotEmpty
          ? '\nIMPORTANT: Do NOT include these dishes: ${avoidDishes.join(", ")}'
          : '';

      // Calculate budget allocation for examples
      final perMealShare = mealsPerDay > 0 ? 1.0 / mealsPerDay : 1.0 / 3;
      final breakfastBudget = budgetConstraints != null && mealsPerDay >= 3
          ? (budgetConstraints.dailyBudget * 0.20).toStringAsFixed(0)
          : budgetConstraints != null
              ? (budgetConstraints.dailyBudget * perMealShare).toStringAsFixed(0)
              : '200';
      final lunchBudget = budgetConstraints != null
          ? (budgetConstraints.dailyBudget * (mealsPerDay == 2 ? 0.45 : 0.40)).toStringAsFixed(0)
          : '250';
      final dinnerBudget = budgetConstraints != null
          ? (budgetConstraints.dailyBudget * (mealsPerDay == 2 ? 0.55 : 0.40)).toStringAsFixed(0)
          : '300';
      
      // Create single-day prompt
      final prompt = '''
Generate exactly $mealsPerDay meals ($mealTypeList) for Day $day of a $cuisine meal plan ($diet diet).${flavor != null ? ' Flavor: $flavor.' : ''}${healthProfile.isNotEmpty ? ' Health: $healthProfile.' : ''}${budgetConstraints != null ? '\n\nBUDGET CONSTRAINTS (MUST BE ENFORCED):' : ''}
${budgetConstraints != null ? '- Daily Budget: ${budgetConstraints.dailyBudget.toStringAsFixed(0)} $currency/day' : ''}
${budgetConstraints != null ? '- Per Meal Budget: ${budgetConstraints.perMealBudget.toStringAsFixed(0)} $currency/meal (average)' : ''}
${mealsPerDay >= 3 && budgetConstraints != null ? '- Breakfast Target: ~$breakfastBudget $currency (20% of daily)' : ''}
${budgetConstraints != null ? '- Lunch Target: ~$lunchBudget $currency' : ''}
${budgetConstraints != null ? '- Dinner Target: ~$dinnerBudget $currency' : ''}
${budgetConstraints != null ? '- IMPORTANT: Use estimated_cost values close to these targets!' : ''}
$avoidInstruction

CRITICAL REQUIREMENTS:
1. Return ONLY valid JSON array with exactly $mealsPerDay meal objects
2. Recipe description: max 12 words explaining the dish
3. MANDATORY: "steps" array with 5-7 HIGHLY DETAILED cooking instructions
4. MANDATORY: "estimated_cost" field with realistic price matching budget targets
5. ALL dishes must be authentic $cuisine cuisine
6. NO repeated dishes from previous days
7. ALL ingredients must be listed with quantity and unit
8. All numbers must be numeric (not strings)
9. ENFORCE BUDGET: estimated_cost must match the budget targets above

⚠️ DETAILED COOKING STEPS REQUIREMENTS (CRITICAL - NEVER SKIP):
Each step MUST include:
- Specific action verbs (heat, chop, sauté, simmer, boil, bake, fry, stir, mix, etc.)
- Exact temperatures ("medium-high heat", "180°C/350°F", "boiling 100°C")
- Precise cooking times ("3-4 minutes", "until golden, about 5 minutes", "15-20 minutes")
- Visual/sensory cues ("until translucent", "until fragrant", "golden brown", "tender when pierced")
- Equipment details ("large non-stick pan", "medium saucepan", "mixing bowl")
- Technique descriptions ("stirring occasionally", "whisking constantly", "folding gently")
- Portion/measurement details when relevant ("in batches", "one at a time", "evenly distributed")

BAD EXAMPLES (TOO VAGUE - NEVER DO THIS):
❌ "Cook the chicken"
❌ "Add spices"
❌ "Mix everything together"
❌ "Step 1: Prepare ingredients"

GOOD EXAMPLES (DETAILED - ALWAYS DO THIS):
✅ "Heat 2 tablespoons of vegetable oil in a large non-stick pan over medium-high heat for 1-2 minutes until shimmering"
✅ "Add finely diced onions and sauté for 4-5 minutes, stirring occasionally, until they become translucent and soft"
✅ "Stir in turmeric, cumin, and coriander powder, cooking for 30-45 seconds while stirring constantly until fragrant and slightly darkened"
✅ "Add chicken pieces and cook for 6-8 minutes, turning halfway through, until golden brown on all sides and internal temperature reaches 75°C"
✅ "Reduce heat to low, cover with lid, and simmer for 15-20 minutes until meat is tender when pierced with a fork and sauce has thickened"

⚠️ FIELDS THAT MUST NEVER BE MISSING:
- "steps": Array of 5-7 highly detailed cooking instructions (as described above)
- "estimated_cost": Numeric value matching meal budget
- If these fields are missing, vague, or have fewer than 5 steps, the meal plan will be REJECTED!

JSON FORMAT (array of $mealsPerDay meals):
[
  {
    "type": "${mealTypes.first}",
    "name": "Traditional Dish Name",
    "local_name": "Native Language Name",
    "recipe": "Brief description of dish and cooking method - max 12 words",
    "ingredients": [
      {"name": "main ingredient", "quantity": "2", "unit": "cups"},
      {"name": "spice or seasoning", "quantity": "1", "unit": "tsp"}
    ],
    "steps": [
      "Heat 2 tablespoons of vegetable oil in a large non-stick pan (10-12 inch diameter) over medium-high heat for 1-2 minutes until oil begins to shimmer and a water droplet sizzles on contact",
      "Add 1 large finely diced onion and sauté for 4-5 minutes, stirring every 30 seconds with a wooden spoon, until onions become translucent, soft, and start to turn golden at the edges",
      "Stir in 1 tsp turmeric powder, 1 tsp cumin powder, and 1 tsp coriander powder, cooking for 30-45 seconds while stirring constantly to prevent burning, until spices become fragrant and slightly darkened in color",
      "Add your main protein or vegetables and cook for 8-10 minutes, stirring occasionally and turning pieces halfway through, until ingredients are golden brown on all sides and cooked through (internal temperature 75°C for meat)",
      "Reduce heat to low, add 1/2 cup water or broth, cover with a tight-fitting lid, and simmer for 10-15 minutes until everything is tender and sauce has thickened to desired consistency",
      "Remove from heat, taste and adjust salt if needed, garnish generously with freshly chopped cilantro or herbs, and serve immediately while hot with rice, bread, or chosen accompaniments"
    ],
    "calories": 450,
    "protein_g": 20,
    "carbs_g": 55,
    "fat_g": 15,
    "fiber_g": 6,
    "prep_time": "25m",
    "estimated_cost": $breakfastBudget,
    "youtube_link": "https://www.youtube.com/results?search_query=Traditional+Dish+Name+recipe"
  },
  {
    "type": "Lunch",
    "name": "Lunch Dish",
    "local_name": "Native Name",
    "recipe": "Description with cooking method",
    "ingredients": [{"name": "item", "quantity": "1", "unit": "cup"}],
    "steps": [
      "Wash and pat dry all ingredients, then dice vegetables into 1-inch uniform cubes and cut protein into bite-sized pieces for even cooking",
      "Heat 3 tablespoons of cooking oil in a large wok or deep pan over high heat (about 180°C) for 2 minutes until oil is very hot and starts to smoke slightly",
      "Add protein pieces in a single layer (work in batches if needed) and sear without moving for 2-3 minutes per side until deeply golden and caramelized, then transfer to a plate",
      "In the same pan over medium heat, add aromatics (garlic, ginger, onions) and stir-fry for 1-2 minutes until fragrant, then add vegetables and cook for 5-7 minutes, tossing frequently, until tender-crisp",
      "Return the cooked protein to the pan, add sauce ingredients, and toss everything together for 2-3 minutes over medium-high heat until sauce thickens and coats all ingredients evenly",
      "Remove from heat, transfer to a serving platter, garnish with fresh herbs and sesame seeds, and serve hot with steamed rice or noodles on the side"
    ],
    "calories": 550,
    "protein_g": 25,
    "carbs_g": 60,
    "fat_g": 18,
    "fiber_g": 8,
    "prep_time": "30m",
    "estimated_cost": $lunchBudget,
    "youtube_link": "https://www.youtube.com/results?search_query=Lunch+Dish+recipe"
  },
  {
    "type": "Dinner",
    "name": "Dinner Dish",
    "local_name": "Native Name",
    "recipe": "Evening meal description with preparation style",
    "ingredients": [{"name": "protein", "quantity": "300", "unit": "g"}],
    "steps": [
      "Marinate or prepare main ingredient with seasonings for 15 minutes",
      "Heat cooking vessel to proper temperature",
      "Cook using specific technique for specified duration",
      "Add complementary ingredients and adjust seasoning",
      "Finish cooking and serve with side dishes"
    ],
    "calories": 600,
    "protein_g": 30,
    "carbs_g": 65,
    "fat_g": 20,
    "fiber_g": 10,
    "prep_time": "35m",
    "estimated_cost": $dinnerBudget,
    "youtube_link": "https://www.youtube.com/results?search_query=Dinner+Dish+recipe"
  }
]

COOKING STEPS MUST:
- Be 3-5 steps minimum per meal
- Include specific cooking actions (chop, sauté, simmer, bake, fry, etc.)
- Mention temperatures, times, or visual cues when relevant
- Describe actual cooking techniques, not generic placeholder text
- Be detailed enough for someone to follow and cook the dish

Generate 3 unique, authentic $cuisine meals with complete cooking instructions now:
''';

      // Execute with Gemini (OPTIMIZED for speed)
      final response = await _executeComplexTask(
        prompt: prompt,
        maxTokens: 4096, // 🚀 OPTIMIZED: Reduced for faster generation (3 meals fits easily)
        temperature: 0.85, // 🚀 OPTIMIZED: Higher temp = faster, creative generation
        useFastModel: true, // Use fast model for single day
      );

      // Parse JSON response
      try {
        final meals = jsonDecode(response) as List;
        debugPrint('✅ TESTING: Day $day generated successfully (${meals.length} meals)');
        
        // Debug: Check each meal for required fields
        for (var i = 0; i < meals.length; i++) {
          final meal = meals[i] as Map<String, dynamic>;
          final hasSteps = meal.containsKey('steps') && (meal['steps'] as List).isNotEmpty;
          final hasCost = meal.containsKey('estimated_cost') && meal['estimated_cost'] != 0;
          debugPrint('   Meal ${i+1} (${meal['type']}): steps=$hasSteps, cost=$hasCost (${meal['estimated_cost']})');
        }
        
        return meals;
      } catch (e) {
        debugPrint('❌ TESTING: Failed to parse Gemini response: $e');
        debugPrint('   Raw response (first 500 chars): ${response.substring(0, response.length > 500 ? 500 : response.length)}');
        // Try to repair JSON
        final repaired = _repairStructuredJson(response);
        final meals = jsonDecode(repaired) as List;
        debugPrint('✅ TESTING: Day $day generated after JSON repair (${meals.length} meals)');
        return meals;
      }

    } catch (e) {
      debugPrint('❌ TESTING: Day $day generation failed: $e');
      rethrow;
    }
  }
}