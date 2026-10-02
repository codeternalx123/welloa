import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/nutrition_calculation.dart';
import '../models/health_models.dart' hide VerifiedNutritionData;
import '../providers/user_profile_provider.dart';
import 'health_nexus_service.dart';
import 'multi_ai_service.dart';

// ============================================
// CLINICAL AI PROMPT BUILDER
// ============================================

class RationalePromptBuilder {
  static String buildPrompt({
    required double tdee,
    required String primaryGoal,
    required List<String> conditions,
    required int targetProtein,
    required int targetCarbs,
    required int targetFat,
  }) {
    return '''
You are an empathetic, expert nutrition coach.

USER PROFILE:
- Target Calories: ${tdee.round()} kcal (Base)
- Goal: $primaryGoal
- Conditions: ${conditions.isEmpty ? 'None' : conditions.join(', ')}
- Target Macros: Protein ${targetProtein}g, Carbs ${targetCarbs}g, Fat ${targetFat}g

INSTRUCTIONS:
Generate user-friendly, non-medical copy explaining their nutrition plan.
The tone must be encouraging, accessible, and focus on steady progress rather than strict medical limitations. Do not use scary medical jargon.

1. calorieReason: Explain how their calorie target helps their specific goal.
2. goalAdjustments: A friendly sentence about what their plan is set up to do.
3. conditionAdjustments: Generate 1-2 sentences explaining how their meals are tailored for their specific health conditions. If no conditions, leave empty.
4. warnings: 1-2 friendly tips on what to watch out for.
5. macroReasons: Explain why the specific macro targets are set this way, referencing their goal or conditions when useful.
6. mealGuidance: One practical sentence on how to structure a typical plate.

OUTPUT EXACT JSON ONLY:
{
  "calorieReason": "<short plain-language reason for this daily calorie goal>",
  "goalAdjustments": ["<string>"],
  "conditionAdjustments": ["<string>"],
  "warnings": ["<string>"],
  "macroReasons": [
    {"macro": "Protein", "targetG": $targetProtein, "reason": "<string>"},
    {"macro": "Carbs", "targetG": $targetCarbs, "reason": "<string>"},
    {"macro": "Fat", "targetG": $targetFat, "reason": "<string>"}
  ],
  "mealGuidance": "<string>"
}
''';
  }
}

/// UNICORN GRADE: Predictive Metabolic Intelligence Engine.
/// Fuses clinical goals with normalized intake for real-time biological budgeting.
class DailyBalanceService {
  static final DailyBalanceService _instance = DailyBalanceService._internal();
  factory DailyBalanceService() => _instance;
  DailyBalanceService._internal();

  // ============================================
  // CORE INTELLIGENCE: THE BALANCE CALCULATOR
  // ============================================

