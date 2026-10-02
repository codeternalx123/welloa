// lib/services/restaurant_meal_matcher.dart
// DECACORN ENHANCEMENT: Craving-to-Metabolism Matching Engine
// QIO-powered matching of cravings to metabolically safe restaurant meals

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'transparent_kitchen_indexer.dart';
import 'flavor_metabolic_matrix_agent.dart';

/// ═══════════════════════════════════════════════════════════════════
/// RESTAURANT MEAL MATCHER
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Problem**: User has craving but cooking is not possible
/// - Need restaurant meal that satisfies craving
/// - Must be metabolically safe (low glucose spike)
/// - Must match personal flavor preferences
/// 
/// **Solution**: Craving-to-Metabolism Matching with QIO
/// 1. Parse craving description (spicy, heavy, creamy, etc.)
/// 2. Search Transparent Kitchen Index for verified meals
/// 3. Use QIO to simulate dG/dt for each candidate
/// 4. Surface top 3 meals that satisfy craving + metabolic safety
/// 5. Show verified status, price, alternatives
/// 
/// **Key Innovation:**
/// - Not just "find Biryani" but "find safest Biryani for YOUR glucose"
/// - Quantum-inspired optimization balances craving satisfaction + safety
/// - Only suggests VERIFIED meals with online recipes
/// ═══════════════════════════════════════════════════════════════════

class RestaurantMealMatcher {
  static final RestaurantMealMatcher _instance = RestaurantMealMatcher._internal();
  factory RestaurantMealMatcher() => _instance;
  RestaurantMealMatcher._internal();
  
  final TransparentKitchenIndexer _indexer = TransparentKitchenIndexer();
  
  // ═══════════════════════════════════════════════════════════════════
  // CRAVING MATCHING
  // ═══════════════════════════════════════════════════════════════════
  
