// lib/services/autonomous_procurement_engine.dart
// Smart Meal Planning & Grocery Suggestions
// Zero-friction execution - removes human impulse from the supply chain

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'flavor_metabolic_matrix_agent.dart' show FlavorMetabolicMatrixAgent, FlavorProfile, OptimizedMealRecommendation;
import 'transparent_kitchen_indexer.dart' show TransparentKitchenIndexer, VerificationStatus, AlternativeMeal;
import 'restaurant_meal_matcher.dart' as matcher;
import 'deep_link_cart_fulfillment.dart' as fulfillment;

/// ═══════════════════════════════════════════════════════════════════
/// AUTONOMOUS PROCUREMENT ENGINE
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Problem**: Advice without execution is worthless
/// - Meal plans ignored when user enters grocery store
/// - Impulse purchases derail metabolic progress
/// - Cognitive load of planning → decision fatigue
/// 
/// **Solution**: Full Supply Chain Autonomy
/// 1. Connects to grocery APIs (Instacart, Amazon Fresh, local)
/// 2. Builds optimal cart based on:
///    - Weekly metabolic goals
///    - Real-time glucose trends
///    - Dynamic flavor profile
/// 3. Autonomously purchases and schedules delivery
/// 4. Acts as deterministic barrier between impulse and kitchen
/// 5. Complete removal of willpower dependency
/// 
/// **Key Innovation:**
/// - Not a shopping list, but autonomous execution
/// - Adapts to real-time biometric fluctuations
/// - Preserves joy through flavor profile matching
/// - Zero cognitive load on user
/// ═══════════════════════════════════════════════════════════════════

class AutonomousProcurementEngine {
  static final AutonomousProcurementEngine _instance = AutonomousProcurementEngine._internal();
  factory AutonomousProcurementEngine() => _instance;
  AutonomousProcurementEngine._internal();
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Metabolic targets
  static const double MAX_WEEKLY_AVG_SPIKE = 45.0; // mg/dL
  static const double TARGET_TIME_IN_RANGE = 0.70; // 70%
  static const int MEAL_PLAN_DAYS = 7;
  
  // Restaurant meal integration
  final TransparentKitchenIndexer _kitchenIndexer = TransparentKitchenIndexer();
  final matcher.RestaurantMealMatcher _mealMatcher = matcher.RestaurantMealMatcher();
  final fulfillment.DeepLinkCartFulfillment _deepLink = fulfillment.DeepLinkCartFulfillment();
  
  // ═══════════════════════════════════════════════════════════════════
  // AUTONOMOUS CART BUILDING
  // ═══════════════════════════════════════════════════════════════════
  
