import '../models/clinical_graph.dart';
import '../providers/user_profile_provider.dart';

/// The core calculation engine for Wellor.
/// Handles Mifflin-St Jeor math and resolves multi-condition clinical conflicts.
class MetabolicOrchestrator {
  MetabolicOrchestrator._();
  static final MetabolicOrchestrator instance = MetabolicOrchestrator._();

  /// Calculates a precise nutritional prescription based on biometrics and the Clinical Knowledge Graph.
  Map<String, dynamic> calculatePrescription({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required double activityMultiplier,
    required List<String> userDiseases,
    required List<String> userGoals,
  }) {
    // 1. Calculate Basal Metabolic Rate (BMR) using Mifflin-St Jeor
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    bmr += (gender.toLowerCase() == 'male') ? 5 : -161;

    // 2. Calculate Total Daily Energy Expenditure (TDEE)
    double tdee = bmr * activityMultiplier;

    // 3. Resolve Multi-Condition Knowledge Graph Drivers
    double calorieMultiplier = 1.0;
    Map<String, NutrientImpact> compositeNutrientProfile = {};
    
    // Process Diseases First (Safety Tier)
    for (var disease in userDiseases) {
      final node = ClinicalKnowledgeBase.diseaseGraph[disease];
      if (node != null) {
        // Merge calorie adjustments (Multiplicative to account for metabolic strain)
        calorieMultiplier *= node.calorieAdjustment;
        _mergeNutrientDrivers(compositeNutrientProfile, node.drivers);
      }
    }

    // Process Goals Second (Optimization Tier)
    for (var goal in userGoals) {
      final node = ClinicalKnowledgeBase.goalGraph[goal];
      if (node != null) {
        calorieMultiplier *= node.calorieAdjustment;
        _mergeNutrientDrivers(compositeNutrientProfile, node.drivers);
      }
    }

    // 4. Final Calorie Prescription
    final double targetCalories = tdee * calorieMultiplier;

    // 5. Macro-Nutrient Allocation
    return {
      'bmr': bmr,
      'tdee': tdee,
      'targetCalories': targetCalories,
      'nutrientDrivers': compositeNutrientProfile,
      'macros': _calculateMacroBreakdown(targetCalories, compositeNutrientProfile),
      'clinicalWarnings': _generateWarnings(compositeNutrientProfile),
    };
  }

  /// Resolves conflicts between multiple diseases.
  /// Rule: restrictStrict (Safety) ALWAYS overrides increaseTarget (Optimization).
  void _mergeNutrientDrivers(
    Map<String, NutrientImpact> current, 
    Map<String, NutrientImpact> incoming
  ) {
    incoming.forEach((nutrient, impact) {
      if (!current.containsKey(nutrient)) {
        current[nutrient] = impact;
      } else {
        // Conflict Resolution Strategy
        // If one disease says "Increase" and another says "Strictly Restrict", 
        // the restriction wins for patient safety.
        if (impact == NutrientImpact.restrictStrict) {
          current[nutrient] = NutrientImpact.restrictStrict;
        } else if (impact == NutrientImpact.limitModerate && current[nutrient] != NutrientImpact.restrictStrict) {
          current[nutrient] = NutrientImpact.limitModerate;
        }
      }
    });
  }

  /// Distributes calories across Protein, Carbs, and Fats based on clinical needs.
  Map<String, double> _calculateMacroBreakdown(double calories, Map<String, NutrientImpact> drivers) {
    double pRatio = 0.25; // Default 25% Protein
    double cRatio = 0.45; // Default 45% Carbs
    
    // Adjust based on Knowledge Graph
    if (drivers['netCarbs'] == NutrientImpact.restrictStrict) cRatio = 0.20; // Diabetic/PCOS limit
    if (drivers['protein'] == NutrientImpact.restrictStrict) pRatio = 0.12;  // Renal limit
    if (drivers['protein'] == NutrientImpact.increaseTarget) pRatio = 0.35; // Athletic/Recovery boost

    final fRatio = 1.0 - (pRatio + cRatio);

    return {
      'proteinGrams': (calories * pRatio) / 4,
      'carbGrams': (calories * cRatio) / 4,
      'fatGrams': (calories * fRatio) / 9,
    };
  }

  List<String> _generateWarnings(Map<String, NutrientImpact> drivers) {
    List<String> warnings = [];
    drivers.forEach((nutrient, impact) {
      if (impact == NutrientImpact.restrictStrict) {
        warnings.add("Critical: This profile requires strict $nutrient restriction.");
      }
    });
    return warnings;
  }
}