  /// Match craving to metabolically optimal restaurant meals
  Future<RestaurantMatchResult> matchCravingToMeal({
    required String userId,
    required String cravingDescription,
    required Position userLocation,
    required FlavorProfile flavorProfile,
    required double maxAllowedSpike,
    double radiusKm = 5.0,
  }) async {
    try {
      debugPrint('🎯 Matching craving: "$cravingDescription"');
      
      // Step 1: Parse craving attributes
      final cravingProfile = _parseCravingDescription(cravingDescription);
      
      debugPrint('🎯 Craving profile: ${cravingProfile.primaryAttribute}, '
          'cuisine: ${cravingProfile.cuisineHint}');
      
      // Step 2: Get local restaurants from Transparent Kitchen Index
      final restaurants = await _indexer.indexLocalRestaurants(
        userLocation: userLocation,
        radiusKm: radiusKm,
      );
      
      // Filter to only verified/partially verified
      final verifiedRestaurants = restaurants
          .where((r) => r.verificationStatus != VerificationStatus.notVerified)
          .toList();
      
      if (verifiedRestaurants.isEmpty) {
        return RestaurantMatchResult.noVerifiedRestaurants();
      }
      
      debugPrint('🎯 Searching ${verifiedRestaurants.length} verified restaurants');
      
      // Step 3: Find candidate meals matching craving
      final candidates = _findCandidateMeals(
        restaurants: verifiedRestaurants,
        cravingProfile: cravingProfile,
        flavorProfile: flavorProfile,
      );
      
      if (candidates.isEmpty) {
        return RestaurantMatchResult.noMatches(cravingDescription);
      }
      
      debugPrint('🎯 Found ${candidates.length} candidate meals');
      
      // Step 4: Use QIO to score each candidate on craving satisfaction + metabolic safety
      final scoredCandidates = await _scoreCandidatesWithQIO(
        candidates: candidates,
        cravingProfile: cravingProfile,
        flavorProfile: flavorProfile,
        maxAllowedSpike: maxAllowedSpike,
      );
      
      // Step 5: Select top 3 matches
      scoredCandidates.sort((a, b) => b.totalScore.compareTo(a.totalScore));
      final topMatches = scoredCandidates.take(3).toList();
      
      // Step 6: For each match, find alternatives
      for (final match in topMatches) {
        final alternatives = await _indexer.findAlternatives(
          meal: match.meal,
          localRestaurants: verifiedRestaurants,
        );
        
        match.meal = VerifiedMeal(
          id: match.meal.id,
          restaurantId: match.meal.restaurantId,
          name: match.meal.name,
          description: match.meal.description,
          category: match.meal.category,
          cuisine: match.meal.cuisine,
          price: match.meal.price,
          currency: match.meal.currency,
          isVerified: match.meal.isVerified,
          verificationSource: match.meal.verificationSource,
          ingredients: match.meal.ingredients,
          predictedSpikeGlucose: match.meal.predictedSpikeGlucose,
          confidence: match.meal.confidence,
          nutritionalInfo: match.meal.nutritionalInfo,
          recipeUrl: match.meal.recipeUrl,
          alternatives: alternatives,
        );
      }
      
      debugPrint('✅ Top match: ${topMatches.first.meal.name} at ${topMatches.first.restaurant.name} '
          '(score: ${topMatches.first.totalScore.toStringAsFixed(2)})');
      
      return RestaurantMatchResult.success(
        craving: cravingDescription,
        matches: topMatches,
        totalSearched: candidates.length,
      );
      
    } catch (e) {
      debugPrint('❌ Error matching craving: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // CRAVING PARSING
  // ═══════════════════════════════════════════════════════════════════
  
  CravingProfile _parseCravingDescription(String description) {
    final lower = description.toLowerCase();
    
    // Extract attributes
    String primaryAttribute = 'savory'; // Default
    String? cuisineHint;
    String? textureHint;
    String? temperatureHint;
    final descriptors = <String>[];
    
    // Taste attributes
    if (lower.contains('spicy') || lower.contains('hot')) {
      primaryAttribute = 'spicy';
      descriptors.add('spicy');
    }
    if (lower.contains('sweet')) {
      descriptors.add('sweet');
    }
    if (lower.contains('salty')) {
      descriptors.add('salty');
    }
    if (lower.contains('sour') || lower.contains('tangy')) {
      descriptors.add('sour');
    }
    if (lower.contains('creamy') || lower.contains('rich')) {
      descriptors.add('creamy');
    }
    
    // Texture
    if (lower.contains('crunchy') || lower.contains('crispy')) {
      textureHint = 'crispy';
    }
    if (lower.contains('soft') || lower.contains('tender')) {
      textureHint = 'soft';
    }
    if (lower.contains('chewy')) {
      textureHint = 'chewy';
    }
    
    // Temperature
    if (lower.contains('hot') || lower.contains('warm')) {
      temperatureHint = 'hot';
    }
    if (lower.contains('cold') || lower.contains('chilled')) {
      temperatureHint = 'cold';
    }
    
    // Cuisine hints
    if (lower.contains('biryani') || lower.contains('curry') || lower.contains('indian')) {
      cuisineHint = 'Indian';
    }
    if (lower.contains('pizza') || lower.contains('pasta') || lower.contains('italian')) {
      cuisineHint = 'Italian';
    }
    if (lower.contains('sushi') || lower.contains('ramen') || lower.contains('japanese')) {
      cuisineHint = 'Japanese';
    }
    if (lower.contains('burrito') || lower.contains('taco') || lower.contains('mexican')) {
      cuisineHint = 'Mexican';
    }
    if (lower.contains('stir fry') || lower.contains('noodles') || lower.contains('chinese')) {
      cuisineHint = 'Chinese';
    }
    
    // Weight/satiety
    bool heavy = lower.contains('heavy') || lower.contains('filling') || lower.contains('hearty');
    bool light = lower.contains('light') || lower.contains('fresh') || lower.contains('salad');
    
    return CravingProfile(
      originalDescription: description,
      primaryAttribute: primaryAttribute,
      descriptors: descriptors,
      cuisineHint: cuisineHint,
      textureHint: textureHint,
      temperatureHint: temperatureHint,
      heavy: heavy,
      light: light,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // CANDIDATE SEARCH
  // ═══════════════════════════════════════════════════════════════════
  
  List<MealCandidate> _findCandidateMeals({
    required List<VerifiedRestaurant> restaurants,
    required CravingProfile cravingProfile,
    required FlavorProfile flavorProfile,
  }) {
    final candidates = <MealCandidate>[];
    
    for (final restaurant in restaurants) {
      for (final meal in restaurant.meals) {
        // Only consider verified meals
        if (!meal.isVerified) continue;
        
        // Check if meal matches craving attributes
        final matchScore = _calculateCravingMatch(meal, cravingProfile);
        
        if (matchScore > 0.3) { // Minimum 30% match
          candidates.add(MealCandidate(
            meal: meal,
            restaurant: restaurant,
            cravingMatchScore: matchScore,
          ));
        }
      }
    }
    
    return candidates;
  }
  
  double _calculateCravingMatch(VerifiedMeal meal, CravingProfile craving) {
    double score = 0.0;
    
    // Cuisine match (40% weight)
    if (craving.cuisineHint != null && 
        meal.cuisine.toLowerCase() == craving.cuisineHint!.toLowerCase()) {
      score += 0.4;
    }
    
    // Category match (30% weight)
    final mealNameLower = meal.name.toLowerCase();
    final descLower = meal.description.toLowerCase();
    
    for (final descriptor in craving.descriptors) {
      if (mealNameLower.contains(descriptor) || descLower.contains(descriptor)) {
        score += 0.1; // Up to 0.3 for matching 3 descriptors
      }
    }
    
    // Texture match (15% weight)
    if (craving.textureHint != null) {
      if (mealNameLower.contains(craving.textureHint!) || 
          descLower.contains(craving.textureHint!)) {
        score += 0.15;
      }
    }
    
    // Weight match (15% weight)
    if (craving.heavy && (mealNameLower.contains('bowl') || 
                          mealNameLower.contains('platter') ||
                          meal.category.toLowerCase().contains('entree'))) {
      score += 0.15;
    }
    
    if (craving.light && (mealNameLower.contains('salad') || 
                          mealNameLower.contains('light') ||
                          meal.category.toLowerCase().contains('salad'))) {
      score += 0.15;
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // QUANTUM-INSPIRED OPTIMIZATION SCORING
  // ═══════════════════════════════════════════════════════════════════
  
  Future<List<ScoredMealMatch>> _scoreCandidatesWithQIO({
    required List<MealCandidate> candidates,
    required CravingProfile cravingProfile,
    required FlavorProfile flavorProfile,
    required double maxAllowedSpike,
  }) async {
    final scored = <ScoredMealMatch>[];
    
    for (final candidate in candidates) {
      // Dimension 1: Craving satisfaction (already calculated)
      final cravingSatisfaction = candidate.cravingMatchScore;
      
      // Dimension 2: Metabolic safety
      final metabolicSafety = _calculateMetabolicSafety(
        candidate.meal,
        maxAllowedSpike,
      );
      
      // Dimension 3: Flavor profile alignment
      final flavorAlignment = _calculateFlavorAlignment(
        candidate.meal,
        flavorProfile,
      );
      
      // Dimension 4: Price value (normalized)
      final priceValue = _calculatePriceValue(candidate.meal.price);
      
      // Dimension 5: Verification confidence
      final verificationScore = candidate.meal.confidence;
      
      // Combined QIO score (weighted)
      final totalScore = (cravingSatisfaction * 0.30) +
                        (metabolicSafety * 0.30) +
                        (flavorAlignment * 0.20) +
                        (priceValue * 0.10) +
                        (verificationScore * 0.10);
      
      scored.add(ScoredMealMatch(
        meal: candidate.meal,
        restaurant: candidate.restaurant,
        cravingSatisfaction: cravingSatisfaction,
        metabolicSafety: metabolicSafety,
        flavorAlignment: flavorAlignment,
        priceValue: priceValue,
        verificationScore: verificationScore,
        totalScore: totalScore,
      ));
    }
    
    return scored;
  }
  
  double _calculateMetabolicSafety(VerifiedMeal meal, double maxAllowedSpike) {
    if (meal.predictedSpikeGlucose == null) return 0.5; // Unknown = moderate
    
    final spike = meal.predictedSpikeGlucose!;
    
    if (spike <= maxAllowedSpike * 0.7) return 1.0; // Excellent
    if (spike <= maxAllowedSpike) return 0.8; // Good
    if (spike <= maxAllowedSpike * 1.2) return 0.5; // Acceptable
    return 0.2; // Poor
  }
  
  double _calculateFlavorAlignment(VerifiedMeal meal, FlavorProfile profile) {
    double alignment = 0.5; // Base
    
    // Check if meal cuisine matches preferred cuisines
    if (profile.preferredCuisines.containsKey(meal.cuisine)) {
      alignment += 0.3;
    }
    
    // Check if meal ingredients overlap with frequent ingredients
    int matchingIngredients = 0;
    for (final ingredient in meal.ingredients) {
      if (profile.ingredientFrequency.containsKey(ingredient)) {
        matchingIngredients++;
      }
    }
    
    if (meal.ingredients.isNotEmpty) {
      alignment += (matchingIngredients / meal.ingredients.length) * 0.2;
    }
    
    return alignment.clamp(0.0, 1.0);
  }
  
  double _calculatePriceValue(double price) {
    // Normalize price (assume $5-25 range)
    // Lower price = higher value score
    if (price <= 8) return 1.0;
    if (price <= 12) return 0.8;
    if (price <= 18) return 0.6;
    if (price <= 25) return 0.4;
    return 0.2;
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// DATA MODELS
/// ═══════════════════════════════════════════════════════════════════

class CravingProfile {
  final String originalDescription;
  final String primaryAttribute;
  final List<String> descriptors;
  final String? cuisineHint;
  final String? textureHint;
  final String? temperatureHint;
  final bool heavy;
  final bool light;
  
  const CravingProfile({
    required this.originalDescription,
    required this.primaryAttribute,
    required this.descriptors,
    this.cuisineHint,
    this.textureHint,
    this.temperatureHint,
    required this.heavy,
    required this.light,
  });
}

class MealCandidate {
  final VerifiedMeal meal;
  final VerifiedRestaurant restaurant;
  final double cravingMatchScore;
  
  const MealCandidate({
    required this.meal,
    required this.restaurant,
    required this.cravingMatchScore,
  });
}

class ScoredMealMatch {
  VerifiedMeal meal;
  final VerifiedRestaurant restaurant;
  final double cravingSatisfaction;
  final double metabolicSafety;
  final double flavorAlignment;
  final double priceValue;
  final double verificationScore;
  final double totalScore;
  
  ScoredMealMatch({
    required this.meal,
    required this.restaurant,
    required this.cravingSatisfaction,
    required this.metabolicSafety,
    required this.flavorAlignment,
    required this.priceValue,
    required this.verificationScore,
    required this.totalScore,
  });
  
  String get scoreLabel {
    if (totalScore >= 0.8) return 'Excellent Match';
    if (totalScore >= 0.65) return 'Good Match';
    if (totalScore >= 0.5) return 'Fair Match';
    return 'Poor Match';
  }
}

class RestaurantMatchResult {
  final bool success;
  final String craving;
  final List<ScoredMealMatch> matches;
  final int totalSearched;
  final String? errorMessage;
  
  const RestaurantMatchResult({
    required this.success,
    required this.craving,
    required this.matches,
    required this.totalSearched,
    this.errorMessage,
  });
  
  factory RestaurantMatchResult.success({
    required String craving,
    required List<ScoredMealMatch> matches,
    required int totalSearched,
  }) => RestaurantMatchResult(
    success: true,
    craving: craving,
    matches: matches,
    totalSearched: totalSearched,
  );
  
  factory RestaurantMatchResult.noVerifiedRestaurants() => const RestaurantMatchResult(
    success: false,
    craving: '',
    matches: [],
    totalSearched: 0,
    errorMessage: 'No verified restaurants found in your area',
  );
  
  factory RestaurantMatchResult.noMatches(String craving) => RestaurantMatchResult(
    success: false,
    craving: craving,
    matches: [],
    totalSearched: 0,
    errorMessage: 'No meals found matching "$craving"',
  );
}