  /// Orchestrates a "Clinical Triage" of the day's intake.
  /// Returns a detailed budget report relative to the user's biological truth.
  Future<DailyBalanceReport> computeDailyStatus({
    required List<VerifiedNutritionData> mealLogs,
    required UserProfileProvider profile,
    bool useAiReasoning = false,
  }) async {
    // 1. Parallel Aggregation
    final aggregate = _sumIntake(mealLogs);
    final targets = profile.currentGoals;
    final user = profile.userProfile;

    // Optional: query Health Nexus for dynamic metabolic adjustments
    MetabolicReport? adjustment;
    try {
      if (user != null) {
        adjustment = await HealthNexusService().performDeepSync(userId: '', profile: user);
      }
    } catch (_) {
      adjustment = null;
    }

    // Calculate additional calories from adjustment
    final additionalCalories = adjustment != null 
        ? (adjustment.adjustedCalorieTarget > targets.targetCalories 
            ? adjustment.adjustedCalorieTarget - targets.targetCalories 
            : 0)
        : 0;
    final adjustedCaloriesTarget = targets.targetCalories + additionalCalories;

    // 2. High-Precision Delta Calculation
    final calorieStatus = _calculateMacroBalance(aggregate.calories, adjustedCaloriesTarget.toDouble());
    final proteinStatus = _calculateMacroBalance(aggregate.proteinG, targets.targetProtein.toDouble());
    final carbStatus = _calculateMacroBalance(aggregate.carbsG, targets.targetCarbs.toDouble());
    final fatStatus = _calculateMacroBalance(aggregate.fatG, targets.targetFat.toDouble());

    // 3. Clinical Micro-Nutrient Audit
    // Critical for hypertension (Sodium) and glucose stability (Fiber)
    final fiberStatus = _calculateMacroBalance(aggregate.fiberG, targets.targetFiber.toDouble());
    final sodiumStatus = _calculateMacroBalance(aggregate.sodiumMg, targets.targetSodium.toDouble());

    // Build insight text to surface adjusted calories when present
    final insightPrefix = adjustment != null && additionalCalories > 0
        ? '${targets.targetCalories.toString()}, + $additionalCalories from Activity'
        : targets.targetCalories.toString();

    // 4. Clinical Rationale: AI-powered reasoning for WHY these targets were set
    final rationale = useAiReasoning && user != null
        ? await _buildClinicalRationale(profile)
        : _buildFallbackRationale(
            targets: targets,
            goal: user?.primaryGoal ?? 'general wellness',
          );

    return DailyBalanceReport(
      timestamp: DateTime.now(),
      calories: calorieStatus,
      protein: proteinStatus,
      carbs: carbStatus,
      fat: fatStatus,
      fiber: fiberStatus,
      sodium: sodiumStatus,
      metabolicInsight: '${_generateClinicalInsight(calorieStatus, carbStatus, fiberStatus)}\nTargets: $insightPrefix',
      clinicalRiskLevel: _assessRisk(sodiumStatus, calorieStatus),
      clinicalRationale: rationale,
    );
  }

  /// Convenience: compute report directly from providers used in the app.
  /// This allows UI code (e.g. Home Screen wrapped in a Consumer<NutritionGoalsProvider>)
  /// to pass provider instances directly to the balance engine.
  Future<DailyBalanceReport> computeFromProviders({
    required dynamic nutritionGoalsProvider,
    required UserProfileProvider profile,
    bool useAiReasoning = false,
  }) async {
    // nutritionGoalsProvider is expected to expose a `todayMeals` List<NutritionCalculation>
    final List<VerifiedNutritionData> logs = [];
    try {
      final meals = (nutritionGoalsProvider.todayMeals as List).cast();
      debugPrint('⚙️ DailyBalanceService: Processing ${meals.length} meals from provider');
      for (final m in meals) {
        // Convert NutritionCalculation into a verified aggregate for the day
        final totalWeight = (m.foodItems.isNotEmpty)
            ? m.foodItems.map((f) => (f.portionGrams ?? 0.0)).fold(0.0, (a, b) => a + b)
            : (m.totalCalories > 0 ? 100.0 : 0.0);

        debugPrint('⚙️ Meal: ${m.totalCalories} cal, ${m.proteinGrams}g protein');
        logs.add(VerifiedNutritionData(
          foodName: m.foodItems.isNotEmpty ? m.foodItems.map((f) => f.name).join(', ') : 'Logged Meal',
          source: 'app-logs',
          isVerified: true,
          servingWeightGrams: totalWeight > 0 ? totalWeight : 100.0,
          calories: m.totalCalories,
          proteinG: m.proteinGrams,
          carbsG: m.carbsGrams,
          fatG: m.fatGrams,
          fiberG: m.fiberGrams,
          sugarG: (m as dynamic).sugarGrams ?? 0.0,
          sodiumMg: m.sodiumMg,
          cholesterolMg: (m as dynamic).cholesterolMg ?? 0.0,
          saturatedFatG: 0.0,
          transFatG: 0.0,
        ));
      }
    } catch (e) {
      debugPrint('DailyBalanceService: Failed to convert provider meals: $e');
    }

    // FALLBACK: If todayMeals list is empty, use todayTracker aggregate values
    // This handles cases where individual meal documents aren't available but totals are
    if (logs.isEmpty) {
      try {
        final tracker = nutritionGoalsProvider.todayTracker;
        debugPrint('⚙️ DailyBalanceService: Using tracker fallback - tracker=${tracker != null}, calories=${tracker?.totalCalories}, mealsLogged=${tracker?.mealsLogged}');
        if (tracker != null && (tracker.totalCalories > 0 || tracker.mealsLogged > 0)) {
          logs.add(VerifiedNutritionData(
            foodName: 'Daily Total',
            source: 'tracker-aggregate',
            isVerified: true,
            servingWeightGrams: 100.0,
            calories: tracker.totalCalories,
            proteinG: tracker.totalProtein,
            carbsG: tracker.totalCarbs,
            fatG: tracker.totalFat,
            fiberG: tracker.totalFiber,
            sugarG: 0.0,
            sodiumMg: tracker.totalSodium,
            cholesterolMg: 0.0,
            saturatedFatG: 0.0,
            transFatG: 0.0,
          ));
          debugPrint('⚙️ DailyBalanceService: Using todayTracker fallback - ${tracker.totalCalories} cal, fiber=${tracker.totalFiber}g, sodium=${tracker.totalSodium}mg');
        }
      } catch (e) {
        debugPrint('DailyBalanceService: Failed to use todayTracker fallback: $e');
      }
    }
    
    debugPrint('⚙️ DailyBalanceService: Final logs count: ${logs.length}');

    return await computeDailyStatus(
      mealLogs: logs,
      profile: profile,
      useAiReasoning: useAiReasoning,
    );
  }

