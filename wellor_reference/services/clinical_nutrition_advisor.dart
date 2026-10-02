import 'dart:convert';
import '../providers/user_profile_provider.dart';
import '../models/food_item_nutrition.dart';

/// Clinical Nutrition Advisor - Evidence-based dietary recommendations
/// 
/// ROLE: You are a clinical nutrition advisor embedded in a health scanner application.
/// You are NOT a general-purpose assistant. You have one job: analyze a user's
/// health profile and deliver precise, evidence-informed dietary recommendations.
class ClinicalNutritionAdvisor {
  
  /// Generate personalized nutritional advice based on user health profile and scanned food
  ClinicalNutritionRecommendation generateRecommendation({
    required UserProfile? profile,
    required List<FoodItemNutrition> scannedFoods,
  }) {
    // Handle missing profile gracefully
    if (profile == null || !profile.hasPartialNutritionProfile) {
      return _generateGenericRecommendation(scannedFoods);
    }

    // Build health profile object
    final healthProfile = _buildHealthProfile(profile);
    
    // Calculate food totals
    final foodAnalysis = _analyzeFoodItems(scannedFoods);
    
    // Execute reasoning chain
    return _executeReasoningChain(healthProfile, foodAnalysis);
  }

  HealthProfileData _buildHealthProfile(UserProfile profile) {
    // Calculate BMI if height and weight available
    double? bmi;
    if (profile.weight != null && profile.height != null) {
      final weightKg = profile.weight!;
      final heightM = profile.height! / 100;
      bmi = weightKg / (heightM * heightM);
    }

    return HealthProfileData(
      age: profile.age,
      sex: profile.gender?.toLowerCase(),
      weightKg: profile.weight,
      heightCm: profile.height,
      bmi: bmi,
      conditions: profile.diseases,
      allergies: [], // Could be extracted from diseases if needed
      intolerances: [],
      medications: [],
      activityLevel: _mapActivityLevel(profile.activityLevel),
      dietaryPreference: 'omnivore', // Could be added to UserProfile
      goals: profile.healthGoals,
      recentLabs: {},
    );
  }

