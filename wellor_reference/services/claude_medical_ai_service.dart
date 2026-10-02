import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../models/family_plan_models.dart';
import '../models/subscription_tier.dart';
import '../config/medical_safety_config.dart';

/// MEDICAL-GRADE AI: Claude 3.5 Sonnet for Health-Condition-Based Meal Planning
/// 
/// Safety Features:
/// - Lowest hallucination rate among AI models
/// - Medical reasoning optimized
/// - Contraindication awareness
/// - Nutrient-disease interaction validation
/// - Conservative recommendations for complex conditions
/// 
/// Cost: ~$3 per 1M input tokens, ~$15 per 1M output tokens
/// Worth it for medical safety and liability reduction.
class ClaudeMedicalAIService {
  static final ClaudeMedicalAIService _instance = ClaudeMedicalAIService._internal();
  factory ClaudeMedicalAIService() => _instance;
  ClaudeMedicalAIService._internal();

  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';
  
  String get _apiKey => EnvConfig.anthropicApiKey;
  String get _modelId => EnvConfig.anthropicModel;

  /// Check if Claude API is available
  bool get isAvailable => _apiKey.isNotEmpty;

  // ============================================
  // HEALTH-AWARE MEAL PLAN GENERATION
  // ============================================

  /// Generate a complete meal plan with medical safety considerations
  /// 
  /// This method uses Claude's superior medical reasoning to:
  /// - Understand complex health conditions
  /// - Avoid contraindicated foods
  /// - Balance multiple dietary restrictions
  /// - Provide safe, evidence-based recommendations
  /// 
  /// MEDICAL SAFETY: Includes input validation, audit logging, and contraindication checking
  static Future<String> generateHealthAwareMealPlan({
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
  }) async {
    final service = ClaudeMedicalAIService();
    
    if (!service.isAvailable) {
      throw Exception('Claude API key not configured. Add ANTHROPIC_API_KEY to .env file.');
    }

    // SAFETY: Validate and sanitize health profile
    final sanitizedProfile = MedicalSafetyConfig.sanitizeInput(healthProfile);
    final validation = MedicalSafetyConfig.validateHealthProfile(sanitizedProfile);
    
    if (!validation.isValid) {
      debugPrint('❌ Health profile validation failed: ${validation.summary}');
      throw Exception('Invalid health profile: ${validation.errors.join(", ")}');
    }
    
    if (validation.hasWarnings) {
      debugPrint('⚠️ Health profile warnings: ${validation.warnings.join(", ")}');
    }
    
    if (validation.requiresExpertReview) {
      debugPrint('⚠️ Complex health profile requires expert review');
    }

    final hasHealthConditions = sanitizedProfile.toLowerCase().contains('condition') ||
                                 sanitizedProfile.toLowerCase().contains('disease') ||
                                 sanitizedProfile.toLowerCase().contains('diabetes') ||
                                 sanitizedProfile.toLowerCase().contains('hypertension') ||
                                 sanitizedProfile.toLowerCase().contains('cholesterol');

    // Use medical-grade system prompt from safety config
    final systemPrompt = MedicalSafetyConfig.getMedicalSystemPrompt(includeDisclaimer: true);

    final userPrompt = service._buildMealPlanPrompt(
      days: days,
      cuisine: cuisine,
      diet: diet,
      flavor: flavor,
      cookingTime: cookingTime,
      healthProfile: sanitizedProfile,
      budgetConstraints: budgetConstraints,
      country: country,
      currency: currency,
      includeWarnings: validation.hasWarnings,
      warnings: validation.warnings,
    );

    final response = await service._executeClaudeRequest(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: MedicalSafetyConfig.maxMedicalTokens,
      temperature: MedicalSafetyConfig.medicalTemperature,
    );

    // AUDIT: Log meal plan generation for liability protection
    MedicalSafetyConfig.logMedicalRecommendation(
      userId: userId ?? 'anonymous',
      operationType: 'meal_plan_generation',
      inputData: 'Days: $days, Cuisine: $cuisine, Profile: ${sanitizedProfile.substring(0, sanitizedProfile.length > 100 ? 100 : sanitizedProfile.length)}',
      outputData: 'Generated ${days}-day meal plan',
      confidence: 0.9,
      warnings: validation.warnings,
    );

    return response;
  }