  /// Alias for computeDailyStatus - commonly used name in UI code
  Future<DailyBalanceReport> calculateBalance({
    required List<VerifiedNutritionData> mealLogs,
    required UserProfileProvider profile,
  }) async {
    return computeDailyStatus(mealLogs: mealLogs, profile: profile);
  }

  // ============================================
  // PRIVATE LOGIC: CLINICAL GUARDRAILS
  // ============================================

  MacroBalance _calculateMacroBalance(double current, double target) {
    // Lead Dev Rule: Never trust 0 targets to avoid division by zero errors.
    final safeTarget = target > 0 ? target : 1.0;
    return MacroBalance(
      current: current,
      target: target,
      percentage: (current / safeTarget).clamp(0.0, 2.0), // Support up to 200% for over-limit UI
      remaining: math.max(0, target - current),
      isOverLimit: current > target,
    );
  }

  VerifiedNutritionData _sumIntake(List<VerifiedNutritionData> logs) {
    if (logs.isEmpty) return VerifiedNutritionData.empty();
    return logs.reduce((a, b) => VerifiedNutritionData(
      foodName: 'Aggregated',
      calories: a.calories + b.calories,
      proteinG: a.proteinG + b.proteinG,
      carbsG: a.carbsG + b.carbsG,
      fatG: a.fatG + b.fatG,
      fiberG: a.fiberG + b.fiberG,
      sodiumMg: a.sodiumMg + b.sodiumMg,
      servingWeightGrams: a.servingWeightGrams + b.servingWeightGrams,
      isVerified: true,
    ));
  }

  String _generateClinicalInsight(MacroBalance cals, MacroBalance carbs, MacroBalance fiber) {
    if (carbs.isOverLimit && fiber.percentage < 0.5) {
      return "High glycemic load detected. Prioritize high-fiber greens for your next meal.";
    }
    if (cals.percentage > 0.9 && cals.percentage <= 1.0) {
      return "Target nearly reached. Suggesting a light, protein-dense snack if hungry.";
    }
    return "Metabolic tracking is optimal. You are within clinical range.";
  }

  ClinicalRisk _assessRisk(MacroBalance sodium, MacroBalance cals) {
    if (sodium.percentage > 1.2) return ClinicalRisk.high;
    if (cals.percentage > 1.1) return ClinicalRisk.moderate;
    return ClinicalRisk.low;
  }

  // ============================================
  // CLINICAL RATIONALE GENERATOR (AI-Powered)
  // ============================================

  final MultiAIService _ai = MultiAIService();