  String _mapActivityLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'sedentary': return 'sedentary';
      case 'light': return 'lightly_active';
      case 'moderate': return 'moderately_active';
      case 'active':
      case 'very_active': return 'very_active';
      default: return 'moderately_active';
    }
  }

  FoodAnalysis _analyzeFoodItems(List<FoodItemNutrition> foods) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;

    for (final food in foods) {
      totalCalories += food.calories;
      totalProtein += food.proteinGrams;
      totalCarbs += food.carbsGrams;
      totalFat += food.fatGrams;
      totalFiber += food.fiberGrams;
    }

    return FoodAnalysis(
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      totalFiber: totalFiber,
      foodItems: foods,
    );
  }

  ClinicalNutritionRecommendation _executeReasoningChain(
    HealthProfileData profile,
    FoodAnalysis foodAnalysis,
  ) {
    // 1. CONTRAINDICATIONS FIRST
    final strictAvoid = _checkContraindications(profile);
    
    // 2. PRIORITY STACK - rank goals by clinical urgency
    final prioritizedGoals = _prioritizeGoals(profile);
    
    // 3. CALORIC ANCHOR
    final caloricTarget = _calculateCaloricTarget(profile, prioritizedGoals);
    
    // 4. MACRO DISTRIBUTION
    final macros = _calculateMacros(profile, caloricTarget, prioritizedGoals);
    
    // 5. MICRONUTRIENT FLAGS
    final micronutrientWatch = _identifyMicronutrientNeeds(profile);
    
    // 6. MEDICATION INTERACTIONS (placeholder for future)
    final flags = _generateFlags(profile, foodAnalysis, macros);
    
    // Generate food recommendations
    final eatMore = _generateEatMoreRecommendations(profile, macros, foodAnalysis);
    final eatLess = _generateEatLessRecommendations(profile, foodAnalysis);
    
    // Check if professional referral needed
    final referToProfessional = _shouldReferToProfessional(profile);
    
    // Generate summary
    final summary = _generateSummary(profile, foodAnalysis, prioritizedGoals);
    
    return ClinicalNutritionRecommendation(
      summary: summary,
      caloricTarget: caloricTarget,
      macros: macros,
      eatMore: eatMore,
      eatLess: eatLess,
      avoidStrictly: strictAvoid,
      micronutrientWatch: micronutrientWatch,
      mealTiming: _generateMealTiming(profile),
      flags: flags,
      referToProfessional: referToProfessional,
      disclaimer: 'This advice is for educational purposes. Consult your healthcare provider before making major dietary changes, especially if you have medical conditions or take medications.',
    );
  }

  List<String> _checkContraindications(HealthProfileData profile) {
    final avoid = <String>[];
    
    // Check allergies
    avoid.addAll(profile.allergies);
    avoid.addAll(profile.intolerances);
    
    // Condition-based restrictions
    for (final condition in profile.conditions) {
      final condLower = condition.toLowerCase();
      
      if (condLower.contains('kidney') || condLower.contains('renal')) {
        avoid.add('High potassium foods (limit bananas, oranges, tomatoes)');
        avoid.add('Excessive sodium');
      }
      
      if (condLower.contains('gout')) {
        avoid.add('High purine foods (organ meats, anchovies, sardines)');
      }
    }
    
    return avoid;
  }

  List<String> _prioritizeGoals(HealthProfileData profile) {
    final goals = List<String>.from(profile.goals);
    
    // Reorder by clinical priority
    final priority = <String>[];
    
    // Metabolic control first
    if (goals.any((g) => g.toLowerCase().contains('diabetes') || g.toLowerCase().contains('blood sugar'))) {
      priority.add(goals.firstWhere((g) => g.toLowerCase().contains('diabetes') || g.toLowerCase().contains('blood sugar')));
    }
    
    // Cardiovascular risk
    if (goals.any((g) => g.toLowerCase().contains('cholesterol') || g.toLowerCase().contains('heart') || g.toLowerCase().contains('blood pressure'))) {
      priority.addAll(goals.where((g) => g.toLowerCase().contains('cholesterol') || g.toLowerCase().contains('heart') || g.toLowerCase().contains('blood pressure')));
    }
    
    // Weight management
    if (goals.any((g) => g.toLowerCase().contains('weight') || g.toLowerCase().contains('lose') || g.toLowerCase().contains('gain'))) {
      priority.addAll(goals.where((g) => g.toLowerCase().contains('weight') || g.toLowerCase().contains('lose') || g.toLowerCase().contains('gain')));
    }
    
    // Add remaining goals
    for (final goal in goals) {
      if (!priority.contains(goal)) {
        priority.add(goal);
      }
    }
    
    return priority.isEmpty ? goals : priority;
  }

  CaloricTarget _calculateCaloricTarget(HealthProfileData profile, List<String> goals) {
    // Mifflin-St Jeor formula
    double bmr;
    if (profile.weightKg != null && profile.heightCm != null && profile.age != null) {
      final w = profile.weightKg!;
      final h = profile.heightCm!;
      final a = profile.age!;
      
      double base = (10 * w) + (6.25 * h) - (5 * a);
      bmr = profile.sex == 'male' ? base + 5 : base - 161;
    } else {
      // Fallback estimation
      bmr = profile.sex == 'male' ? 1800 : 1400;
    }
    
    // Apply activity multiplier
    final activityMultiplier = _getActivityMultiplier(profile.activityLevel);
    double tdee = bmr * activityMultiplier;
    
    // Apply goal modifier
    final primaryGoal = goals.isNotEmpty ? goals.first.toLowerCase() : '';
    if (primaryGoal.contains('weight') && primaryGoal.contains('loss')) {
      tdee *= 0.80; // -20% for weight loss
    } else if (primaryGoal.contains('muscle') || primaryGoal.contains('gain')) {
      tdee *= 1.15; // +15% for muscle gain
    }
    
    // Apply safety rails
    final minCalories = profile.sex == 'male' ? 1500 : 1200;
    final dailyKcal = tdee.clamp(minCalories.toDouble(), 4000.0).round();
    
    return CaloricTarget(
      dailyKcal: dailyKcal,
      note: _getCaloricNote(primaryGoal, dailyKcal),
    );
  }

  double _getActivityMultiplier(String level) {
    switch (level) {
      case 'sedentary': return 1.2;
      case 'lightly_active': return 1.375;
      case 'moderately_active': return 1.55;
      case 'very_active': return 1.725;
      default: return 1.55;
    }
  }

  String _getCaloricNote(String goal, int calories) {
    if (goal.contains('weight') && goal.contains('loss')) {
      return 'Moderate deficit for sustainable weight loss';
    } else if (goal.contains('muscle')) {
      return 'Slight surplus to support muscle growth';
    } else if (goal.contains('diabetes')) {
      return 'Controlled portions for stable blood sugar';
    }
    return 'Maintenance calories for current activity level';
  }

  Macros _calculateMacros(HealthProfileData profile, CaloricTarget caloricTarget, List<String> goals) {
    final dailyKcal = caloricTarget.dailyKcal;
    final primaryGoal = goals.isNotEmpty ? goals.first.toLowerCase() : '';
    final hasDiabetes = profile.conditions.any((c) => c.toLowerCase().contains('diabetes'));
    final hasHeartDisease = profile.conditions.any((c) => c.toLowerCase().contains('heart') || c.toLowerCase().contains('cardiovascular'));
    final hasKidneyDisease = profile.conditions.any((c) => c.toLowerCase().contains('kidney') || c.toLowerCase().contains('renal'));
    
    // Protein calculation
    double proteinPercent = 0.25; // 25% default
    if (primaryGoal.contains('muscle')) {
      proteinPercent = 0.30;
    } else if (primaryGoal.contains('weight') && primaryGoal.contains('loss')) {
      proteinPercent = 0.30; // Higher protein for satiety
    } else if (hasKidneyDisease) {
      proteinPercent = 0.15; // Moderate protein for kidney protection
    }
    
    // Carb calculation
    double carbPercent = 0.45; // 45% default
    if (hasDiabetes) {
      carbPercent = 0.35; // Lower carbs for blood sugar control
    } else if (primaryGoal.contains('keto') || primaryGoal.contains('low carb')) {
      carbPercent = 0.10;
    } else if (primaryGoal.contains('muscle')) {
      carbPercent = 0.45; // Adequate carbs for training
    }
    
    // Fat calculation
    double fatPercent = 1.0 - proteinPercent - carbPercent;
    if (hasHeartDisease) {
      fatPercent = fatPercent.clamp(0.20, 0.30); // Moderate fat for heart health
      // Recalculate to balance
      carbPercent = 1.0 - proteinPercent - fatPercent;
    }
    
    final proteinG = ((dailyKcal * proteinPercent) / 4).round();
    final carbsG = ((dailyKcal * carbPercent) / 4).round();
    final fatG = ((dailyKcal * fatPercent) / 9).round();
    
    // Fiber target
    int fiberG = 30; // Standard recommendation
    if (hasDiabetes) fiberG = 35;
    if (profile.conditions.any((c) => c.toLowerCase().contains('constipation'))) fiberG = 40;
    
    return Macros(
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      fiberG: fiberG,
    );
  }

  List<MicronutrientWatch> _identifyMicronutrientNeeds(HealthProfileData profile) {
    final watch = <MicronutrientWatch>[];
    
    // Age-based
    if (profile.age != null && profile.age! > 50) {
      watch.add(MicronutrientWatch(
        nutrient: 'Vitamin D',
        action: 'Consider 1000-2000 IU daily supplement',
      ));
      watch.add(MicronutrientWatch(
        nutrient: 'Calcium',
        action: 'Ensure 1200mg daily through diet or supplement',
      ));
    }
    
    // Sex-based
    if (profile.sex == 'female' && (profile.age == null || profile.age! < 50)) {
      watch.add(MicronutrientWatch(
        nutrient: 'Iron',
        action: 'Aim for 18mg daily from lean meats, legumes, fortified cereals',
      ));
    }
    
    // Condition-based
    if (profile.conditions.any((c) => c.toLowerCase().contains('diabetes'))) {
      watch.add(MicronutrientWatch(
        nutrient: 'Chromium',
        action: 'May help with glucose metabolism - discuss with provider',
      ));
      watch.add(MicronutrientWatch(
        nutrient: 'Magnesium',
        action: 'Important for insulin sensitivity - aim for 400mg daily',
      ));
    }
    
    if (profile.conditions.any((c) => c.toLowerCase().contains('hypertension') || c.toLowerCase().contains('blood pressure'))) {
      watch.add(MicronutrientWatch(
        nutrient: 'Potassium',
        action: 'Aim for 3500-4700mg daily from fruits and vegetables',
      ));
      watch.add(MicronutrientWatch(
        nutrient: 'Sodium',
        action: 'Limit to <1500mg daily - avoid processed foods',
      ));
    }
    
    return watch;
  }

  List<ClinicalFlag> _generateFlags(HealthProfileData profile, FoodAnalysis food, Macros macros) {
    final flags = <ClinicalFlag>[];
    
    // Check scanned food against goals
    final hasDiabetes = profile.conditions.any((c) => c.toLowerCase().contains('diabetes'));
    if (hasDiabetes && food.totalCarbs > 60) {
      final glycemicLoad = food.totalCarbs - food.totalFiber;
      if (glycemicLoad > 40) {
        flags.add(ClinicalFlag(
          severity: 'warning',
          message: 'High glycemic load detected (${glycemicLoad.round()}g net carbs). May cause blood sugar spike.',
        ));
      }
    }
    
    // Low protein warning
    if (food.totalProtein < (macros.proteinG * 0.2)) {
      flags.add(ClinicalFlag(
        severity: 'info',
        message: 'This meal is low in protein. Consider adding lean meat, eggs, or legumes.',
      ));
    }
    
    // Low fiber warning
    if (food.totalFiber < 5 && food.totalCarbs > 40) {
      flags.add(ClinicalFlag(
        severity: 'info',
        message: 'Low fiber content. Add vegetables or whole grains for better satiety and glucose control.',
      ));
    }
    
    // High sodium warning for hypertension
    if (profile.conditions.any((c) => c.toLowerCase().contains('hypertension') || c.toLowerCase().contains('blood pressure'))) {
      flags.add(ClinicalFlag(
        severity: 'warning',
        message: 'With high blood pressure, limit sodium to <500mg per meal.',
      ));
    }
    
    return flags;
  }

  List<FoodRecommendation> _generateEatMoreRecommendations(
    HealthProfileData profile,
    Macros macros,
    FoodAnalysis food,
  ) {
    final recommendations = <FoodRecommendation>[];
    final hasDiabetes = profile.conditions.any((c) => c.toLowerCase().contains('diabetes'));
    final hasHeartDisease = profile.conditions.any((c) => c.toLowerCase().contains('heart'));
    
    // Fiber-rich foods
    if (food.totalFiber < macros.fiberG * 0.3) {
      recommendations.add(FoodRecommendation(
        food: 'Non-starchy vegetables (broccoli, spinach, peppers)',
        reason: 'High fiber, low calorie, rich in vitamins',
        serving: '2-3 cups per day',
      ));
    }
    
    // Protein-rich foods
    if (food.totalProtein < macros.proteinG * 0.25) {
      recommendations.add(FoodRecommendation(
        food: 'Lean protein (chicken breast, fish, tofu)',
        reason: 'Supports muscle maintenance and satiety',
        serving: '4-6 oz per meal',
      ));
    }
    
    // Condition-specific
    if (hasDiabetes) {
      recommendations.add(FoodRecommendation(
        food: 'Fatty fish (salmon, mackerel, sardines)',
        reason: 'Omega-3s help reduce inflammation and improve insulin sensitivity',
        serving: '3-4 oz, 2-3 times per week',
      ));
      recommendations.add(FoodRecommendation(
        food: 'Legumes (lentils, chickpeas, black beans)',
        reason: 'Low GI, high fiber, stabilizes blood sugar',
        serving: '½ cup cooked per serving',
      ));
    }
    
    if (hasHeartDisease) {
      recommendations.add(FoodRecommendation(
        food: 'Nuts (almonds, walnuts)',
        reason: 'Healthy fats that support heart health',
        serving: '1 oz (small handful) daily',
      ));
      recommendations.add(FoodRecommendation(
        food: 'Berries (blueberries, strawberries)',
        reason: 'Antioxidants reduce cardiovascular inflammation',
        serving: '1 cup fresh or ½ cup frozen daily',
      ));
    }
    
    // General healthy additions
    recommendations.add(FoodRecommendation(
      food: 'Leafy greens (kale, spinach, arugula)',
      reason: 'Nutrient-dense, low calorie, supports overall health',
      serving: '1-2 cups raw or ½ cup cooked daily',
    ));
    
    return recommendations.take(6).toList();
  }

  List<FoodWarning> _generateEatLessRecommendations(
    HealthProfileData profile,
    FoodAnalysis food,
  ) {
    final warnings = <FoodWarning>[];
    final hasDiabetes = profile.conditions.any((c) => c.toLowerCase().contains('diabetes'));
    final hasHeartDisease = profile.conditions.any((c) => c.toLowerCase().contains('heart'));
    final hasHypertension = profile.conditions.any((c) => c.toLowerCase().contains('hypertension') || c.toLowerCase().contains('blood pressure'));
    
    if (hasDiabetes) {
      warnings.add(FoodWarning(
        food: 'Refined carbohydrates (white bread, white rice, sugary drinks)',
        reason: 'Rapid blood sugar spikes, poor glucose control',
      ));
      warnings.add(FoodWarning(
        food: 'Sugary desserts and candy',
        reason: 'Direct glucose elevation without nutritional benefit',
      ));
    }
    
    if (hasHeartDisease || hasHypertension) {
      warnings.add(FoodWarning(
        food: 'Processed meats (bacon, sausage, deli meats)',
        reason: 'High in sodium and saturated fat',
      ));
      warnings.add(FoodWarning(
        food: 'Fried foods',
        reason: 'Trans fats and excess calories harm cardiovascular health',
      ));
    }
    
    if (hasHypertension) {
      warnings.add(FoodWarning(
        food: 'High-sodium foods (canned soups, chips, fast food)',
        reason: 'Directly increases blood pressure',
      ));
    }
    
    // General
    warnings.add(FoodWarning(
      food: 'Ultra-processed snacks',
      reason: 'Low nutrient density, excess additives and preservatives',
    ));
    
    warnings.add(FoodWarning(
      food: 'Sugar-sweetened beverages',
      reason: 'Empty calories with no satiety benefit',
    ));
    
    return warnings.take(5).toList();
  }

  String _generateMealTiming(HealthProfileData profile) {
    final hasDiabetes = profile.conditions.any((c) => c.toLowerCase().contains('diabetes'));
    
    if (hasDiabetes) {
      return '3 balanced meals with 1-2 small snacks. Consistent timing helps regulate blood sugar.';
    }
    
    final primaryGoal = profile.goals.isNotEmpty ? profile.goals.first.toLowerCase() : '';
    if (primaryGoal.contains('weight') && primaryGoal.contains('loss')) {
      return '3 meals, avoid eating 3 hours before bed. Consider 12-14 hour overnight fast.';
    }
    
    return '3 balanced meals per day with optional healthy snacks if hungry.';
  }

  bool _shouldReferToProfessional(HealthProfileData profile) {
    // Check for conditions that require professional oversight
    for (final condition in profile.conditions) {
      final condLower = condition.toLowerCase();
      
      if (condLower.contains('kidney') && condLower.contains('stage 3')) return true;
      if (condLower.contains('kidney') && condLower.contains('stage 4')) return true;
      if (condLower.contains('kidney') && condLower.contains('stage 5')) return true;
      if (condLower.contains('dialysis')) return true;
      if (condLower.contains('cancer')) return true;
      if (condLower.contains('malignancy')) return true;
      if (condLower.contains('tumor')) return true;
      if (condLower.contains('eating disorder')) return true;
    }
    
    // Check BMI extremes
    if (profile.bmi != null) {
      if (profile.bmi! < 16 || profile.bmi! > 40) return true;
    }
    
    return false;
  }

  String _generateSummary(HealthProfileData profile, FoodAnalysis food, List<String> goals) {
    final primaryGoal = goals.isNotEmpty ? goals.first : 'general health';
    final hasDiabetes = profile.conditions.any((c) => c.toLowerCase().contains('diabetes'));
    
    if (hasDiabetes) {
      return 'Focus on low-glycemic carbs, consistent meal timing, and high fiber to manage blood sugar. '
             'Your scanned meal has ${food.totalCarbs.round()}g carbs and ${food.totalFiber.round()}g fiber.';
    }
    
    if (primaryGoal.toLowerCase().contains('weight loss')) {
      return 'Prioritize lean protein, fiber-rich vegetables, and portion control for sustainable weight loss. '
             'This meal contains ${food.totalCalories.round()} calories.';
    }
    
    return 'Balanced nutrition with adequate protein, fiber-rich carbs, and healthy fats supports your $primaryGoal goal.';
  }

  ClinicalNutritionRecommendation _generateGenericRecommendation(List<FoodItemNutrition> foods) {
    final food = _analyzeFoodItems(foods);
    
    return ClinicalNutritionRecommendation(
      summary: 'Complete your health profile for personalized recommendations. This meal has ${food.totalCalories.round()} calories.',
      caloricTarget: CaloricTarget(dailyKcal: 2000, note: 'Complete profile for personalized target'),
      macros: Macros(proteinG: 150, carbsG: 200, fatG: 65, fiberG: 30),
      eatMore: [
        FoodRecommendation(food: 'Vegetables', reason: 'High in fiber and nutrients', serving: '2-3 cups daily'),
        FoodRecommendation(food: 'Lean protein', reason: 'Supports muscle and satiety', serving: '4-6 oz per meal'),
      ],
      eatLess: [
        FoodWarning(food: 'Processed foods', reason: 'Often high in sodium and additives'),
        FoodWarning(food: 'Sugary drinks', reason: 'Empty calories'),
      ],
      avoidStrictly: [],
      micronutrientWatch: [],
      mealTiming: '3 balanced meals per day',
      flags: [],
      referToProfessional: false,
      disclaimer: 'Complete your health profile for personalized advice. This is general guidance only.',
    );
  }
}

