// lib/services/craving_interception_agent.dart
// Smart Craving Management & Healthy Alternatives
// Acts BEFORE dietary failure occurs using physiological signals

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'flavor_metabolic_matrix_agent.dart';
import '../models/glucose_context.dart';

/// ═══════════════════════════════════════════════════════════════════
/// CRAVING INTERCEPTION AGENT
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Problem**: Willpower fails when physiologically compromised
/// - Fatigue + stress + glucose dip = junk food consumption
/// - By the time user "craves", decision is already made
/// - Reactive approaches fail after impulse triggers
/// 
/// **Solution**: Predictive Pre-Crime Interception
/// 1. Fuse edge wearable data (HRV, sleep debt, cortisol proxies)
/// 2. Detect physiological state indicating low willpower
/// 3. Predict craving BEFORE conscious awareness
/// 4. Autonomously pre-order taste-aligned, high-satiety meal
/// 5. Intercept before failure occurs
/// 
/// **Key Innovation:**
/// - Act on physiological signals, not self-reported cravings
/// - Autonomous execution (pre-order delivery)
/// - Preserves hedonic satisfaction while preventing metabolic damage
/// ═══════════════════════════════════════════════════════════════════

class CravingInterceptionAgent {
  static final CravingInterceptionAgent _instance = CravingInterceptionAgent._internal();
  factory CravingInterceptionAgent() => _instance;
  CravingInterceptionAgent._internal();
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Physiological thresholds for craving prediction
  static const double LOW_HRV_THRESHOLD = 40.0; // ms (indicating high stress)
  static const double HIGH_STRESS_SCORE = 7.0; // 0-10 scale
  static const double LOW_GLUCOSE_THRESHOLD = 75.0; // mg/dL
  static const int SLEEP_DEBT_HOURS = 2; // Cumulative hours
  static const double WILLPOWER_CRISIS_THRESHOLD = 0.7; // 0-1 scale
  
  // ═══════════════════════════════════════════════════════════════════
  // CONTINUOUS MONITORING
  // ═══════════════════════════════════════════════════════════════════
  