  /// Build and execute autonomous grocery purchase
  /// Call this weekly or when metabolic trends deteriorate
  Future<ProcurementResult> executeAutonomousProcurement({
    required String userId,
    required List<double> recentGlucoseReadings,
    required FlavorProfile flavorProfile,
    required DateTime startDate,
    int daysOfFood = 7,
  }) async {
    try {
      debugPrint('🤖 Autonomous Procurement: Building optimal cart for $daysOfFood days');
      
      // Step 1: Analyze current metabolic state
      final metabolicState = _analyzeMetabolicState(recentGlucoseReadings);
      
      debugPrint('🤖 Metabolic State: TIR ${(metabolicState.timeInRange * 100).toStringAsFixed(0)}%, '
          'Avg Spike ${metabolicState.avgSpike.toStringAsFixed(0)} mg/dL');
      
      // Step 2: Determine weekly metabolic goals
      final goals = _calculateWeeklyGoals(metabolicState);
      
      // Step 3: Generate meal plan optimized for goals + flavor
      final mealPlan = await _generateOptimizedMealPlan(
        userId: userId,
        days: daysOfFood,
        goals: goals,
        flavorProfile: flavorProfile,
        metabolicState: metabolicState,
      );
      
      // Step 4: Build consolidated ingredient list
      final cart = _buildGroceryCart(mealPlan);
      
      debugPrint('🤖 Cart built: ${cart.items.length} items, '
          'total \$${cart.totalCost.toStringAsFixed(2)}');
      
      // Step 5: Optimize cart for cost + availability
      final optimizedCart = await _optimizeCart(cart, userId);
      
      // Step 6: Select optimal vendor
      final vendor = await _selectOptimalVendor(
        userId: userId,
        cart: optimizedCart,
        deliveryLocation: await _getUserDeliveryAddress(userId),
      );
      
      // Step 7: Autonomously place order
      final order = await _placeAutonomousOrder(
        userId: userId,
        cart: optimizedCart,
        vendor: vendor,
      );
      
      // Step 8: Schedule delivery
      final delivery = await _scheduleDelivery(
        userId: userId,
        order: order,
        preferredWindow: await _getOptimalDeliveryWindow(userId),
      );
      
      // Step 9: Send confirmation + meal plan
      await _sendProcurementConfirmation(
        userId: userId,
        order: order,
        mealPlan: mealPlan,
        delivery: delivery,
      );
      
      debugPrint('✅ Autonomous Procurement: Order ${order.id} placed, '
          'delivery ${delivery.estimatedArrival}');
      
      return ProcurementResult(
        success: true,
        orderId: order.id,
        vendor: vendor.name,
        itemCount: optimizedCart.items.length,
        totalCost: optimizedCart.totalCost,
        estimatedDelivery: delivery.estimatedArrival,
        mealPlan: mealPlan,
      );
      
    } catch (e) {
      debugPrint('❌ Autonomous Procurement: Error executing procurement: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // RESTAURANT MEAL INTEGRATION
  // ═══════════════════════════════════════════════════════════════════
  
  /// Generate hybrid meal plan: home cooking + restaurant verified meals
  Future<HybridMealPlan> generateHybridMealPlan({
    required String userId,
    required int days,
    required WeeklyGoals goals,
    required FlavorProfile flavorProfile,
    required Position userLocation,
    int restaurantMealsPerWeek = 3, // User preference
  }) async {
    try {
      debugPrint('🍽️ Generating hybrid meal plan: $restaurantMealsPerWeek restaurant meals/week');
      
      // Step 1: Generate base meal plan for home cooking
      final homeMealPlan = await _generateOptimizedMealPlan(
        userId: userId,
        days: days - restaurantMealsPerWeek,
        goals: goals,
        flavorProfile: flavorProfile,
        metabolicState: MetabolicState.defaultState(),
      );
      
      // Step 2: Get verified restaurant options
      final restaurants = await _kitchenIndexer.indexLocalRestaurants(
        userLocation: userLocation,
        radiusKm: 5.0,
      );
      
      final verifiedRestaurants = restaurants
          .where((r) => r.verificationStatus != VerificationStatus.notVerified)
          .toList();
      
      // Step 3: Generate restaurant meal suggestions for remaining days
      final restaurantMeals = <RestaurantMealOption>[];
      
      for (int i = 0; i < restaurantMealsPerWeek; i++) {
        // Vary by meal time
        final mealTime = i % 3 == 0 ? 'lunch' : (i % 3 == 1 ? 'dinner' : 'breakfast');
        
        final cravingHint = _generateCravingForMealTime(mealTime, flavorProfile);
        
        final match = await _mealMatcher.matchCravingToMeal(
          userId: userId,
          cravingDescription: cravingHint,
          userLocation: userLocation,
          flavorProfile: flavorProfile,
          maxAllowedSpike: goals.targetMaxSpike,
        );
        
        if (match.success && match.matches.isNotEmpty) {
          final topMatch = match.matches.first;
          
          // Generate deep link
          final deepLink = await _deepLink.generateDeepLink(
            mealMatch: topMatch,
            preferredPlatform: 'ubereats', // User preference
          );
          
          restaurantMeals.add(RestaurantMealOption(
            match: topMatch,
            deepLink: deepLink,
            dayOfWeek: i,
            mealTime: mealTime,
          ));
        }
      }
      
      debugPrint('✅ Hybrid plan: ${homeMealPlan.days.length} home meals, '
          '${restaurantMeals.length} restaurant meals');
      
      return HybridMealPlan(
        homeMeals: homeMealPlan,
        restaurantMeals: restaurantMeals,
        goals: goals,
        estimatedCost: _calculateHybridCost(homeMealPlan, restaurantMeals),
      );
      
    } catch (e) {
      debugPrint('❌ Error generating hybrid meal plan: $e');
      rethrow;
    }
  }
  
  /// Handle craving with restaurant meal suggestion
  Future<RestaurantCravingResult> handleCravingWithRestaurant({
    required String userId,
    required String cravingDescription,
    required Position userLocation,
    required FlavorProfile flavorProfile,
    required double maxAllowedSpike,
  }) async {
    try {
      debugPrint('😋 Handling craving: "$cravingDescription"');
      
      // Match craving to verified restaurant meals
      final match = await _mealMatcher.matchCravingToMeal(
        userId: userId,
        cravingDescription: cravingDescription,
        userLocation: userLocation,
        flavorProfile: flavorProfile,
        maxAllowedSpike: maxAllowedSpike,
      );
      
      if (!match.success || match.matches.isEmpty) {
        return RestaurantCravingResult.noMatches(cravingDescription);
      }
      
      // Generate deep links for top 3 matches
      final suggestions = <RestaurantSuggestion>[];
      
      for (final mealMatch in match.matches) {
        final deepLink = await _deepLink.generateDeepLink(
          mealMatch: mealMatch,
          preferredPlatform: 'ubereats',
        );
        
        suggestions.add(RestaurantSuggestion(
          match: mealMatch,
          deepLink: deepLink,
          alternatives: mealMatch.meal.alternatives,
        ));
      }
      
      return RestaurantCravingResult.success(
        craving: cravingDescription,
        suggestions: suggestions,
      );
      
    } catch (e) {
      debugPrint('❌ Error handling craving: $e');
      rethrow;
    }
  }
  
  String _generateCravingForMealTime(String mealTime, FlavorProfile profile) {
    // Generate craving hint based on meal time and user's flavor profile
    
    if (mealTime == 'breakfast') {
      return 'Light and energizing breakfast';
    }
    
    if (mealTime == 'lunch') {
      if (profile.preferredCuisines.isNotEmpty) {
        final cuisine = profile.preferredCuisines.keys.first;
        return 'Something filling from $cuisine cuisine';
      }
      return 'Filling lunch with protein';
    }
    
    if (mealTime == 'dinner') {
      if (profile.spicePreferences.isNotEmpty) {
        return 'Flavorful dinner with spices';
      }
      return 'Satisfying dinner';
    }
    
    return 'Healthy meal';
  }
  
  double _calculateHybridCost(WeeklyMealPlan homePlan, List<RestaurantMealOption> restaurantMeals) {
    // Calculate total weekly cost
    double homeCost = 0.0;
    
    for (final day in homePlan.days) {
      for (final meal in day.meals) {
        // Estimate home meal cost (ingredients)
        homeCost += 5.0; // Simplified
      }
    }
    
    double restaurantCost = restaurantMeals.fold(0.0, (sum, option) => sum + option.match.meal.price);
    
    return homeCost + restaurantCost;
  }
  
  // ═══════════════════════════════════════════════════════════════════
  
  // ═══════════════════════════════════════════════════════════════════
  // METABOLIC STATE ANALYSIS
  // ═══════════════════════════════════════════════════════════════════
  
  MetabolicState _analyzeMetabolicState(List<double> readings) {
    if (readings.isEmpty) {
      return MetabolicState.defaultState();
    }
    
    // Calculate time in range (70-180 mg/dL)
    final inRange = readings.where((r) => r >= 70 && r <= 180).length;
    final timeInRange = inRange / readings.length;
    
    // Calculate average spike (deviation above baseline 90)
    final baseline = 90.0;
    final spikes = readings.where((r) => r > baseline).map((r) => r - baseline);
    final avgSpike = spikes.isEmpty ? 0.0 : spikes.reduce((a, b) => a + b) / spikes.length;
    
    // Calculate glucose variability (coefficient of variation)
    final mean = readings.reduce((a, b) => a + b) / readings.length;
    final variance = readings.map((r) => pow(r - mean, 2)).reduce((a, b) => a + b) / readings.length;
    final stdDev = sqrt(variance);
    final cv = stdDev / mean;
    
    // Determine metabolic trend
    MetabolicTrend trend;
    if (avgSpike < 35 && timeInRange > 0.75) {
      trend = MetabolicTrend.excellent;
    } else if (avgSpike < 45 && timeInRange > 0.70) {
      trend = MetabolicTrend.good;
    } else if (avgSpike < 60 && timeInRange > 0.60) {
      trend = MetabolicTrend.fair;
    } else {
      trend = MetabolicTrend.needsImprovement;
    }
    
    return MetabolicState(
      timeInRange: timeInRange,
      avgSpike: avgSpike,
      coefficientOfVariation: cv,
      trend: trend,
    );
  }
  
  WeeklyGoals _calculateWeeklyGoals(MetabolicState state) {
    // Adjust goals based on current performance
    double targetSpike;
    double targetTIR;
    
    switch (state.trend) {
      case MetabolicTrend.needsImprovement:
        // Aggressive correction needed
        targetSpike = 35.0;
        targetTIR = 0.75;
        break;
      case MetabolicTrend.fair:
        // Moderate correction
        targetSpike = 40.0;
        targetTIR = 0.72;
        break;
      case MetabolicTrend.good:
        // Maintain with slight optimization
        targetSpike = 42.0;
        targetTIR = 0.73;
        break;
      case MetabolicTrend.excellent:
        // Maintain current state
        targetSpike = 45.0;
        targetTIR = 0.75;
        break;
    }
    
    return WeeklyGoals(
      targetMaxSpike: targetSpike,
      targetTimeInRange: targetTIR,
      targetMealsPerDay: 3,
      allowSnacks: state.trend != MetabolicTrend.needsImprovement,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MEAL PLAN GENERATION
  // ═══════════════════════════════════════════════════════════════════
  
  Future<WeeklyMealPlan> _generateOptimizedMealPlan({
    required String userId,
    required int days,
    required WeeklyGoals goals,
    required FlavorProfile flavorProfile,
    required MetabolicState metabolicState,
  }) async {
    final agent = FlavorMetabolicMatrixAgent();
    final dailyMeals = <DailyMealPlan>[];
    
    for (int day = 0; day < days; day++) {
      // Generate meals for each day
      final meals = <OptimizedMealRecommendation>[];
      
      // Breakfast (lower spike target)
      final breakfast = await agent.generateJoyfulRecommendations(
        userId: userId,
        flavorProfile: flavorProfile,
        maxAllowedSpike: goals.targetMaxSpike * 0.8, // 80% of target
        count: 1,
      );
      meals.addAll([...breakfast]);
      
      // Lunch (moderate spike)
      final lunch = await agent.generateJoyfulRecommendations(
        userId: userId,
        flavorProfile: flavorProfile,
        maxAllowedSpike: goals.targetMaxSpike,
        count: 1,
      );
      meals.addAll([...lunch]);
      
      // Dinner (lowest spike target)
      final dinner = await agent.generateJoyfulRecommendations(
        userId: userId,
        flavorProfile: flavorProfile,
        maxAllowedSpike: goals.targetMaxSpike * 0.7, // 70% of target
        count: 1,
      );
      meals.addAll([...dinner]);
      
      // Optional snacks
      if (goals.allowSnacks) {
        final snacks = await _generateSnackOptions(
          flavorProfile: flavorProfile,
          maxSpike: 20.0,
        );
        meals.addAll(snacks);
      }
      
      dailyMeals.add(DailyMealPlan(
        day: day,
        meals: meals,
        totalPredictedSpike: meals.fold(0.0, (sum, m) => sum + m.predictedSpike),
      ));
    }
    
    return WeeklyMealPlan(
      days: dailyMeals,
      goals: goals,
      estimatedTimeInRange: _estimateTIR(dailyMeals),
    );
  }
  
  Future<List<OptimizedMealRecommendation>> _generateSnackOptions({
    required FlavorProfile flavorProfile,
    required double maxSpike,
  }) async {
    // Generate low-spike snack options
    return [
      OptimizedMealRecommendation(
        mealName: 'Mixed Nuts & Dark Chocolate',
        ingredients: ['almonds', 'walnuts', 'dark chocolate 85%'],
        predictedSpike: 15.0,
        hedonicScore: 0.8,
        metabolicScore: 0.95,
        totalScore: 0.88,
        culturalCuisine: 'Universal',
        substitutions: [],
        cookingInstructions: 'Pre-portioned snack pack',
      ),
    ];
  }
  
  double _estimateTIR(List<DailyMealPlan> dailyMeals) {
    // Estimate time in range based on predicted meal spikes
    final avgDailySpike = dailyMeals.fold(0.0, (sum, d) => sum + d.totalPredictedSpike) / dailyMeals.length;
    
    if (avgDailySpike < 100) return 0.80;
    if (avgDailySpike < 120) return 0.75;
    if (avgDailySpike < 140) return 0.70;
    return 0.65;
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // CART BUILDING & OPTIMIZATION
  // ═══════════════════════════════════════════════════════════════════
  
  GroceryCart _buildGroceryCart(WeeklyMealPlan mealPlan) {
    final ingredientCounts = <String, double>{};
    
    // Consolidate ingredients from all meals
    for (final day in mealPlan.days) {
      for (final meal in day.meals) {
        for (final ingredient in meal.ingredients) {
          // Estimate quantity (simplified - in production, use nutrition database)
          final quantity = _estimateIngredientQuantity(ingredient);
          ingredientCounts[ingredient] = (ingredientCounts[ingredient] ?? 0.0) + quantity;
        }
      }
    }
    
    // Convert to cart items
    final items = ingredientCounts.entries.map((entry) {
      return GroceryItem(
        name: entry.key,
        quantity: entry.value,
        unit: _getIngredientUnit(entry.key),
        estimatedPrice: _estimatePrice(entry.key, entry.value),
        category: _categorizeIngredient(entry.key),
      );
    }).toList();
    
    final totalCost = items.fold(0.0, (sum, item) => sum + item.estimatedPrice);
    
    return GroceryCart(
      items: items,
      totalCost: totalCost,
    );
  }
  
  Future<GroceryCart> _optimizeCart(GroceryCart cart, String userId) async {
    // Optimize cart for:
    // 1. Cost efficiency (bulk discounts)
    // 2. Ingredient substitutions (sales/availability)
    // 3. Portion optimization (minimize waste)
    
    final optimizedItems = <GroceryItem>[];
    
    for (final item in cart.items) {
      // Check if bulk purchase is cost-effective
      if (item.quantity > 2.0 && _supportsBulkPurchase(item.name)) {
        optimizedItems.add(item.copyWith(
          quantity: _roundUpToBulkSize(item.quantity),
          estimatedPrice: _calculateBulkPrice(item),
        ));
      } else {
        optimizedItems.add(item);
      }
    }
    
    final optimizedTotal = optimizedItems.fold(0.0, (sum, item) => sum + item.estimatedPrice);
    
    return GroceryCart(
      items: optimizedItems,
      totalCost: optimizedTotal,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // VENDOR SELECTION & ORDER PLACEMENT
  // ═══════════════════════════════════════════════════════════════════
  
  Future<GroceryVendor> _selectOptimalVendor({
    required String userId,
    required GroceryCart cart,
    required String deliveryLocation,
  }) async {
    // Evaluate vendors on:
    // 1. Availability of items
    // 2. Total cost (including fees)
    // 3. Delivery speed
    // 4. Quality ratings
    // 5. Past user satisfaction
    
    final vendors = await _getAvailableVendors(deliveryLocation);
    
    if (vendors.isEmpty) {
      throw Exception('No vendors available for location: $deliveryLocation');
    }
    
    // Score each vendor
    final scoredVendors = <_ScoredVendor>[];
    
    for (final vendor in vendors) {
      final availability = await _checkItemAvailability(vendor, cart);
      final totalCost = cart.totalCost + vendor.deliveryFee;
      final pastSatisfaction = await _getUserVendorRating(userId, vendor.id);
      
      final score = (availability * 0.40) +
                   ((1.0 - (totalCost / 200)) * 0.30) + // Normalize cost
                   (vendor.qualityRating * 0.20) +
                   (pastSatisfaction * 0.10);
      
      scoredVendors.add(_ScoredVendor(vendor: vendor, score: score));
    }
    
    scoredVendors.sort((a, b) => b.score.compareTo(a.score));
    
    final selected = scoredVendors.first.vendor;
    debugPrint('🤖 Selected vendor: ${selected.name} (score: ${scoredVendors.first.score.toStringAsFixed(2)})');
    
    return selected;
  }
  
  Future<GroceryOrder> _placeAutonomousOrder({
    required String userId,
    required GroceryCart cart,
    required GroceryVendor vendor,
  }) async {
    debugPrint('🤖 Placing autonomous order with ${vendor.name}');
    
    // Get user's payment method
    final paymentMethod = await _getUserPaymentMethod(userId);
    
    // Place order via vendor API
    // In production: Integrate with Instacart API, Amazon Fresh API, etc.
    
    // Simulate API call
    await Future.delayed(Duration(seconds: 2));
    
    final orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    
    // Store order in Firestore
    await _db
        .collection('users')
        .doc(userId)
        .collection('autonomous_grocery_orders')
        .add({
          'orderId': orderId,
          'vendorId': vendor.id,
          'vendorName': vendor.name,
          'items': cart.items.map((i) => i.toMap()).toList(),
          'totalCost': cart.totalCost + vendor.deliveryFee,
          'paymentMethod': paymentMethod,
          'status': 'processing',
          'timestamp': FieldValue.serverTimestamp(),
        });
    
    return GroceryOrder(
      id: orderId,
      vendorId: vendor.id,
      cart: cart,
      totalCost: cart.totalCost + vendor.deliveryFee,
      placedAt: DateTime.now(),
    );
  }
  
  Future<DeliverySchedule> _scheduleDelivery({
    required String userId,
    required GroceryOrder order,
    required TimeWindow preferredWindow,
  }) async {
    // Schedule delivery during user's preferred window
    final estimatedArrival = DateTime.now().add(Duration(hours: preferredWindow.hoursFromNow));
    
    return DeliverySchedule(
      orderId: order.id,
      estimatedArrival: estimatedArrival,
      window: preferredWindow,
    );
  }
  
  Future<void> _sendProcurementConfirmation({
    required String userId,
    required GroceryOrder order,
    required WeeklyMealPlan mealPlan,
    required DeliverySchedule delivery,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'type': 'autonomous_procurement',
          'title': '🤖 Your Weekly Groceries Are Ordered',
          'message': 'Order ${order.id} arriving ${_formatDeliveryTime(delivery.estimatedArrival)}. '
                     'Meal plan for ${mealPlan.days.length} days ready.',
          'orderId': order.id,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
    
    debugPrint('📱 Procurement confirmation sent to user');
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════
  
  double _estimateIngredientQuantity(String ingredient) {
    // Simplified quantity estimation
    // In production: Use nutrition database + portion planning
    return 0.25; // kg or liters
  }
  
  String _getIngredientUnit(String ingredient) {
    if (ingredient.contains('oil') || ingredient.contains('milk')) return 'L';
    return 'kg';
  }
  
  double _estimatePrice(String ingredient, double quantity) {
    // Simplified pricing
    // In production: Real-time vendor API pricing
    return quantity * 5.0; // $5 per unit
  }
  
  String _categorizeIngredient(String ingredient) {
    final lower = ingredient.toLowerCase();
    
    if (lower.contains('chicken') || lower.contains('beef') || lower.contains('fish')) {
      return 'protein';
    }
    if (lower.contains('rice') || lower.contains('quinoa') || lower.contains('pasta')) {
      return 'grains';
    }
    if (lower.contains('tomato') || lower.contains('lettuce') || lower.contains('pepper')) {
      return 'vegetables';
    }
    
    return 'other';
  }
  
  bool _supportsBulkPurchase(String ingredient) {
    return ingredient.contains('rice') || ingredient.contains('flour') || ingredient.contains('oil');
  }
  
  double _roundUpToBulkSize(double quantity) {
    // Round up to nearest bulk size (e.g., 5 kg bags)
    return (quantity / 5.0).ceil() * 5.0;
  }
  
  double _calculateBulkPrice(GroceryItem item) {
    // Bulk discount: 15% off
    return item.estimatedPrice * 0.85;
  }
  
  Future<List<GroceryVendor>> _getAvailableVendors(String location) async {
    // In production: Query vendor APIs for availability
    return [
      GroceryVendor(
        id: 'vendor_instacart',
        name: 'Instacart',
        deliveryFee: 7.99,
        qualityRating: 0.85,
        avgDeliveryMinutes: 120,
      ),
      GroceryVendor(
        id: 'vendor_amazon_fresh',
        name: 'Amazon Fresh',
        deliveryFee: 9.99,
        qualityRating: 0.90,
        avgDeliveryMinutes: 180,
      ),
    ];
  }
  
  Future<double> _checkItemAvailability(GroceryVendor vendor, GroceryCart cart) async {
    // Check what % of items are available
    // Simplified: assume 95% availability
    return 0.95;
  }
  
  Future<double> _getUserVendorRating(String userId, String vendorId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('vendor_ratings')
        .doc(vendorId)
        .get();
    
    return (snapshot.data()?['rating'] as num?)?.toDouble() ?? 0.5;
  }
  
  Future<String> _getUserDeliveryAddress(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    return userDoc.data()?['deliveryAddress'] as String? ?? 'Unknown';
  }
  
  Future<String> _getUserPaymentMethod(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    return userDoc.data()?['paymentMethod'] as String? ?? 'card_****1234';
  }
  
  Future<TimeWindow> _getOptimalDeliveryWindow(String userId) async {
    // Get user's preferred delivery time
    final userDoc = await _db.collection('users').doc(userId).get();
    final preferredHour = userDoc.data()?['preferredDeliveryHour'] as int? ?? 18;
    
    return TimeWindow(
      hoursFromNow: max(2, preferredHour - DateTime.now().hour),
      label: 'Evening',
    );
  }
  
  String _formatDeliveryTime(DateTime time) {
    final diff = time.difference(DateTime.now());
    
    if (diff.inHours < 4) return 'in ${diff.inHours} hours';
    if (diff.inDays < 1) return 'today at ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    return 'tomorrow at ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// DATA MODELS
/// ═══════════════════════════════════════════════════════════════════

class MetabolicState {
  final double timeInRange;
  final double avgSpike;
  final double coefficientOfVariation;
  final MetabolicTrend trend;
  
  const MetabolicState({
    required this.timeInRange,
    required this.avgSpike,
    required this.coefficientOfVariation,
    required this.trend,
  });
  
  factory MetabolicState.defaultState() => const MetabolicState(
    timeInRange: 0.70,
    avgSpike: 45.0,
    coefficientOfVariation: 0.25,
    trend: MetabolicTrend.fair,
  );
}

enum MetabolicTrend {
  needsImprovement,
  fair,
  good,
  excellent,
}

class WeeklyGoals {
  final double targetMaxSpike;
  final double targetTimeInRange;
  final int targetMealsPerDay;
  final bool allowSnacks;
  
  const WeeklyGoals({
    required this.targetMaxSpike,
    required this.targetTimeInRange,
    required this.targetMealsPerDay,
    required this.allowSnacks,
  });
}

// Restaurant meal integration models

class HybridMealPlan {
  final WeeklyMealPlan homeMeals;
  final List<RestaurantMealOption> restaurantMeals;
  final WeeklyGoals goals;
  final double estimatedCost;
  
  const HybridMealPlan({
    required this.homeMeals,
    required this.restaurantMeals,
    required this.goals,
    required this.estimatedCost,
  });
}

class RestaurantMealOption {
  final matcher.ScoredMealMatch match;
  final fulfillment.DeepLinkResult deepLink;
  final int dayOfWeek;
  final String mealTime;
  
  const RestaurantMealOption({
    required this.match,
    required this.deepLink,
    required this.dayOfWeek,
    required this.mealTime,
  });
}

class RestaurantCravingResult {
  final bool success;
  final String craving;
  final List<RestaurantSuggestion> suggestions;
  final String? errorMessage;
  
  const RestaurantCravingResult({
    required this.success,
    required this.craving,
    required this.suggestions,
    this.errorMessage,
  });
  
  factory RestaurantCravingResult.success({
    required String craving,
    required List<RestaurantSuggestion> suggestions,
  }) => RestaurantCravingResult(
    success: true,
    craving: craving,
    suggestions: suggestions,
  );
  
  factory RestaurantCravingResult.noMatches(String craving) => RestaurantCravingResult(
    success: false,
    craving: craving,
    suggestions: [],
    errorMessage: 'No verified restaurant meals found matching your craving',
  );
}

class RestaurantSuggestion {
  final matcher.ScoredMealMatch match;
  final fulfillment.DeepLinkResult deepLink;
  final List<AlternativeMeal> alternatives;
  
  const RestaurantSuggestion({
    required this.match,
    required this.deepLink,
    required this.alternatives,
  });
}

class WeeklyMealPlan {
  final List<DailyMealPlan> days;
  final WeeklyGoals goals;
  final double estimatedTimeInRange;
  
  const WeeklyMealPlan({
    required this.days,
    required this.goals,
    required this.estimatedTimeInRange,
  });
}

class DailyMealPlan {
  final int day;
  final List<OptimizedMealRecommendation> meals;
  final double totalPredictedSpike;
  
  const DailyMealPlan({
    required this.day,
    required this.meals,
    required this.totalPredictedSpike,
  });
}

class GroceryCart {
  final List<GroceryItem> items;
  final double totalCost;
  
  const GroceryCart({
    required this.items,
    required this.totalCost,
  });
}

class GroceryItem {
  final String name;
  final double quantity;
  final String unit;
  final double estimatedPrice;
  final String category;
  
  const GroceryItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.estimatedPrice,
    required this.category,
  });
  
  GroceryItem copyWith({
    double? quantity,
    double? estimatedPrice,
  }) => GroceryItem(
    name: name,
    quantity: quantity ?? this.quantity,
    unit: unit,
    estimatedPrice: estimatedPrice ?? this.estimatedPrice,
    category: category,
  );
  
  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'price': estimatedPrice,
    'category': category,
  };
}

class GroceryVendor {
  final String id;
  final String name;
  final double deliveryFee;
  final double qualityRating; // 0-1
  final int avgDeliveryMinutes;
  
  const GroceryVendor({
    required this.id,
    required this.name,
    required this.deliveryFee,
    required this.qualityRating,
    required this.avgDeliveryMinutes,
  });
}

class GroceryOrder {
  final String id;
  final String vendorId;
  final GroceryCart cart;
  final double totalCost;
  final DateTime placedAt;
  
  const GroceryOrder({
    required this.id,
    required this.vendorId,
    required this.cart,
    required this.totalCost,
    required this.placedAt,
  });
}

class DeliverySchedule {
  final String orderId;
  final DateTime estimatedArrival;
  final TimeWindow window;
  
  const DeliverySchedule({
    required this.orderId,
    required this.estimatedArrival,
    required this.window,
  });
}

class TimeWindow {
  final int hoursFromNow;
  final String label;
  
  const TimeWindow({
    required this.hoursFromNow,
    required this.label,
  });
}

class ProcurementResult {
  final bool success;
  final String orderId;
  final String vendor;
  final int itemCount;
  final double totalCost;
  final DateTime estimatedDelivery;
  final WeeklyMealPlan mealPlan;
  
  const ProcurementResult({
    required this.success,
    required this.orderId,
    required this.vendor,
    required this.itemCount,
    required this.totalCost,
    required this.estimatedDelivery,
    required this.mealPlan,
  });
}

class _ScoredVendor {
  final GroceryVendor vendor;
  final double score;
  
  const _ScoredVendor({
    required this.vendor,
    required this.score,
  });
}