// ============================================
// DATA MODELS
// ============================================

class HealthProfileData {
  final int? age;
  final String? sex;
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final List<String> conditions;
  final List<String> allergies;
  final List<String> intolerances;
  final List<String> medications;
  final String activityLevel;
  final String dietaryPreference;
  final List<String> goals;
  final Map<String, dynamic> recentLabs;

  HealthProfileData({
    this.age,
    this.sex,
    this.weightKg,
    this.heightCm,
    this.bmi,
    required this.conditions,
    required this.allergies,
    required this.intolerances,
    required this.medications,
    required this.activityLevel,
    required this.dietaryPreference,
    required this.goals,
    required this.recentLabs,
  });
}

class FoodAnalysis {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final List<FoodItemNutrition> foodItems;

  FoodAnalysis({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    required this.foodItems,
  });
}

class ClinicalNutritionRecommendation {
  final String summary;
  final CaloricTarget caloricTarget;
  final Macros macros;
  final List<FoodRecommendation> eatMore;
  final List<FoodWarning> eatLess;
  final List<String> avoidStrictly;
  final List<MicronutrientWatch> micronutrientWatch;
  final String mealTiming;
  final List<ClinicalFlag> flags;
  final bool referToProfessional;
  final String disclaimer;

  ClinicalNutritionRecommendation({
    required this.summary,
    required this.caloricTarget,
    required this.macros,
    required this.eatMore,
    required this.eatLess,
    required this.avoidStrictly,
    required this.micronutrientWatch,
    required this.mealTiming,
    required this.flags,
    required this.referToProfessional,
    required this.disclaimer,
  });

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'caloric_target': {
      'daily_kcal': caloricTarget.dailyKcal,
      'note': caloricTarget.note,
    },
    'macros': {
      'protein_g': macros.proteinG,
      'carbs_g': macros.carbsG,
      'fat_g': macros.fatG,
      'fiber_g': macros.fiberG,
    },
    'eat_more': eatMore.map((e) => {
      'food': e.food,
      'reason': e.reason,
      'serving': e.serving,
    }).toList(),
    'eat_less': eatLess.map((e) => {
      'food': e.food,
      'reason': e.reason,
    }).toList(),
    'avoid_strictly': avoidStrictly,
    'micronutrient_watch': micronutrientWatch.map((m) => {
      'nutrient': m.nutrient,
      'action': m.action,
    }).toList(),
    'meal_timing': mealTiming,
    'flags': flags.map((f) => {
      'severity': f.severity,
      'message': f.message,
    }).toList(),
    'refer_to_professional': referToProfessional,
    'disclaimer': disclaimer,
  };
}

class CaloricTarget {
  final int dailyKcal;
  final String note;

  CaloricTarget({required this.dailyKcal, required this.note});
}

class Macros {
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;

  Macros({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });
}

class FoodRecommendation {
  final String food;
  final String reason;
  final String serving;

  FoodRecommendation({
    required this.food,
    required this.reason,
    required this.serving,
  });
}

class FoodWarning {
  final String food;
  final String reason;

  FoodWarning({required this.food, required this.reason});
}

class MicronutrientWatch {
  final String nutrient;
  final String action;

  MicronutrientWatch({required this.nutrient, required this.action});
}

class ClinicalFlag {
  final String severity; // 'info' | 'warning' | 'critical'
  final String message;

  ClinicalFlag({required this.severity, required this.message});
}
