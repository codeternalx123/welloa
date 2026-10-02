import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Offline Service - Handles offline data caching and sync
/// Enables the app to work seamlessly without internet connection
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // Connectivity state
  bool _isOnline = true;
  bool _isInitialized = false;
  final _connectivityController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Keys for SharedPreferences
  static const String _keyPendingMeals = 'pending_meals';
  static const String _keyCachedNutritionData = 'cached_nutrition_data';
  static const String _keyCachedUserGoals = 'cached_user_goals';
  static const String _keyCachedMealPlans = 'cached_meal_plans';
  static const String _keyLastSyncTime = 'last_sync_time';

  // Getters
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Initialize offline service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check initial connectivity
      final result = await Connectivity().checkConnectivity();
      _isOnline = !result.contains(ConnectivityResult.none);
      
      // Listen for connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        final wasOffline = !_isOnline;
        _isOnline = !result.contains(ConnectivityResult.none);
        _connectivityController.add(_isOnline);
        
        debugPrint('📶 Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        
        // Auto-sync when coming back online
        if (_isOnline && wasOffline) {
          syncPendingData();
        }
      });
      
      _isInitialized = true;
      debugPrint('📶 OfflineService initialized. Online: $_isOnline');
    } catch (e) {
      debugPrint('❌ OfflineService initialization error: $e');
      _isOnline = true; // Assume online if check fails
      _isInitialized = true;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }

  // ============================================
  // MEAL CACHING & OFFLINE LOGGING
  // ============================================

  /// Cache a meal for offline sync
  Future<void> cachePendingMeal(Map<String, dynamic> mealData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMeals = prefs.getStringList(_keyPendingMeals) ?? [];
      
      // Add timestamp and ID for tracking
      mealData['_cachedAt'] = DateTime.now().toIso8601String();
      mealData['_pendingId'] = DateTime.now().millisecondsSinceEpoch.toString();
      
      pendingMeals.add(jsonEncode(mealData));
      await prefs.setStringList(_keyPendingMeals, pendingMeals);
      
      debugPrint('💾 Meal cached for offline sync: ${mealData['mealType']}');
    } catch (e) {
      debugPrint('❌ Error caching meal: $e');
    }
  }

  /// Get pending meals count
  Future<int> getPendingMealsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMeals = prefs.getStringList(_keyPendingMeals) ?? [];
      return pendingMeals.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get all pending meals
  Future<List<Map<String, dynamic>>> getPendingMeals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMeals = prefs.getStringList(_keyPendingMeals) ?? [];
      return pendingMeals.map((m) => jsonDecode(m) as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// Sync all pending meals to Firestore
  Future<void> syncPendingData() async {
    if (!_isOnline) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMeals = prefs.getStringList(_keyPendingMeals) ?? [];
      
      if (pendingMeals.isEmpty) return;
      
      debugPrint('🔄 Syncing ${pendingMeals.length} pending meals...');
      
      final firestore = FirebaseFirestore.instance;
      final successfullySynced = <String>[];
      
      for (final mealJson in pendingMeals) {
        try {
          final mealData = Map<String, dynamic>.from(jsonDecode(mealJson) as Map<String, dynamic>);
          mealData.remove('_pendingId');
          mealData.remove('_cachedAt');
          
          // Extract date key from timestamp or use current date
          final dateKey = mealData['dateKey'] as String? ?? _generateDateKey(DateTime.now());
          mealData.remove('dateKey');
          
          // Add to Firestore
          final mealsRef = firestore
              .collection('daily_nutrition')
              .doc(user.uid)
              .collection('days')
              .doc(dateKey)
              .collection('meals');
              
          await mealsRef.add({
            ...mealData,
            'timestamp': FieldValue.serverTimestamp(),
            'syncedFromOffline': true,
          });
          
          successfullySynced.add(mealJson);
          debugPrint('✅ Synced meal: ${mealData['mealType']}');
        } catch (e) {
          debugPrint('❌ Failed to sync meal: $e');
        }
      }
      
      // Remove successfully synced meals
      final remainingMeals = pendingMeals
          .where((m) => !successfullySynced.contains(m))
          .toList();
      await prefs.setStringList(_keyPendingMeals, remainingMeals);
      
      // Update last sync time
      await prefs.setString(_keyLastSyncTime, DateTime.now().toIso8601String());
      
      debugPrint('✅ Sync complete. ${successfullySynced.length} synced, ${remainingMeals.length} remaining');
    } catch (e) {
      debugPrint('❌ Sync error: $e');
    }
  }

  // ============================================
  // NUTRITION DATA CACHING
  // ============================================

  /// Cache today's nutrition data for offline access
  Future<void> cacheNutritionData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      data['_cachedAt'] = DateTime.now().toIso8601String();
      await prefs.setString(_keyCachedNutritionData, jsonEncode(data));
      debugPrint('💾 Nutrition data cached');
    } catch (e) {
      debugPrint('❌ Error caching nutrition data: $e');
    }
  }

  /// Get cached nutrition data
  Future<Map<String, dynamic>?> getCachedNutritionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_keyCachedNutritionData);
      if (cached != null) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Error reading cached nutrition data: $e');
    }
    return null;
  }

  // ============================================
  // USER GOALS CACHING
  // ============================================

  /// Cache user goals for offline access
  Future<void> cacheUserGoals(Map<String, dynamic> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      goals['_cachedAt'] = DateTime.now().toIso8601String();
      await prefs.setString(_keyCachedUserGoals, jsonEncode(goals));
      debugPrint('💾 User goals cached');
    } catch (e) {
      debugPrint('❌ Error caching user goals: $e');
    }
  }

  /// Get cached user goals
  Future<Map<String, dynamic>?> getCachedUserGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_keyCachedUserGoals);
      if (cached != null) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Error reading cached user goals: $e');
    }
    return null;
  }

  // ============================================
  // MEAL PLANS CACHING
  // ============================================

  /// Cache generated meal plan for offline viewing
  Future<void> cacheMealPlan(String planId, Map<String, dynamic> mealPlan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPlans = prefs.getString(_keyCachedMealPlans);
      final plans = cachedPlans != null 
          ? Map<String, dynamic>.from(jsonDecode(cachedPlans) as Map<String, dynamic>)
          : <String, dynamic>{};
      
      mealPlan['_cachedAt'] = DateTime.now().toIso8601String();
      plans[planId] = mealPlan;
      
      // Keep only last 5 meal plans
      if (plans.length > 5) {
        final sortedKeys = plans.keys.toList()
          ..sort((a, b) {
            final aTime = DateTime.tryParse((plans[a] as Map<String, dynamic>)['_cachedAt']?.toString() ?? '') ?? DateTime(2000);
            final bTime = DateTime.tryParse((plans[b] as Map<String, dynamic>)['_cachedAt']?.toString() ?? '') ?? DateTime(2000);
            return aTime.compareTo(bTime);
          });
        plans.remove(sortedKeys.first);
      }
      
      await prefs.setString(_keyCachedMealPlans, jsonEncode(plans));
      debugPrint('💾 Meal plan cached: $planId');
    } catch (e) {
      debugPrint('❌ Error caching meal plan: $e');
    }
  }

  /// Get cached meal plans
  Future<Map<String, dynamic>> getCachedMealPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_keyCachedMealPlans);
      if (cached != null) {
        return Map<String, dynamic>.from(jsonDecode(cached) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('❌ Error reading cached meal plans: $e');
    }
    return {};
  }

  /// Get a specific cached meal plan
  Future<Map<String, dynamic>?> getCachedMealPlan(String planId) async {
    final plans = await getCachedMealPlans();
    final plan = plans[planId];
    if (plan != null) {
      return Map<String, dynamic>.from(plan as Map<String, dynamic>);
    }
    return null;
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString(_keyLastSyncTime);
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
    } catch (e) {
      debugPrint('❌ Error reading last sync time: $e');
    }
    return null;
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPendingMeals);
      await prefs.remove(_keyCachedNutritionData);
      await prefs.remove(_keyCachedUserGoals);
      await prefs.remove(_keyCachedMealPlans);
      await prefs.remove(_keyLastSyncTime);
      debugPrint('🗑️ Cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  String _generateDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Widget to show offline status banner
class OfflineStatusBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final VoidCallback? onSyncTap;

  const OfflineStatusBanner({
    super.key,
    required this.isOnline,
    this.pendingCount = 0,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: isOnline ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOnline ? 'Back online!' : 'You\'re offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                if (pendingCount > 0)
                  Text(
                    '$pendingCount meal${pendingCount > 1 ? 's' : ''} pending sync',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOnline ? Colors.green.shade600 : Colors.orange.shade600,
                    ),
                  )
                else if (!isOnline)
                  Text(
                    'App features available offline',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
                  ),
              ],
            ),
          ),
          if (isOnline && pendingCount > 0 && onSyncTap != null)
            TextButton(
              onPressed: onSyncTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: Colors.green.shade100,
              ),
              child: const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