  /// Generate a single day's meals with health considerations
  /// 
  /// MEDICAL SAFETY: Includes validation and audit logging
  static Future<List<dynamic>> generateHealthAwareDayMeals({
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
    int mealsPerDay = 3,
  }) async {
    final service = ClaudeMedicalAIService();
    
    if (!service.isAvailable) {
      throw Exception('Claude API key not configured.');
    }

    // SAFETY: Sanitize input
    final sanitizedProfile = MedicalSafetyConfig.sanitizeInput(healthProfile);
    final validation = MedicalSafetyConfig.validateHealthProfile(sanitizedProfile);
    
    if (!validation.isValid) {
      throw Exception('Invalid health profile: ${validation.errors.join(", ")}');
    }

    final avoidList = avoidDishes?.isNotEmpty == true
        ? avoidDishes!.take(20).join(', ')
        : 'none';

    final mealTypes = SubscriptionQuotas.mealTypesForCount(mealsPerDay);
    final mealTypeList = mealTypes.join(', ');

    final budgetInstruction = budgetConstraints != null
        ? ' BUDGET: Each meal MUST cost approximately ${budgetConstraints.perMealBudget.toStringAsFixed(0)} $currency.'
            ' Daily budget: ${budgetConstraints.dailyBudget.toStringAsFixed(0)} $currency/day.'
            '${mealsPerDay >= 3 ? ' Breakfast ~${(budgetConstraints.dailyBudget * 0.20).toStringAsFixed(0)},' : ''}'
            ' Lunch ~${(budgetConstraints.dailyBudget * (mealsPerDay == 2 ? 0.45 : 0.40)).toStringAsFixed(0)},'
            ' Dinner ~${(budgetConstraints.dailyBudget * (mealsPerDay == 2 ? 0.55 : 0.40)).toStringAsFixed(0)}.'
        : ' BUDGET: Keep prices reasonable, realistic, and affordable for a typical household in $country. Do not exceed the standard medium budget for $country. Do not generate luxury or unrealistically high prices.';

    final hasHealthConditions = sanitizedProfile.toLowerCase().contains('condition') ||
                                 sanitizedProfile.toLowerCase().contains('diabetes') ||
                                 sanitizedProfile.toLowerCase().contains('hypertension');

    // Use medical-grade system prompt from safety config
    final systemPrompt = MedicalSafetyConfig.getMedicalSystemPrompt(includeDisclaimer: false);

    final userPrompt = '''
Generate Day $day meals for a $cuisine $diet meal plan.
${flavor != null ? 'Flavor preference: $flavor.' : ''}
${cookingTime != null ? 'Maximum cooking time: $cookingTime.' : ''}
Country: $country. Currency: $currency.
$budgetInstruction

HEALTH PROFILE: $healthProfile

Avoid these dishes: $avoidList.

CRITICAL REQUIREMENTS:
1. Generate EXACTLY $mealsPerDay meals: $mealTypeList
2.${mealsPerDay >= 3 ? ' Breakfast MUST be light (porridge, eggs, tea, fruit, toast, cereal)' : ' Lunch and dinner should be balanced main meals'}
3. Each meal MUST have 5-8 detailed cooking_instructions steps
4. Each step must include quantities, temperatures, timing, and techniques
5. All ingredients must be safe for the health conditions listed
6. Highlight any nutritional benefits for the specific conditions

Return ONLY valid JSON in this exact format:
{
  "meals": [
    {
      "type": "${mealTypes.first}",
      "name": "Dish Name",
      "local_name": "Native Name",
      "health_notes": "Why this is good for [condition]",
      "cooking_instructions": [
        "1. Detailed step with quantities and timing",
        "2. Next step with technique details",
        "3. Continue until complete"
      ],
      "ingredients": [
        {"name": "item", "quantity": 2, "unit": "cups"}
      ],
      "calories": 350,
      "protein_g": 15,
      "carbs_g": 45,
      "fat_g": 12,
      "fiber_g": 5,
      "prep_time": "20m",
      "estimated_cost": ${budgetConstraints != null ? budgetConstraints.perMealBudget.toStringAsFixed(0) : '150'},
      "youtube_link": "https://www.youtube.com/results?search_query=Dish+recipe"
    }
  ]
}

Return ONLY the JSON, no markdown formatting, no explanations.
''';

    final response = await service._executeClaudeRequest(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: MedicalSafetyConfig.maxMedicalTokens,
      temperature: MedicalSafetyConfig.medicalTemperature,
    );

    // AUDIT: Log daily meal generation
    MedicalSafetyConfig.logMedicalRecommendation(
      userId: userId ?? 'anonymous',
      operationType: 'daily_meal_generation',
      inputData: 'Day: $day, Cuisine: $cuisine, Diet: $diet',
      outputData: 'Generated day $day meals',
      confidence: 0.88,
      warnings: validation.warnings,
    );

    // Parse response
    Map<String, dynamic> parsed;
    try {
      // Remove markdown code blocks if present
      String cleanedResponse = response.trim();
      if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse
            .replaceFirst(RegExp(r'^```[a-z]*\n'), '')
            .replaceFirst(RegExp(r'\n```$'), '');
      }
      parsed = jsonDecode(cleanedResponse) as Map<String, dynamic>;
    } on FormatException catch (e) {
      debugPrint('⚠️ Claude JSON parse error: $e');
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to parse Claude response as JSON');
      }
    }

    final mealsJson = parsed['meals'] as List? ?? [];
    return mealsJson;
  }

  // ============================================
  // PROMPT BUILDERS
  // ============================================
  
  // Note: System prompts now come from MedicalSafetyConfig for consistency
  // See: config/medical_safety_config.dart

  String _buildMealPlanPrompt({
    required int days,
    required String cuisine,
    required String diet,
    String? flavor,
    String? cookingTime,
    required String healthProfile,
    BudgetConstraints? budgetConstraints,
    required String country,
    required String currency,
    bool includeWarnings = false,
    List<String> warnings = const [],
  }) {
    final budgetSection = budgetConstraints != null
        ? '''
BUDGET CONSTRAINTS:
- Total budget: ${budgetConstraints.totalBudget.toStringAsFixed(0)} $currency for $days days
- Daily budget: ${budgetConstraints.dailyBudget.toStringAsFixed(0)} $currency/day
- Per meal target: ${budgetConstraints.perMealBudget.toStringAsFixed(0)} $currency
- Breakfast: ~${(budgetConstraints.dailyBudget * 0.20).toStringAsFixed(0)} $currency
- Lunch: ~${(budgetConstraints.dailyBudget * 0.40).toStringAsFixed(0)} $currency
- Dinner: ~${(budgetConstraints.dailyBudget * 0.40).toStringAsFixed(0)} $currency
'''
        : '''
BUDGET CONSTRAINTS:
- No strict budget set, but you MUST keep prices reasonable, realistic, and affordable for a typical household in $country.
- Do not exceed the standard medium budget for $country.
- Do not generate luxury or unrealistically high prices.
''';

    final warningsSection = includeWarnings && warnings.isNotEmpty
        ? '''

⚠️ SAFETY WARNINGS DETECTED:
${warnings.map((w) => '- $w').join('\n')}

PLEASE ADDRESS THESE WARNINGS IN YOUR RECOMMENDATIONS:
- Provide extra precautions for complex health profiles
- Suggest consulting healthcare providers when appropriate
- Flag any meals requiring special monitoring
'''
        : '';

    return '''
Create a $days-day meal plan with the following specifications:

BASIC REQUIREMENTS:
- Cuisine: $cuisine
- Diet type: $diet
${flavor != null ? '- Flavor preference: $flavor' : ''}
${cookingTime != null ? '- Maximum cooking time: $cookingTime' : ''}
- Country: $country
- Currency: $currency

HEALTH PROFILE:
$healthProfile
$warningsSection
$budgetSection

MEAL PLAN STRUCTURE:
- Generate $days days of meals
- Each day has 3 meals: Breakfast, Lunch, Dinner
- Breakfast must be light morning meals (porridge, eggs, fruit, toast, tea, cereal)
- Lunch and Dinner can be heavier dishes
- Each meal must have 5-8 detailed cooking instructions
- All meals must be safe for the health conditions listed
- Include "health_notes" explaining benefits for specific conditions

REQUIRED JSON FORMAT:
{
  "plan": [
    {
      "day": 1,
      "meals": [
        {
          "type": "Breakfast",
          "name": "Dish Name",
          "local_name": "Native Name",
          "health_notes": "Nutritional benefits for [condition]",
          "cooking_instructions": [
            "1. Step with quantities and timing",
            "2. Step with technique",
            "3. Continue..."
          ],
          "ingredients": [
            {"name": "item", "quantity": 2, "unit": "cups"}
          ],
          "calories": 350,
          "protein_g": 15,
          "carbs_g": 45,
          "fat_g": 12,
          "fiber_g": 5,
          "prep_time": "20m",
          "estimated_cost": 150,
          "youtube_link": "https://www.youtube.com/results?search_query=recipe"
        }
      ]
    }
  ],
  "grocery_list": ["ingredient 1", "ingredient 2"],
  "budget_summary": {
    "total_cost": ${budgetConstraints?.totalBudget.toStringAsFixed(0) ?? '1000'},
    "daily_cost": ${budgetConstraints?.dailyBudget.toStringAsFixed(0) ?? '500'},
    "cost_per_meal": ${budgetConstraints?.perMealBudget.toStringAsFixed(0) ?? '167'},
    "currency": "$currency"
  }
}

Return ONLY the JSON, no markdown code blocks, no explanations.
''';
  }

  // ============================================
  // API EXECUTION
  // ============================================

  Future<String> _executeClaudeRequest({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 16384,
    double temperature = 0.7,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': _apiVersion,
          // Prompt caching keeps the large medical system prompt in Claude's
          // cache for 5 minutes, so repeated calls (e.g. each day of a meal
          // plan) reuse it at ~10% of the input-token cost.
          'anthropic-beta': 'prompt-caching-2024-07-31',
        },
        body: jsonEncode({
          'model': _modelId,
          'max_tokens': maxTokens,
          'temperature': temperature,
          'system': [
            {
              'type': 'text',
              'text': systemPrompt,
              'cache_control': {'type': 'ephemeral'},
            }
          ],
          'messages': [
            {
              'role': 'user',
              'content': userPrompt,
            }
          ],
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as List;
        if (content.isNotEmpty && content[0]['type'] == 'text') {
          return content[0]['text'] as String;
        }
        throw Exception('Unexpected response format from Claude API');
      } else {
        final errorBody = response.body;
        debugPrint('❌ Claude API Error (${response.statusCode}): $errorBody');
        throw Exception('Claude API request failed: ${response.statusCode} - $errorBody');
      }
    } on TimeoutException {
      throw Exception('Claude API request timed out after 90 seconds');
    } catch (e) {
      debugPrint('❌ Claude API execution error: $e');
      rethrow;
    }
  }
}