  /// Monitor physiological signals for craving risk
  /// Call this every 15-30 minutes from background service
  Future<CravingRiskAssessment> assessCravingRisk({
    required String userId,
    required double currentGlucose,
    required double heartRateVariability,
    required int sleepDebtMinutes,
    required double stressScore, // 0-10 from wearable or self-report
    required DateTime lastMealTime,
    required String currentLocation,
  }) async {
    try {
      debugPrint('🚨 Craving Interception: Assessing risk for user');
      
      // Calculate time since last meal
      final hoursSinceLastMeal = DateTime.now().difference(lastMealTime).inHours;
      
      // Component 1: Glucose state (30% weight)
      final glucoseRisk = _assessGlucoseRisk(currentGlucose, hoursSinceLastMeal);
      
      // Component 2: Stress/HRV state (25% weight)
      final stressRisk = _assessStressRisk(heartRateVariability, stressScore);
      
      // Component 3: Sleep debt (20% weight)
      final sleepRisk = _assessSleepDebtRisk(sleepDebtMinutes);
      
      // Component 4: Temporal pattern (15% weight)
      final temporalRisk = await _assessTemporalRisk(userId, hoursSinceLastMeal);
      
      // Component 5: Environmental context (10% weight)
      final environmentalRisk = _assessEnvironmentalRisk(currentLocation);
      
      // Combined willpower depletion score
      final willpowerDepletion = (glucoseRisk * 0.30) +
                                (stressRisk * 0.25) +
                                (sleepRisk * 0.20) +
                                (temporalRisk * 0.15) +
                                (environmentalRisk * 0.10);
      
      final riskLevel = _classifyRiskLevel(willpowerDepletion);
      
      debugPrint('🚨 Craving Interception: Risk level = $riskLevel '
          '(willpower depletion: ${(willpowerDepletion * 100).toStringAsFixed(0)}%)');
      
      // Determine if intervention is needed
      final shouldIntervene = willpowerDepletion >= WILLPOWER_CRISIS_THRESHOLD;
      
      if (shouldIntervene) {
        debugPrint('⚡ CRITICAL: Craving crisis detected! Initiating pre-emptive intervention');
      }
      
      return CravingRiskAssessment(
        userId: userId,
        timestamp: DateTime.now(),
        willpowerDepletion: willpowerDepletion,
        glucoseRisk: glucoseRisk,
        stressRisk: stressRisk,
        sleepRisk: sleepRisk,
        temporalRisk: temporalRisk,
        environmentalRisk: environmentalRisk,
        riskLevel: riskLevel,
        shouldIntervene: shouldIntervene,
        predictedCravingType: _predictCravingType(
          glucoseRisk,
          stressRisk,
          sleepRisk,
        ),
      );
      
    } catch (e) {
      debugPrint('❌ Craving Interception: Error assessing risk: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // AUTONOMOUS INTERVENTION
  // ═══════════════════════════════════════════════════════════════════
  
  /// Execute pre-emptive intervention BEFORE user consciously craves
  Future<InterventionResult> executePreemptiveIntervention({
    required String userId,
    required CravingRiskAssessment risk,
    required FlavorProfile flavorProfile,
    required String currentLocation,
  }) async {
    try {
      debugPrint('⚡ Executing pre-emptive craving interception');
      
      // Step 1: Generate optimal intervention meal
      final interventionMeal = await _generateInterventionMeal(
        userId: userId,
        cravingType: risk.predictedCravingType,
        flavorProfile: flavorProfile,
        urgency: risk.riskLevel,
      );
      
      // Step 2: Check if meal delivery is possible
      final deliveryAvailable = await _checkDeliveryAvailability(
        location: currentLocation,
        mealRequirements: interventionMeal,
      );
      
      if (!deliveryAvailable) {
        debugPrint('⚠️ Delivery not available, sending in-app guidance instead');
        return InterventionResult(
          success: false,
          method: InterventionMethod.inAppGuidance,
          message: 'Prepare ${interventionMeal.mealName} at home (recipe sent)',
          estimatedArrival: null,
        );
      }
      
      // Step 3: Autonomously place order
      final orderResult = await _placeAutonomousOrder(
        userId: userId,
        meal: interventionMeal,
        deliveryLocation: currentLocation,
        urgency: risk.riskLevel == CravingRiskLevel.critical,
      );
      
      // Step 4: Notify user AFTER order is placed
      await _sendInterceptionNotification(
        userId: userId,
        meal: interventionMeal,
        estimatedArrival: orderResult.estimatedArrival ?? const Duration(minutes: 30),
        reasoning: _buildReasoningExplanation(risk),
      );
      
      // Step 5: Log intervention for learning
      await _logInterventionOutcome(
        userId: userId,
        risk: risk,
        intervention: orderResult,
      );
      
      debugPrint('✅ Pre-emptive intervention executed: ${interventionMeal.mealName} '
          'arriving in ${orderResult.estimatedArrival?.inMinutes ?? 30} minutes');
      
      return orderResult;
      
    } catch (e) {
      debugPrint('❌ Craving Interception: Error executing intervention: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // RISK ASSESSMENT COMPONENTS
  // ═══════════════════════════════════════════════════════════════════
  
  double _assessGlucoseRisk(double currentGlucose, int hoursSinceLastMeal) {
    double risk = 0.0;
    
    // Low glucose = high craving risk
    if (currentGlucose < 70) {
      risk += 1.0;
    } else if (currentGlucose < 80) {
      risk += 0.7;
    } else if (currentGlucose < 90) {
      risk += 0.4;
    }
    
    // Long time since last meal
    if (hoursSinceLastMeal >= 5) {
      risk += 0.5;
    } else if (hoursSinceLastMeal >= 4) {
      risk += 0.3;
    }
    
    return risk.clamp(0.0, 1.0);
  }
  
  double _assessStressRisk(double hrv, double stressScore) {
    double risk = 0.0;
    
    // Low HRV = high stress = high craving risk
    if (hrv < 30) {
      risk += 1.0;
    } else if (hrv < 40) {
      risk += 0.7;
    } else if (hrv < 50) {
      risk += 0.4;
    }
    
    // High stress score
    if (stressScore >= 8) {
      risk += 0.8;
    } else if (stressScore >= 6) {
      risk += 0.5;
    } else if (stressScore >= 4) {
      risk += 0.2;
    }
    
    return (risk / 2).clamp(0.0, 1.0); // Average of two indicators
  }
  
  double _assessSleepDebtRisk(int sleepDebtMinutes) {
    final sleepDebtHours = sleepDebtMinutes / 60.0;
    
    if (sleepDebtHours >= 4) return 1.0;
    if (sleepDebtHours >= 3) return 0.8;
    if (sleepDebtHours >= 2) return 0.6;
    if (sleepDebtHours >= 1) return 0.3;
    
    return 0.0;
  }
  
  Future<double> _assessTemporalRisk(String userId, int hoursSinceLastMeal) async {
    // Check historical craving patterns
    final box = await Hive.openBox('craving_patterns');
    final patterns = box.get('${userId}_patterns', defaultValue: <dynamic>[]) as List<dynamic>;
    
    if (patterns.isEmpty) return 0.3; // Default moderate risk
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Check if current time matches historical craving times
    int matchingCravings = 0;
    for (final pattern in patterns) {
      final patternMap = Map<String, dynamic>.from(pattern as Map);
      final patternHour = patternMap['hour'] as int;
      
      if ((currentHour - patternHour).abs() <= 1) {
        matchingCravings++;
      }
    }
    
    // Risk increases if many past cravings occurred at this time
    return (matchingCravings / max(patterns.length, 10)).clamp(0.0, 1.0);
  }
  
  double _assessEnvironmentalRisk(String currentLocation) {
    final location = currentLocation.toLowerCase();
    
    // High-risk environments
    if (location.contains('convenience') || location.contains('gas station')) {
      return 0.9;
    }
    
    if (location.contains('mall') || location.contains('food court')) {
      return 0.7;
    }
    
    if (location.contains('restaurant') || location.contains('cafe')) {
      return 0.6;
    }
    
    if (location.contains('home') || location.contains('office')) {
      return 0.3;
    }
    
    return 0.5; // Unknown location
  }
  
  CravingRiskLevel _classifyRiskLevel(double willpowerDepletion) {
    if (willpowerDepletion >= 0.8) return CravingRiskLevel.critical;
    if (willpowerDepletion >= 0.6) return CravingRiskLevel.high;
    if (willpowerDepletion >= 0.4) return CravingRiskLevel.moderate;
    if (willpowerDepletion >= 0.2) return CravingRiskLevel.low;
    return CravingRiskLevel.minimal;
  }
  
  CravingType _predictCravingType(
    double glucoseRisk,
    double stressRisk,
    double sleepRisk,
  ) {
    // High glucose risk → craving for simple carbs/sugar
    if (glucoseRisk > 0.7) return CravingType.simpleCarbs;
    
    // High stress → craving for comfort food
    if (stressRisk > 0.7) return CravingType.comfortFood;
    
    // High sleep debt → craving for caffeine + sugar
    if (sleepRisk > 0.7) return CravingType.energyBoost;
    
    // Default: salty/savory snacks
    return CravingType.saltySnacks;
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MEAL GENERATION & DELIVERY
  // ═══════════════════════════════════════════════════════════════════
  
  Future<InterventionMeal> _generateInterventionMeal({
    required String userId,
    required CravingType cravingType,
    required FlavorProfile flavorProfile,
    required CravingRiskLevel urgency,
  }) async {
    // Generate meal that satisfies craving while maintaining metabolic safety
    final agent = FlavorMetabolicMatrixAgent();
    
    // Use the FlavorMetabolicMatrixAgent to generate personalized recommendations
    final recommendations = await agent.generateJoyfulRecommendations(
      userId: userId,
      flavorProfile: flavorProfile,
      maxAllowedSpike: 35.0, // Low spike target for craving intervention
      count: 1,
    );
    
    if (recommendations.isNotEmpty) {
      final meal = recommendations.first;
      return InterventionMeal(
        mealName: meal.mealName,
        ingredients: meal.ingredients,
        targetSatiety: 0.85,
        predictedSpikeGlucose: meal.predictedSpike,
        cravingType: cravingType,
        urgency: urgency,
      );
    }
    
    // Fallback to simple meal suggestions if agent fails
    String mealName;
    List<String> ingredients;
    double targetSatiety;
    
    switch (cravingType) {
      case CravingType.simpleCarbs:
        // High-satiety, slow-release carbs
        mealName = 'Protein-Packed Grain Bowl';
        ingredients = ['quinoa', 'chicken', 'chickpeas', 'vegetables', 'tahini'];
        targetSatiety = 0.9;
        break;
        
      case CravingType.comfortFood:
        // Culturally-aligned comfort with safe macros
        final favoriteCuisine = flavorProfile.preferredCuisines.isNotEmpty 
            ? flavorProfile.preferredCuisines.keys.first 
            : 'Mediterranean';
        mealName = '$favoriteCuisine Comfort Bowl';
        ingredients = ['rice substitute', 'protein', 'vegetables', 'spices'];
        targetSatiety = 0.85;
        break;
        
      case CravingType.energyBoost:
        // High protein + healthy fats + slow carbs
        mealName = 'Energy Power Bowl';
        ingredients = ['salmon', 'avocado', 'sweet potato', 'greens', 'nuts'];
        targetSatiety = 0.95;
        break;
        
      case CravingType.saltySnacks:
        // High-protein savory option
        mealName = 'Savory Protein Plate';
        ingredients = ['eggs', 'cheese', 'nuts', 'vegetables', 'hummus'];
        targetSatiety = 0.8;
        break;
    }
    
    return InterventionMeal(
      mealName: mealName,
      ingredients: ingredients,
      targetSatiety: targetSatiety,
      predictedSpikeGlucose: 35.0, // Low spike target
      cravingType: cravingType,
      urgency: urgency,
    );
  }
  
  /// Generate a full meal plan for craving management
  Future<List<InterventionMeal>> generateCravingMealPlan({
    required String userId,
    required FlavorProfile flavorProfile,
    required int days,
  }) async {
    final agent = FlavorMetabolicMatrixAgent();
    final mealPlan = <InterventionMeal>[];
    
    for (int day = 0; day < days; day++) {
      // Generate 3 meals per day
      final dailyRecommendations = await agent.generateJoyfulRecommendations(
        userId: userId,
        flavorProfile: flavorProfile,
        maxAllowedSpike: 40.0,
        count: 3, // Breakfast, lunch, dinner
      );
      
      for (final meal in dailyRecommendations) {
        mealPlan.add(InterventionMeal(
          mealName: meal.mealName,
          ingredients: meal.ingredients,
          targetSatiety: 0.85,
          predictedSpikeGlucose: meal.predictedSpike,
          cravingType: CravingType.comfortFood,
          urgency: CravingRiskLevel.moderate,
        ));
      }
    }
    
    return mealPlan;
  }
  
  Future<bool> _checkDeliveryAvailability({
    required String location,
    required InterventionMeal mealRequirements,
  }) async {
    // Check if delivery services are available in user's location
    // In production: Integrate with DoorDash, UberEats, local APIs
    
    // Simplified check
    if (location.toLowerCase().contains('home') || 
        location.toLowerCase().contains('office')) {
      return true;
    }
    
    return false;
  }
  
  Future<InterventionResult> _placeAutonomousOrder({
    required String userId,
    required InterventionMeal meal,
    required String deliveryLocation,
    required bool urgency,
  }) async {
    // Autonomous ordering via delivery API
    // In production: Integrate with delivery platform APIs
    
    debugPrint('📦 Placing autonomous order for ${meal.mealName}');
    
    // Simulate order placement
    await Future.delayed(Duration(seconds: 2));
    
    // Get user's preferred restaurants from history
    final restaurantId = await _selectOptimalRestaurant(
      userId: userId,
      mealRequirements: meal,
      location: deliveryLocation,
    );
    
    // Place order (simulated)
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    final estimatedArrival = Duration(minutes: urgency ? 20 : 35);
    
    // Store order in Firestore
    await _db
        .collection('users')
        .doc(userId)
        .collection('autonomous_orders')
        .add({
          'orderId': orderId,
          'mealName': meal.mealName,
          'restaurantId': restaurantId,
          'deliveryLocation': deliveryLocation,
          'estimatedArrival': estimatedArrival.inMinutes,
          'urgency': urgency,
          'timestamp': FieldValue.serverTimestamp(),
        });
    
    return InterventionResult(
      success: true,
      method: InterventionMethod.autonomousDelivery,
      message: '${meal.mealName} is on its way!',
      estimatedArrival: estimatedArrival,
      orderId: orderId,
    );
  }
  
  Future<String> _selectOptimalRestaurant({
    required String userId,
    required InterventionMeal mealRequirements,
    required String location,
  }) async {
    // Select restaurant based on:
    // 1. Past positive experiences
    // 2. Meal availability
    // 3. Delivery speed
    // 4. Quality ratings
    
    // Simplified - return mock restaurant ID
    return 'restaurant_healthy_bowl_123';
  }
  
  Future<void> _sendInterceptionNotification({
    required String userId,
    required InterventionMeal meal,
    required Duration estimatedArrival,
    required String reasoning,
  }) async {
    // Send notification AFTER order is placed
    debugPrint('📱 Sending interception notification to user');
    
    // In production: Use FCM or local notifications
    // For now, store in Firestore for UI to pick up
    
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'type': 'craving_interception',
          'title': '⚡ BiteLab Pre-Empted Your Craving',
          'message': '${meal.mealName} is arriving in ${estimatedArrival.inMinutes} minutes.',
          'reasoning': reasoning,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
  }
  
  String _buildReasoningExplanation(CravingRiskAssessment risk) {
    final reasons = <String>[];
    
    if (risk.glucoseRisk > 0.5) {
      reasons.add('Your glucose is trending low');
    }
    
    if (risk.stressRisk > 0.5) {
      reasons.add('Your HRV indicates high stress');
    }
    
    if (risk.sleepRisk > 0.5) {
      reasons.add('You have sleep debt');
    }
    
    if (risk.temporalRisk > 0.5) {
      reasons.add('This is your typical craving time');
    }
    
    final reasonsText = reasons.join(', ');
    
    return 'I detected physiological signals (${reasonsText}) that typically precede cravings. '
           'I\'ve pre-ordered a meal that satisfies your palate while keeping you metabolically safe.';
  }
  
  Future<void> _logInterventionOutcome({
    required String userId,
    required CravingRiskAssessment risk,
    required InterventionResult intervention,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('craving_interventions')
        .add({
          'riskLevel': risk.riskLevel.name,
          'willpowerDepletion': risk.willpowerDepletion,
          'interventionMethod': intervention.method.name,
          'success': intervention.success,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// DATA MODELS
/// ═══════════════════════════════════════════════════════════════════

class CravingRiskAssessment {
  final String userId;
  final DateTime timestamp;
  final double willpowerDepletion; // 0-1
  final double glucoseRisk;
  final double stressRisk;
  final double sleepRisk;
  final double temporalRisk;
  final double environmentalRisk;
  final CravingRiskLevel riskLevel;
  final bool shouldIntervene;
  final CravingType predictedCravingType;
  
  const CravingRiskAssessment({
    required this.userId,
    required this.timestamp,
    required this.willpowerDepletion,
    required this.glucoseRisk,
    required this.stressRisk,
    required this.sleepRisk,
    required this.temporalRisk,
    required this.environmentalRisk,
    required this.riskLevel,
    required this.shouldIntervene,
    required this.predictedCravingType,
  });
}

enum CravingRiskLevel {
  minimal,
  low,
  moderate,
  high,
  critical,
}

enum CravingType {
  simpleCarbs,
  comfortFood,
  energyBoost,
  saltySnacks,
}

class InterventionMeal {
  final String mealName;
  final List<String> ingredients;
  final double targetSatiety; // 0-1
  final double predictedSpikeGlucose;
  final CravingType cravingType;
  final CravingRiskLevel urgency;
  
  const InterventionMeal({
    required this.mealName,
    required this.ingredients,
    required this.targetSatiety,
    required this.predictedSpikeGlucose,
    required this.cravingType,
    required this.urgency,
  });
}

class InterventionResult {
  final bool success;
  final InterventionMethod method;
  final String message;
  final Duration? estimatedArrival;
  final String? orderId;
  
  const InterventionResult({
    required this.success,
    required this.method,
    required this.message,
    this.estimatedArrival,
    this.orderId,
  });
}

enum InterventionMethod {
  autonomousDelivery,
  inAppGuidance,
  voiceCoaching,
}