  /// Asynchronously generates evidence-based reasoning via AI Clinical Reasoning Engine.
  /// Deterministic math (BMR/TDEE) is calculated locally; the AI handles
  /// heuristic MNT adjustments for any condition or compound combination.
  Future<ClinicalRationale> _buildClinicalRationale(UserProfileProvider profileProvider) async {
    final user = profileProvider.userProfile;
    final targets = profileProvider.currentGoals;
    if (user == null || !user.hasPartialNutritionProfile) {
      return ClinicalRationale.generic();
    }

    final fallbackRationale = _buildFallbackRationale(
      targets: targets,
      goal: user.primaryGoal,
    );

    final prompt = RationalePromptBuilder.buildPrompt(
      tdee: user.tdee,
      primaryGoal: user.primaryGoal,
      conditions: user.diseases,
      targetProtein: targets.targetProtein,
      targetCarbs: targets.targetCarbs,
      targetFat: targets.targetFat,
    );

    try {
      final data = await _ai.executeStructuredTask(
        prompt: prompt,
        temperature: 0.2,
        maxTokens: 4096,
      );

      final aiConditionAdjustments = List<String>.from(data['conditionAdjustments'] ?? []);
      final aiGoalAdjustments = List<String>.from(data['goalAdjustments'] ?? []);
      final aiWarnings = List<String>.from(data['warnings'] ?? []);
      final aiMacroReasons = (data['macroReasons'] as List<dynamic>? ?? []).map((m) {
        return MacroRationale(
          macro: m['macro'] as String? ?? '',
          targetG: (m['targetG'] as num?)?.toInt() ?? 0,
          reason: m['reason'] as String? ?? '',
        );
      }).where((m) => m.macro.isNotEmpty && m.reason.isNotEmpty).toList();

      return ClinicalRationale(
        dailyCalorieTarget: targets.targetCalories,
        calorieReason: (data['calorieReason'] as String?)?.trim().isNotEmpty == true
            ? data['calorieReason'] as String
            : fallbackRationale.calorieReason,
        conditionAdjustments: aiConditionAdjustments.isNotEmpty
            ? aiConditionAdjustments
            : fallbackRationale.conditionAdjustments,
        goalAdjustments: aiGoalAdjustments.isNotEmpty
            ? aiGoalAdjustments
            : fallbackRationale.goalAdjustments,
        warnings: aiWarnings.isNotEmpty ? aiWarnings : fallbackRationale.warnings,
        macroReasons: aiMacroReasons.isNotEmpty ? aiMacroReasons : fallbackRationale.macroReasons,
        mealGuidance: (data['mealGuidance'] as String?)?.trim().isNotEmpty == true
            ? data['mealGuidance'] as String
            : fallbackRationale.mealGuidance,
      );
    } catch (e) {
      debugPrint('🧠 ClinicalRationale: AI reasoning failed ($e), using local fallback');
      return fallbackRationale;
    }
  }

  /// Generic fallback used when AI is unavailable.
  /// Keeps the client thin and avoids condition-specific copy in Dart.
  ClinicalRationale _buildFallbackRationale({
    required NutritionTargets targets,
    required String goal,
  }) {
    return ClinicalRationale(
      dailyCalorieTarget: targets.targetCalories,
      calorieReason: 'Calculated to support your daily energy needs and steady progress.',
      conditionAdjustments: const ['Your plan is customized around the health details in your profile.'],
      goalAdjustments: [
        goal == 'gain_muscle'
            ? 'Set up to support strength, recovery, and steady progress.'
            : goal == 'lose_weight'
                ? 'Set up to help you make steady progress toward weight loss.'
                : 'Set up to help you make steady progress toward your goals.',
      ],
      warnings: const [
        'Listen to your hunger, fullness, and energy levels as you move through the day.',
      ],
      mealGuidance: 'Keep meals balanced with a good protein source, smart carbs, and plenty of vegetables.',
      macroReasons: [
        MacroRationale(
          macro: 'Protein',
          targetG: targets.targetProtein,
          reason: 'Helps support your body and keeps meals filling.',
        ),
        MacroRationale(
          macro: 'Carbs',
          targetG: targets.targetCarbs,
          reason: 'Gives you steady energy for your day and activities.',
        ),
        MacroRationale(
          macro: 'Fat',
          targetG: targets.targetFat,
          reason: 'Adds balance to meals and helps keep them satisfying.',
        ),
      ],
    );
  }
}