/// MetabolicEngine - Public API for metabolic calculations
/// Implements singleton pattern and provides comprehensive metabolic analysis
class MetabolicEngine {
  static final MetabolicEngine _instance = MetabolicEngine._internal();
  factory MetabolicEngine() => _instance;
  MetabolicEngine._internal();

  /// Calculate BMR using Mifflin-St Jeor equation
  double calculateBMR(UserProfile user) {
    if (user.weight == null) throw ArgumentError('weight is required');
    if (user.height == null) throw ArgumentError('height is required');
    if (user.age == null) throw ArgumentError('age is required');
    if (user.gender == null || user.gender!.isEmpty) throw ArgumentError('gender is required');

    double bmr = (10 * user.weight!) + (6.25 * user.height!) - (5 * user.age!);
    bmr += (user.gender!.toLowerCase() == 'male') ? 5 : -161;
    return bmr;
  }

  /// Calculate TDEE based on BMR and activity level
  double calculateTDEE(UserProfile user, PhysicalActivityLevel activityLevel) {
    final bmr = calculateBMR(user);
    return bmr * activityLevel.multiplier;
  }

  /// Generate complete metabolic analysis
  MetabolicResult generateMetabolicAnalysis(
    UserProfile user,
    PhysicalActivityLevel activityLevel, {
    String? goal,
  }) {
    final bmr = calculateBMR(user);
    final tdee = bmr * activityLevel.multiplier;
    final macros = calculateMacros(tdee, goal ?? 'maintenance', weightKg: user.weight);

    return MetabolicResult(
      bmr: bmr,
      tdee: tdee,
      surplusCalories: tdee + 500,
      deficitCalories: tdee - 500,
      proteinGrams: macros['protein'] ?? 0,
      carbsGrams: macros['carbs'] ?? 0,
      fatGrams: macros['fat'] ?? 0,
    );
  }

  // ==================== STATIC UTILITY METHODS ====================

  /// Convert pounds to kilograms
  static double lbsToKg(double lbs) {
    if (lbs < 0) throw ArgumentError('weight cannot be negative');
    return lbs * 0.453592;
  }

  /// Convert kilograms to pounds
  static double kgToLbs(double kg) {
    if (kg < 0) throw ArgumentError('weight cannot be negative');
    return kg * 2.20462;
  }

  /// Convert feet (and optional inches) to centimeters
  static double feetToCm(int feet, {int inches = 0}) {
    if (feet < 0) throw ArgumentError('height cannot be negative');
    if (inches < 0 || inches >= 12) throw ArgumentError('inches must be 0-11');
    return (feet * 30.48) + (inches * 2.54);
  }

  /// Convert centimeters to feet and inches
  static List<double> cmToFeet(double cm) {
    if (cm < 0) throw ArgumentError('height cannot be negative');
    final totalInches = cm / 2.54;
    final feet = (totalInches / 12).floor().toDouble();
    final inches = totalInches % 12;
    return [feet, inches];
  }

  /// Calculate macro nutrients based on TDEE and goal
  static Map<String, double> calculateMacros(double tdee, String goal, {double? weightKg}) {
    if (tdee <= 0) throw ArgumentError('TDEE must be positive');

    double pRatio, cRatio, fRatio;

    switch (goal.toLowerCase()) {
      case 'muscle_gain':
        pRatio = 0.30;
        cRatio = 0.50;
        fRatio = 0.20;
        break;
      case 'weight_loss':
        pRatio = 0.35;
        cRatio = 0.45;
        fRatio = 0.20;
        break;
      case 'maintenance':
      default:
        pRatio = 0.30;
        cRatio = 0.50;
        fRatio = 0.20;
        break;
    }

    return {
      'protein': (tdee * pRatio) / 4,
      'carbs': (tdee * cRatio) / 4,
      'fat': (tdee * fRatio) / 9,
    };
  }

  /// Validate user biometrics
  static String? validateBiometrics(UserProfile user) {
    if (user.weight == null) return 'Missing weight';
    if (user.weight! <= 0) return 'Invalid weight: must be positive';
    if (user.height == null) return 'Missing height';
    if (user.height! <= 0) return 'Invalid height: must be positive';
    if (user.age == null) return 'Missing age';
    if (user.age! < 10 || user.age! > 120) return 'Age must be between 10 and 120';
    if (user.gender == null || user.gender!.isEmpty) return 'Gender is required';
    return null;
  }

