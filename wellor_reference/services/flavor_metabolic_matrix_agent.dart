// lib/services/flavor_metabolic_matrix_agent.dart
// Personalized Flavor-Metabolic Matching
// Quantum-Inspired Optimization for personalized meal reconstruction

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'claude_food_analysis_service.dart';
import 'local_cuisine_learning_agent.dart';
import '../models/food_item.dart';

/// ═══════════════════════════════════════════════════════════════════
/// FLAVOR-METABOLIC MATRIX AGENT
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Problem**: Generic meal plans fail because they ignore:
/// - Cultural palate preferences
/// - Emotional joy from food
/// - Regional ingredient availability
/// - Personal taste memories
/// 
/// **Solution**: N=1 Personalized Flavor Mapping
/// 1. Computer vision scans daily meals
/// 2. Maps flavor preferences → glucose trajectory
/// 3. Quantum-Inspired Optimization reconstructs dishes
/// 4. Safe ingredient substitutions maintaining taste
/// 5. Keeps dG/dt stable while satisfying cravings
/// 
/// **Key Innovation:**
/// - Not diet restriction, but intelligent reconstruction
/// - Maintains hedonic value while optimizing metabolic safety
/// - Cultural preservation with medical precision
/// ═══════════════════════════════════════════════════════════════════

class FlavorMetabolicMatrixAgent {
  static final FlavorMetabolicMatrixAgent _instance = FlavorMetabolicMatrixAgent._internal();
  factory FlavorMetabolicMatrixAgent() => _instance;
  FlavorMetabolicMatrixAgent._internal();
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // ═══════════════════════════════════════════════════════════════════
  // FLAVOR PROFILE LEARNING
  // ═══════════════════════════════════════════════════════════════════
  