// ============================================
// MODELS: UNICORN DATA STRUCTURES
// ============================================

enum ClinicalRisk { low, moderate, high }

class DailyBalanceReport {
  final DateTime timestamp;
  final MacroBalance calories;
  final MacroBalance protein;
  final MacroBalance carbs;
  final MacroBalance fat;
  final MacroBalance fiber;
  final MacroBalance sodium;
  final String metabolicInsight;
  final ClinicalRisk clinicalRiskLevel;
  final ClinicalRationale clinicalRationale;

  DailyBalanceReport({
    required this.timestamp,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.metabolicInsight,
    required this.clinicalRiskLevel,
    required this.clinicalRationale,
  });

  /// Compatibility getter for UI access
  double get caloriePercentage => calories.percentage / 100.0;

  /// Zero-state report for when no meals have been logged yet
  factory DailyBalanceReport.empty() {
    final zeroMacro = MacroBalance(
      current: 0,
      target: 2000,
      percentage: 0,
      remaining: 2000,
      isOverLimit: false,
    );
    return DailyBalanceReport(
      timestamp: DateTime.now(),
      calories: zeroMacro,
      protein: MacroBalance(current: 0, target: 50, percentage: 0, remaining: 50, isOverLimit: false),
      carbs: MacroBalance(current: 0, target: 250, percentage: 0, remaining: 250, isOverLimit: false),
      fat: MacroBalance(current: 0, target: 65, percentage: 0, remaining: 65, isOverLimit: false),
      fiber: MacroBalance(current: 0, target: 25, percentage: 0, remaining: 25, isOverLimit: false),
      sodium: MacroBalance(current: 0, target: 2300, percentage: 0, remaining: 2300, isOverLimit: false),
      metabolicInsight: 'Scan your first meal to start tracking today\'s nutrition.',
      clinicalRiskLevel: ClinicalRisk.low,
      clinicalRationale: ClinicalRationale.generic(),
    );
  }
}

/// Evidence-based reasoning behind daily nutrition targets.
/// Explains WHY specific calorie/macro targets were set based on health conditions.
class ClinicalRationale {
  final int dailyCalorieTarget;
  final String calorieReason;
  final List<String> conditionAdjustments;
  final List<String> goalAdjustments;
  final List<MacroRationale> macroReasons;
  final List<String> warnings;
  final String mealGuidance;

  ClinicalRationale({
    required this.dailyCalorieTarget,
    required this.calorieReason,
    required this.conditionAdjustments,
    required this.goalAdjustments,
    required this.macroReasons,
    required this.warnings,
    required this.mealGuidance,
  });

  bool get hasConditionAdjustments => conditionAdjustments.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  factory ClinicalRationale.generic() {
    return ClinicalRationale(
      dailyCalorieTarget: 2000,
      calorieReason: 'This is a general daily calorie goal. Add more details to your profile for a more personal estimate.',
      conditionAdjustments: [],
      goalAdjustments: [],
      macroReasons: [],
      warnings: [],
      mealGuidance: 'Try to eat 3 balanced meals with a good mix of protein, carbs, and healthy fats.',
    );
  }
}

class MacroRationale {
  final String macro;
  final int targetG;
  final String reason;

  MacroRationale({required this.macro, required this.targetG, required this.reason});
}

class MacroBalance {
  final double current;
  final double target;
  final double percentage;
  final double remaining;
  final bool isOverLimit;

  MacroBalance({
    required this.current,
    required this.target,
    required this.percentage,
    required this.remaining,
    required this.isOverLimit,
  });
}

/// UI Helper: map clinical risk level to a UI color for the Daily Ring.
Color clinicalRiskColor(ClinicalRisk risk) {
  switch (risk) {
    case ClinicalRisk.low:
      return Colors.green;
    case ClinicalRisk.moderate:
      return Colors.amber;
    case ClinicalRisk.high:
      return Colors.red;
  }
}