  /// Estimate calories burned for an activity using MET values
  static double estimateActivityCaloriesBurn({
    required String activity,
    required int durationMinutes,
    required double weightKg,
  }) {
    // MET values for common activities
    final metValues = {
      'running': 9.8,
      'walking': 3.5,
      'cycling': 7.5,
      'swimming': 8.0,
      'weightlifting': 6.0,
      'yoga': 2.5,
    };

    final met = metValues[activity.toLowerCase()] ?? 3.5;
    return met * weightKg * (durationMinutes / 60);
  }

  /// Calculate calorie adjustment for weight change goal
  static double calculateCalorieAdjustmentForWeightChange(double weightChangeKg) {
    // 1 kg of body weight ≈ 7700 kcal
    return weightChangeKg * 7700;
  }

  /// Get activity level recommendation based on goal
  static String getActivityLevelRecommendation(String goal) {
    switch (goal.toLowerCase()) {
      case 'weight_gain':
        return 'Moderately Active (1.55x) - Allows for muscle building without excessive calorie burn';
      case 'weight_loss':
        return 'Very Active (1.725x) - Maximizes calorie deficit through activity';
      case 'maintenance':
      default:
        return 'Lightly Active (1.375x) - Balanced activity for weight maintenance';
    }
  }
}

/// Result of metabolic analysis
class MetabolicResult {
  final double bmr;
  final double tdee;
  final double surplusCalories;
  final double deficitCalories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  MetabolicResult({
    required this.bmr,
    required this.tdee,
    required this.surplusCalories,
    required this.deficitCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  String getSummary() {
    return '''
Metabolic Analysis Summary:
- BMR: ${bmr.toStringAsFixed(0)} kcal
- TDEE: ${tdee.toStringAsFixed(0)} kcal
- Protein: ${proteinGrams.toStringAsFixed(1)}g
- Carbs: ${carbsGrams.toStringAsFixed(1)}g
- Fat: ${fatGrams.toStringAsFixed(1)}g
''';
  }

  String getMacroBreakdown() {
    final total = (proteinGrams * 4) + (carbsGrams * 4) + (fatGrams * 9);
    final pPercent = ((proteinGrams * 4) / total * 100).toStringAsFixed(0);
    final cPercent = ((carbsGrams * 4) / total * 100).toStringAsFixed(0);
    final fPercent = ((fatGrams * 9) / total * 100).toStringAsFixed(0);

    return '''
Macro Breakdown:
- Protein: ${proteinGrams.toStringAsFixed(1)}g ($pPercent%)
- Carbs: ${carbsGrams.toStringAsFixed(1)}g ($cPercent%)
- Fat: ${fatGrams.toStringAsFixed(1)}g ($fPercent%)
''';
  }
}

/// Physical activity levels with multipliers
enum PhysicalActivityLevel {
  sedentary(1.2, 'Sedentary'),
  lightlyActive(1.375, 'Lightly Active'),
  moderatelyActive(1.55, 'Moderately Active'),
  veryActive(1.725, 'Very Active'),
  extraActive(1.9, 'Extra Active'),
  // Legacy aliases
  lightly(1.375, 'Lightly Active'),
  moderate(1.55, 'Moderately Active'),
  extremely(1.9, 'Extra Active');

  final double multiplier;
  final String label;

  const PhysicalActivityLevel(this.multiplier, this.label);

  static PhysicalActivityLevel fromString(String? value) {
    if (value == null) return PhysicalActivityLevel.moderatelyActive;
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'sedentary':
        return PhysicalActivityLevel.sedentary;
      case 'lightlyactive':
      case 'lightly':
        return PhysicalActivityLevel.lightlyActive;
      case 'moderatelyactive':
      case 'moderate':
        return PhysicalActivityLevel.moderatelyActive;
      case 'veryactive':
        return PhysicalActivityLevel.veryActive;
      case 'extraactive':
      case 'extremely':
        return PhysicalActivityLevel.extraActive;
      default:
        return PhysicalActivityLevel.moderatelyActive;
    }
  }
}

/// Gender enum with parsing
enum Gender {
  male,
  female,
  other;

  static Gender fromString(String? value) {
    if (value == null) return Gender.other;
    switch (value.toLowerCase()) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      default:
        return Gender.other;
    }
  }
}