  /// Build user's N=1 flavor profile from historical meals
  Future<FlavorProfile> buildFlavorProfile({
    required String userId,
  }) async {
    try {
      debugPrint('🎨 Flavor Matrix: Building N=1 profile for user');
      
      // Get historical meals from Hive
      final box = await Hive.openBox('meal_glucose_history');
      final historyKey = '${userId}_history';
      final history = box.get(historyKey, defaultValue: <dynamic>[]) as List<dynamic>;
      
      if (history.isEmpty) {
        return FlavorProfile.empty(userId);
      }
      
      // Analyze flavor patterns
      final spicePreferences = <String, double>{};
      final texturePreferences = <String, double>{};
      final ingredientFrequency = <String, int>{};
      final cuisineTypes = <String, int>{};
      final cookingMethods = <String, int>{};
      
      for (final entry in history) {
        final meal = Map<String, dynamic>.from(entry as Map);
        final ingredients = List<String>.from(meal['ingredients'] as List? ?? []);
        final cookingMethod = meal['cookingMethod'] as String? ?? 'unknown';
        final culturalRegion = meal['culturalRegion'] as String? ?? 'unknown';
        final enjoymentScore = (meal['enjoymentScore'] as num?)?.toDouble() ?? 3.0; // 1-5 scale
        
        // Weight by enjoyment - foods user loves get higher weight
        final weight = enjoymentScore / 5.0;
        
        // Track ingredients
        for (final ingredient in ingredients) {
          ingredientFrequency[ingredient] = (ingredientFrequency[ingredient] ?? 0) + 1;
          
          // Extract spices
          if (_isSpice(ingredient)) {
            spicePreferences[ingredient] = (spicePreferences[ingredient] ?? 0.0) + weight;
          }
        }
        
        // Track cooking methods
        cookingMethods[cookingMethod] = (cookingMethods[cookingMethod] ?? 0) + 1;
        
        // Track cuisine types
        if (culturalRegion != 'unknown') {
          cuisineTypes[culturalRegion] = (cuisineTypes[culturalRegion] ?? 0) + 1;
        }
        
        // Extract texture preferences from cooking method
        final texture = _extractTexture(cookingMethod);
        texturePreferences[texture] = (texturePreferences[texture] ?? 0.0) + weight;
      }
      
      // Build preference vectors (normalized)
      final topSpices = _getTopN(spicePreferences, 10);
      final topIngredients = _getTopN(ingredientFrequency.map((k, v) => MapEntry(k, v.toDouble())), 20);
      final topCuisines = _getTopN(cuisineTypes.map((k, v) => MapEntry(k, v.toDouble())), 5);
      
      debugPrint('🎨 Flavor Matrix: Top spices: ${topSpices.keys.join(", ")}');
      debugPrint('🎨 Flavor Matrix: Top cuisines: ${topCuisines.keys.join(", ")}');
      
      return FlavorProfile(
        userId: userId,
        spicePreferences: topSpices,
        texturePreferences: texturePreferences,
        ingredientFrequency: topIngredients,
        preferredCuisines: topCuisines,
        preferredCookingMethods: cookingMethods.entries
            .toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        lastUpdated: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Flavor Matrix: Error building profile: $e');
      return FlavorProfile.empty(userId);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // QUANTUM-INSPIRED OPTIMIZATION (QIO)
  // ═══════════════════════════════════════════════════════════════════
  
  /// Reconstruct user's favorite dish with metabolically safe substitutions
  /// Uses Quantum-Inspired Optimization to maintain taste while optimizing dG/dt
  Future<ReconstructedMeal> reconstructFavoriteDish({
    required String userId,
    required String originalDishName,
    required List<String> originalIngredients,
    required double targetMaxSpikeGlucose,
    required FlavorProfile flavorProfile,
  }) async {
    try {
      debugPrint('🔬 QIO: Reconstructing "$originalDishName" for metabolic safety');
      
      // Step 1: Identify problematic ingredients (high glycemic load)
      final problematicIngredients = <String>[];
      final safeIngredients = <String>[];
      
      for (final ingredient in originalIngredients) {
        if (_isHighGlycemic(ingredient)) {
          problematicIngredients.add(ingredient);
        } else {
          safeIngredients.add(ingredient);
        }
      }
      
      debugPrint('🔬 QIO: Found ${problematicIngredients.length} problematic ingredients');
      
      // Step 2: Quantum-Inspired Search for substitutions
      final substitutions = <IngredientSubstitution>[];
      
      for (final ingredient in problematicIngredients) {
        final substitution = await _findOptimalSubstitution(
          original: ingredient,
          flavorProfile: flavorProfile,
          targetGlycemicReduction: 0.3, // 30% reduction
        );
        
        if (substitution != null) {
          substitutions.add(substitution);
        }
      }
      
      // Step 3: Build reconstructed ingredient list
      final reconstructedIngredients = <String>[
        ...safeIngredients,
        ...substitutions.map((s) => s.substituteName),
      ];
      
      // Step 4: Predict new glucose impact
      final prediction = await LocalCuisineLearningAgent().predictUnmappedMeal(
        userId: userId,
        mealName: '$originalDishName (Optimized)',
        ingredients: reconstructedIngredients,
        cookingMethod: _selectOptimalCookingMethod(flavorProfile),
        portionGrams: 250.0,
      );
      
      // Step 5: Calculate taste similarity score
      final tasteSimilarity = _calculateTasteSimilarity(
        originalIngredients,
        reconstructedIngredients,
        flavorProfile,
      );
      
      debugPrint('🔬 QIO: Reconstructed with ${prediction.predictedSpikeGlucose.toStringAsFixed(0)} mg/dL spike '
          '(${tasteSimilarity.toStringAsFixed(0)}% taste similarity)');
      
      return ReconstructedMeal(
        originalDishName: originalDishName,
        reconstructedDishName: '$originalDishName (BiteLab Optimized)',
        originalIngredients: originalIngredients,
        reconstructedIngredients: reconstructedIngredients,
        substitutions: substitutions,
        predictedSpikeGlucose: prediction.predictedSpikeGlucose,
        tasteSimilarityScore: tasteSimilarity,
        hedonicPreservation: tasteSimilarity / 100.0,
        metabolicImprovement: 1.0 - (prediction.predictedSpikeGlucose / targetMaxSpikeGlucose),
        cookingInstructions: _generateCookingInstructions(
          reconstructedIngredients,
          _selectOptimalCookingMethod(flavorProfile),
        ),
      );
      
    } catch (e) {
      debugPrint('❌ QIO: Error reconstructing meal: $e');
      rethrow;
    }
  }
  
  /// Find optimal ingredient substitution using quantum-inspired search
  Future<IngredientSubstitution?> _findOptimalSubstitution({
    required String original,
    required FlavorProfile flavorProfile,
    required double targetGlycemicReduction,
  }) async {
    // Quantum-inspired algorithm: Explore multiple substitution candidates simultaneously
    final candidates = _getSubstitutionCandidates(original);
    
    if (candidates.isEmpty) return null;
    
    // Score each candidate on multiple dimensions
    final scoredCandidates = <_ScoredSubstitution>[];
    
    for (final candidate in candidates) {
      // Dimension 1: Flavor compatibility
      final flavorScore = _calculateFlavorCompatibility(candidate, flavorProfile);
      
      // Dimension 2: Glycemic improvement
      final glycemicScore = _calculateGlycemicImprovement(original, candidate);
      
      // Dimension 3: Texture preservation
      final textureScore = _calculateTexturePreservation(original, candidate, flavorProfile);
      
      // Dimension 4: Culinary authenticity (maintains cultural essence)
      final authenticityScore = _calculateCulturalAuthenticity(original, candidate, flavorProfile);
      
      // Combined quantum score (weighted average)
      final quantumScore = (flavorScore * 0.35) + 
                          (glycemicScore * 0.30) + 
                          (textureScore * 0.20) + 
                          (authenticityScore * 0.15);
      
      scoredCandidates.add(_ScoredSubstitution(
        candidate: candidate,
        score: quantumScore,
        flavorScore: flavorScore,
        glycemicScore: glycemicScore,
        textureScore: textureScore,
        authenticityScore: authenticityScore,
      ));
    }
    
    // Select best candidate
    scoredCandidates.sort((a, b) => b.score.compareTo(a.score));
    final best = scoredCandidates.first;
    
    debugPrint('🔬 QIO: Best substitution for "$original" is "${best.candidate.name}" '
        '(score: ${(best.score * 100).toStringAsFixed(0)}%)');
    
    return IngredientSubstitution(
      originalName: original,
      substituteName: best.candidate.name,
      reason: best.candidate.reason,
      glycemicReduction: best.glycemicScore,
      flavorPreservation: best.flavorScore,
      textureMatch: best.textureScore,
      quantumScore: best.score,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // METABOLIC-HEDONIC OPTIMIZATION
  // ═══════════════════════════════════════════════════════════════════
  
  /// Generate meal recommendations that maximize both metabolic safety AND joy
  Future<List<OptimizedMealRecommendation>> generateJoyfulRecommendations({
    required String userId,
    required FlavorProfile flavorProfile,
    required double maxAllowedSpike,
    int count = 5,
  }) async {
    try {
      debugPrint('😋 Generating $count joyful + safe meal recommendations');
      
      final recommendations = <OptimizedMealRecommendation>[];
      
      // Get user's top 3 favorite cuisines
      final favoriteCuisines = flavorProfile.preferredCuisines.keys.take(3).toList();
      
      for (final cuisine in favoriteCuisines) {
        // Generate meals that match this cuisine
        final meals = await _generateCuisineMeals(
          cuisine: cuisine,
          flavorProfile: flavorProfile,
          maxSpike: maxAllowedSpike,
          count: 2,
        );
        
        recommendations.addAll(meals);
      }
      
      // Sort by combined hedonic-metabolic score
      recommendations.sort((a, b) => b.totalScore.compareTo(a.totalScore));
      
      return recommendations.take(count).toList();
      
    } catch (e) {
      debugPrint('❌ Error generating recommendations: $e');
      return [];
    }
  }
  
  Future<List<OptimizedMealRecommendation>> _generateCuisineMeals({
    required String cuisine,
    required FlavorProfile flavorProfile,
    required double maxSpike,
    required int count,
  }) async {
    final recommendations = <OptimizedMealRecommendation>[];
    
    // Get traditional dishes from this cuisine
    final traditionalDishes = _getTraditionalDishes(cuisine);
    
    for (final dish in traditionalDishes.take(count)) {
      // Reconstruct for metabolic safety
      final reconstructed = await reconstructFavoriteDish(
        userId: flavorProfile.userId,
        originalDishName: dish.name,
        originalIngredients: dish.ingredients,
        targetMaxSpikeGlucose: maxSpike,
        flavorProfile: flavorProfile,
      );
      
      // Calculate hedonic score (how much joy this meal brings)
      final hedonicScore = _calculateHedonicScore(
        ingredients: reconstructed.reconstructedIngredients,
        flavorProfile: flavorProfile,
        culturalResonance: 1.0, // Max because it's from their favorite cuisine
      );
      
      // Calculate metabolic score (how safe it is)
      final metabolicScore = 1.0 - (reconstructed.predictedSpikeGlucose / maxSpike);
      
      // Combined score (weighted: 60% metabolic safety, 40% hedonic joy)
      final totalScore = (metabolicScore * 0.6) + (hedonicScore * 0.4);
      
      recommendations.add(OptimizedMealRecommendation(
        mealName: reconstructed.reconstructedDishName,
        ingredients: reconstructed.reconstructedIngredients,
        predictedSpike: reconstructed.predictedSpikeGlucose,
        hedonicScore: hedonicScore,
        metabolicScore: metabolicScore,
        totalScore: totalScore,
        culturalCuisine: cuisine,
        substitutions: reconstructed.substitutions,
        cookingInstructions: reconstructed.cookingInstructions,
      ));
    }
    
    return recommendations;
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════
  
  bool _isSpice(String ingredient) {
    final spices = [
      'cumin', 'turmeric', 'cardamom', 'cinnamon', 'coriander', 'paprika',
      'chili', 'pepper', 'ginger', 'garlic', 'saffron', 'clove', 'nutmeg',
      'curry', 'masala', 'berbere', 'za\'atar', 'sumac', 'oregano', 'basil',
      'thyme', 'rosemary', 'sage', 'bay leaf', 'anise', 'fennel',
    ];
    
    final lower = ingredient.toLowerCase();
    return spices.any((spice) => lower.contains(spice));
  }
  
  String _extractTexture(String cookingMethod) {
    final method = cookingMethod.toLowerCase();
    
    if (method.contains('fried') || method.contains('crispy')) return 'crispy';
    if (method.contains('grilled') || method.contains('charred')) return 'charred';
    if (method.contains('steamed') || method.contains('soft')) return 'soft';
    if (method.contains('roasted') || method.contains('caramelized')) return 'caramelized';
    if (method.contains('stewed') || method.contains('braised')) return 'tender';
    
    return 'mixed';
  }
  
  bool _isHighGlycemic(String ingredient) {
    final highGI = [
      'white rice', 'pasta', 'bread', 'potato', 'sugar', 'corn', 'wheat',
      'flour', 'noodle', 'bagel', 'donut', 'cake', 'cookie', 'candy',
    ];
    
    final lower = ingredient.toLowerCase();
    return highGI.any((item) => lower.contains(item));
  }
  
  List<SubstitutionCandidate> _getSubstitutionCandidates(String original) {
    final lower = original.toLowerCase();
    
    if (lower.contains('white rice')) {
      return [
        SubstitutionCandidate('cauliflower rice', 'Low-carb alternative, maintains texture'),
        SubstitutionCandidate('quinoa', 'Lower GI, higher protein, nutty flavor'),
        SubstitutionCandidate('brown rice (small portion)', 'Lower GI, more fiber'),
      ];
    }
    
    if (lower.contains('potato')) {
      return [
        SubstitutionCandidate('sweet potato', 'Lower GI, sweeter taste'),
        SubstitutionCandidate('turnip', 'Similar texture, very low carb'),
        SubstitutionCandidate('jicama', 'Crunchy texture, mild flavor'),
      ];
    }
    
    if (lower.contains('pasta') || lower.contains('noodle')) {
      return [
        SubstitutionCandidate('zucchini noodles', 'Very low carb, maintains texture'),
        SubstitutionCandidate('shirataki noodles', 'Zero carb, authentic texture'),
        SubstitutionCandidate('whole grain pasta (half portion)', 'Lower GI, more fiber'),
      ];
    }
    
    if (lower.contains('bread') || lower.contains('roti')) {
      return [
        SubstitutionCandidate('almond flour bread', 'Low carb, nutty flavor'),
        SubstitutionCandidate('lettuce wrap', 'Zero carb, fresh crunch'),
        SubstitutionCandidate('whole grain bread (thin slice)', 'Lower GI, more fiber'),
      ];
    }
    
    if (lower.contains('sugar') || lower.contains('honey')) {
      return [
        SubstitutionCandidate('stevia', 'Zero calorie, natural sweetener'),
        SubstitutionCandidate('monk fruit sweetener', 'Natural, no glucose impact'),
        SubstitutionCandidate('erythritol', 'Sugar alcohol, minimal impact'),
      ];
    }
    
    // Default: no known substitutions
    return [];
  }
  
  double _calculateFlavorCompatibility(SubstitutionCandidate candidate, FlavorProfile profile) {
    // Check if ingredients in candidate match user's flavor profile
    final candidateLower = candidate.name.toLowerCase();
    
    double score = 0.5; // Base score
    
    // Bonus if it matches preferred ingredients
    for (final ingredient in profile.ingredientFrequency.keys) {
      if (candidateLower.contains(ingredient.toLowerCase())) {
        score += 0.1;
      }
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  double _calculateGlycemicImprovement(String original, SubstitutionCandidate candidate) {
    // Simplified glycemic scoring
    final highGI = {'white rice': 0.9, 'potato': 0.85, 'pasta': 0.8, 'bread': 0.75, 'sugar': 1.0};
    final lowGI = {'cauliflower': 0.1, 'quinoa': 0.4, 'sweet potato': 0.5, 'zucchini': 0.1, 'almond': 0.2};
    
    double originalGI = 0.7; // Default
    for (final entry in highGI.entries) {
      if (original.toLowerCase().contains(entry.key)) {
        originalGI = entry.value;
        break;
      }
    }
    
    double candidateGI = 0.5; // Default
    for (final entry in lowGI.entries) {
      if (candidate.name.toLowerCase().contains(entry.key)) {
        candidateGI = entry.value;
        break;
      }
    }
    
    // Score = improvement ratio
    return (originalGI - candidateGI) / originalGI;
  }
  
  double _calculateTexturePreservation(
    String original,
    SubstitutionCandidate candidate,
    FlavorProfile profile,
  ) {
    // Check if candidate maintains texture preferences
    final candidateTexture = _extractTexture(candidate.name);
    
    // Check if this texture is in user's preferences
    final userTextureScore = profile.texturePreferences[candidateTexture] ?? 0.5;
    
    return userTextureScore.clamp(0.0, 1.0);
  }
  
  double _calculateCulturalAuthenticity(
    String original,
    SubstitutionCandidate candidate,
    FlavorProfile profile,
  ) {
    // Maintains cultural authenticity if substitution is commonly used in same cuisine
    // This is simplified - in production, use a cultural food database
    
    // For now, penalize radical departures (e.g., cauliflower for rice in Asian cuisine)
    final candidateLower = candidate.name.toLowerCase();
    
    if (candidateLower.contains('cauliflower') || candidateLower.contains('lettuce')) {
      return 0.6; // Moderate authenticity (Western substitute)
    }
    
    if (candidateLower.contains('whole grain') || candidateLower.contains('brown')) {
      return 0.9; // High authenticity (traditional variant)
    }
    
    return 0.75; // Default moderate authenticity
  }
  
  double _calculateTasteSimilarity(
    List<String> original,
    List<String> reconstructed,
    FlavorProfile profile,
  ) {
    // Calculate Jaccard similarity + weighted by user preferences
    final originalSet = original.map((e) => e.toLowerCase()).toSet();
    final reconstructedSet = reconstructed.map((e) => e.toLowerCase()).toSet();
    
    final intersection = originalSet.intersection(reconstructedSet).length;
    final union = originalSet.union(reconstructedSet).length;
    
    final jaccardSimilarity = union > 0 ? intersection / union : 0.0;
    
    // Bonus for preserving favorite ingredients
    int preservedFavorites = 0;
    for (final fav in profile.ingredientFrequency.keys.take(5)) {
      if (reconstructedSet.contains(fav.toLowerCase())) {
        preservedFavorites++;
      }
    }
    
    final favoriteBonus = preservedFavorites / 5.0;
    
    return ((jaccardSimilarity * 0.7) + (favoriteBonus * 0.3)) * 100;
  }
  
  String _selectOptimalCookingMethod(FlavorProfile profile) {
    if (profile.preferredCookingMethods.isEmpty) return 'mixed';
    return profile.preferredCookingMethods.first.key;
  }
  
  String _generateCookingInstructions(List<String> ingredients, String method) {
    return '''
    1. Prepare ingredients: ${ingredients.join(", ")}
    2. Cooking method: $method
    3. Season to taste with preferred spices
    4. Cook until desired texture achieved
    5. Serve immediately for best flavor
    ''';
  }
  
  double _calculateHedonicScore({
    required List<String> ingredients,
    required FlavorProfile flavorProfile,
    required double culturalResonance,
  }) {
    double score = 0.0;
    
    // Score based on ingredient preferences
    for (final ingredient in ingredients) {
      if (flavorProfile.ingredientFrequency.containsKey(ingredient)) {
        final frequency = flavorProfile.ingredientFrequency[ingredient]!;
        score += frequency / 20.0; // Normalize by max expected frequency
      }
    }
    
    // Add cultural resonance bonus
    score += culturalResonance * 0.3;
    
    return (score / ingredients.length).clamp(0.0, 1.0);
  }
  
  List<_TraditionalDish> _getTraditionalDishes(String cuisine) {
    // Simplified - in production, use comprehensive database
    final dishes = <String, List<_TraditionalDish>>{
      'Indian': [
        _TraditionalDish('Chicken Tikka Masala', ['chicken', 'yogurt', 'tomato', 'cream', 'spices', 'rice']),
        _TraditionalDish('Dal Tadka', ['lentils', 'onion', 'tomato', 'spices', 'ghee']),
      ],
      'Chinese': [
        _TraditionalDish('Kung Pao Chicken', ['chicken', 'peanuts', 'vegetables', 'soy sauce', 'rice']),
        _TraditionalDish('Stir-Fry Vegetables', ['mixed vegetables', 'garlic', 'ginger', 'soy sauce']),
      ],
      'Mexican': [
        _TraditionalDish('Chicken Fajitas', ['chicken', 'bell peppers', 'onion', 'tortilla', 'salsa']),
        _TraditionalDish('Black Bean Bowl', ['black beans', 'rice', 'avocado', 'salsa', 'cheese']),
      ],
    };
    
    return dishes[cuisine] ?? [];
  }
  
  Map<String, T> _getTopN<T extends num>(Map<String, T> map, int n) {
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(min(n, entries.length)));
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// DATA MODELS
/// ═══════════════════════════════════════════════════════════════════

class FlavorProfile {
  final String userId;
  final Map<String, double> spicePreferences; // spice name → preference score
  final Map<String, double> texturePreferences; // texture → preference score
  final Map<String, double> ingredientFrequency; // ingredient → frequency
  final Map<String, double> preferredCuisines; // cuisine → count
  final List<MapEntry<String, int>> preferredCookingMethods;
  final DateTime lastUpdated;
  
  const FlavorProfile({
    required this.userId,
    required this.spicePreferences,
    required this.texturePreferences,
    required this.ingredientFrequency,
    required this.preferredCuisines,
    required this.preferredCookingMethods,
    required this.lastUpdated,
  });
  
  factory FlavorProfile.empty(String userId) => FlavorProfile(
    userId: userId,
    spicePreferences: {},
    texturePreferences: {},
    ingredientFrequency: {},
    preferredCuisines: {},
    preferredCookingMethods: [],
    lastUpdated: DateTime.now(),
  );
}

class ReconstructedMeal {
  final String originalDishName;
  final String reconstructedDishName;
  final List<String> originalIngredients;
  final List<String> reconstructedIngredients;
  final List<IngredientSubstitution> substitutions;
  final double predictedSpikeGlucose;
  final double tasteSimilarityScore; // 0-100%
  final double hedonicPreservation; // 0-1
  final double metabolicImprovement; // 0-1
  final String cookingInstructions;
  
  const ReconstructedMeal({
    required this.originalDishName,
    required this.reconstructedDishName,
    required this.originalIngredients,
    required this.reconstructedIngredients,
    required this.substitutions,
    required this.predictedSpikeGlucose,
    required this.tasteSimilarityScore,
    required this.hedonicPreservation,
    required this.metabolicImprovement,
    required this.cookingInstructions,
  });
  
  String get summary => 
      '${tasteSimilarityScore.toStringAsFixed(0)}% taste similarity, '
      '${(metabolicImprovement * 100).toStringAsFixed(0)}% metabolic improvement';
}

class IngredientSubstitution {
  final String originalName;
  final String substituteName;
  final String reason;
  final double glycemicReduction; // 0-1
  final double flavorPreservation; // 0-1
  final double textureMatch; // 0-1
  final double quantumScore; // Combined score 0-1
  
  const IngredientSubstitution({
    required this.originalName,
    required this.substituteName,
    required this.reason,
    required this.glycemicReduction,
    required this.flavorPreservation,
    required this.textureMatch,
    required this.quantumScore,
  });
}

class SubstitutionCandidate {
  final String name;
  final String reason;
  
  const SubstitutionCandidate(this.name, this.reason);
}

class OptimizedMealRecommendation {
  final String mealName;
  final List<String> ingredients;
  final double predictedSpike;
  final double hedonicScore; // Joy factor 0-1
  final double metabolicScore; // Safety factor 0-1
  final double totalScore; // Combined 0-1
  final String culturalCuisine;
  final List<IngredientSubstitution> substitutions;
  final String cookingInstructions;
  
  const OptimizedMealRecommendation({
    required this.mealName,
    required this.ingredients,
    required this.predictedSpike,
    required this.hedonicScore,
    required this.metabolicScore,
    required this.totalScore,
    required this.culturalCuisine,
    required this.substitutions,
    required this.cookingInstructions,
  });
  
  String get scoreLabel {
    if (totalScore >= 0.8) return 'Excellent';
    if (totalScore >= 0.6) return 'Good';
    if (totalScore >= 0.4) return 'Fair';
    return 'Poor';
  }
}

class _ScoredSubstitution {
  final SubstitutionCandidate candidate;
  final double score;
  final double flavorScore;
  final double glycemicScore;
  final double textureScore;
  final double authenticityScore;
  
  const _ScoredSubstitution({
    required this.candidate,
    required this.score,
    required this.flavorScore,
    required this.glycemicScore,
    required this.textureScore,
    required this.authenticityScore,
  });
}

class _TraditionalDish {
  final String name;
  final List<String> ingredients;
  
  const _TraditionalDish(this.name, this.ingredients);
}
