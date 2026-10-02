import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// �️ **UBER EATS INTEGRATION SERVICE**
/// Restaurant menu integration for metabolic food sourcing via Uber Eats.
/// 
/// **Supported Platform:**
/// - Uber Eats API - Global restaurant delivery platform
///
/// **Core Mission:**
/// Connect to Uber Eats restaurant menus to find metabolically safe meal options.
/// Run glycemic simulation on available menu data.
///
/// 🏗️ **PRODUCTION TODO:**
/// 1. Obtain Uber Eats API credentials (B2B partnership)
/// 2. Implement OAuth/API key rotation
/// 3. Set up webhook handlers for order status
/// 4. Add caching layer for menu data (Redis)
/// 5. Implement rate limiting and circuit breakers

// ============================================================================
// ENUMS
// ============================================================================

enum CloudKitchenPlatform {
  uberEats,      // Uber Eats - Global
}

enum MenuItemAvailability {
  available,
  outOfStock,
  temporarilyUnavailable,
  notInRegion,
}

enum IngredientVerificationStatus {
  verified,       // Exact match with generated meal
  partialMatch,   // Close match, minor substitutions
  mismatch,       // Significant differences
  unknown,        // Platform doesn't provide ingredient data
}

// ============================================================================
// MODELS
// ============================================================================

/// Represents Uber Eats platform availability in a geographic region
class PlatformAvailability {
  final CloudKitchenPlatform platform;
  final String platformName;
  final bool isAvailable;
  final String? unavailabilityReason;
  final List<String> supportedCountries;
  final String apiEndpoint;

  PlatformAvailability({
    required this.platform,
    required this.platformName,
    required this.isAvailable,
    this.unavailabilityReason,
    required this.supportedCountries,
    required this.apiEndpoint,
  });
}

/// Restaurant menu item from Uber Eats with ingredient data
class CloudKitchenMenuItem {
  final String itemId;
  final String itemName;
  final String? localName;
  final CloudKitchenPlatform platform;
  final String brandName;
  
  // Ingredient Data (The Gold Standard)
  final List<IngredientData> ingredients;
  final Map<String, double> macronutrients; // {protein: 25.5g, carbs: 45.2g, ...}
  final double? glycemicIndex;
  final double? glycemicLoad;
  
  // Availability
  final MenuItemAvailability availability;
  final double priceInLocalCurrency;
  final String currencyCode;
  final int estimatedPrepTimeMinutes;
  
  // Verification Metadata
  final DateTime lastVerified;
  final String dataSource; // "kitopi_api", "rebel_os", etc.
  final bool isScientificallyVerified; // Premium platforms only

  CloudKitchenMenuItem({
    required this.itemId,
    required this.itemName,
    this.localName,
    required this.platform,
    required this.brandName,
    required this.ingredients,
    required this.macronutrients,
    this.glycemicIndex,
    this.glycemicLoad,
    required this.availability,
    required this.priceInLocalCurrency,
    required this.currencyCode,
    required this.estimatedPrepTimeMinutes,
    required this.lastVerified,
    required this.dataSource,
    this.isScientificallyVerified = false,
  });
}

/// Ingredient with precise weight and sourcing data
class IngredientData {
  final String ingredientName;
  final double weightInGrams;
  final String? sourceCountry;
  final List<String> allergens;
  final bool isOrganic;
  final String? brandOrSupplier;
  
  // Nutritional breakdown for this specific ingredient
  final Map<String, double>? micronutrients; // {vitaminC: 12mg, iron: 2.5mg, ...}

  IngredientData({
    required this.ingredientName,
    required this.weightInGrams,
    this.sourceCountry,
    required this.allergens,
    this.isOrganic = false,
    this.brandOrSupplier,
    this.micronutrients,
  });
}

/// Order placed through cloud kitchen platform
class CloudKitchenOrder {
  final String orderId;
  final CloudKitchenPlatform platform;
  final String platformOrderId; // External order ID
  final List<CloudKitchenMenuItem> items;
  final double totalPrice;
  final String currencyCode;
  final String deliveryAddress;
  final String? deepLink; // For platform-specific order tracking
  final DateTime orderTime;
  final DateTime estimatedDeliveryTime;

  CloudKitchenOrder({
    required this.orderId,
    required this.platform,
    required this.platformOrderId,
    required this.items,
    required this.totalPrice,
    required this.currencyCode,
    required this.deliveryAddress,
    this.deepLink,
    required this.orderTime,
    required this.estimatedDeliveryTime,
  });
}

/// Ingredient verification result comparing generated meal vs platform data
class IngredientVerificationResult {
  final String mealName;
  final CloudKitchenMenuItem platformItem;
  final IngredientVerificationStatus status;
  final List<String> matchedIngredients;
  final List<String> missingIngredients;
  final List<String> extraIngredients;
  final bool isSafeForUser;
  final List<String> healthWarnings; // Allergen conflicts, etc.
  final double confidenceScore; // 0.0 - 1.0

  IngredientVerificationResult({
    required this.mealName,
    required this.platformItem,
    required this.status,
    required this.matchedIngredients,
    required this.missingIngredients,
    required this.extraIngredients,
    required this.isSafeForUser,
    required this.healthWarnings,
    required this.confidenceScore,
  });
}

// ============================================================================
// SERVICE
// ============================================================================

class CloudKitchenService {
  // API Configuration (🏗️ PRODUCTION: Load from environment variables)
  static const String _kitopiApiKey = 'YOUR_KITOPI_B2B_API_KEY';
  static const String _kitopiApiUrl = 'https://api.kitopi.com/v1';
  
  static const String _rebelFoodsApiKey = 'YOUR_REBEL_FOODS_API_KEY';
  static const String _rebelFoodsApiUrl = 'https://api.rebelfoods.com/v2';
  
  static const String _otterApiKey = 'YOUR_OTTER_API_KEY'; // CloudKitchens aggregator
  static const String _otterApiUrl = 'https://api.otter.com/v1';
  
  static const String _kitchInApiKey = 'YOUR_KITCHIN_API_KEY';
  static const String _kitchInApiUrl = 'https://api.kitch-in.com/v1';

  static const Duration _apiTimeout = Duration(seconds: 10);

  // ============================================================================
  // LOCATION-BASED PLATFORM DISCOVERY
  // ============================================================================

  /// Request user location and determine available cloud kitchen platforms
  static Future<List<PlatformAvailability>> getAvailablePlatforms({
    required Position userLocation,
  }) async {
    debugPrint('🌍 CloudKitchenService: Discovering platforms for location: ${userLocation.latitude}, ${userLocation.longitude}');

    final platformCheck = await _checkUberEatsAvailability(userLocation);

    final availablePlatforms = platformCheck.isAvailable ? [platformCheck] : <PlatformAvailability>[];
    
    debugPrint('✅ Found ${availablePlatforms.length} available platforms');
    return [platformCheck]; // Return for user to see coverage
  }

  static Future<PlatformAvailability> _checkUberEatsAvailability(Position location) async {
    try {
      // 🏗️ PRODUCTION: Call Uber Eats API
      // GET /api/v1/service-area?lat={lat}&lng={lng}
      
      // Uber Eats operates globally in 500+ cities
      
      return PlatformAvailability(
        platform: CloudKitchenPlatform.uberEats,
        platformName: 'Uber Eats',
        isAvailable: true, // Global coverage - check specific location in production
        supportedCountries: ['Global - 500+ cities worldwide'],
        apiEndpoint: _kitopiApiUrl, // TODO: Replace with Uber Eats API endpoint
      );
    } catch (e) {
      debugPrint('❌ Uber Eats availability check failed: $e');
      return PlatformAvailability(
        platform: CloudKitchenPlatform.uberEats,
        platformName: 'Uber Eats',
        isAvailable: false,
        unavailabilityReason: 'Service check failed',
        supportedCountries: ['Global'],
        apiEndpoint: _kitopiApiUrl,
      );
    }
  }

  /// Helper: Check if location is in specified country codes
  static Future<bool> _isInRegion(Position location, List<String> countryCodes) async {
    // 🏗️ PRODUCTION: Use reverse geocoding API (Google Maps, Mapbox)
    // For now, return true for testing
    return true; // Mock implementation
  }

  // ============================================================================
  // MENU SEARCH WITH INGREDIENT DATA
  // ============================================================================

  /// Search for meals matching AI-generated criteria with verified ingredients
  static Future<List<CloudKitchenMenuItem>> searchMenuItems({
    required String mealName,
    required Position userLocation,
    List<CloudKitchenPlatform>? preferredPlatforms,
    Map<String, dynamic>? dietaryRestrictions,
  }) async {
    debugPrint('🔍 CloudKitchenService: Searching for "$mealName" near location');

    final availablePlatforms = await getAvailablePlatforms(userLocation: userLocation);
    final activePlatforms = preferredPlatforms ?? 
        availablePlatforms.where((p) => p.isAvailable).map((p) => p.platform).toList();

    // Parallel search across all available platforms
    final searchResults = await Future.wait(
      activePlatforms.map((platform) => _searchPlatformMenu(
        platform: platform,
        query: mealName,
        location: userLocation,
        dietaryRestrictions: dietaryRestrictions,
      ))
    );

    // Flatten results and sort by ingredient data quality
    final allItems = searchResults.expand((list) => list).toList();
    allItems.sort((a, b) {
      // Prioritize scientifically verified items
      if (a.isScientificallyVerified && !b.isScientificallyVerified) return -1;
      if (!a.isScientificallyVerified && b.isScientificallyVerified) return 1;
      
      // Then by ingredient data completeness
      final aScore = a.ingredients.length * (a.glycemicIndex != null ? 2 : 1);
      final bScore = b.ingredients.length * (b.glycemicIndex != null ? 2 : 1);
      return bScore.compareTo(aScore);
    });

    debugPrint('✅ Found ${allItems.length} matching menu items');
    return allItems;
  }

  static Future<List<CloudKitchenMenuItem>> _searchPlatformMenu({
    required CloudKitchenPlatform platform,
    required String query,
    required Position location,
    Map<String, dynamic>? dietaryRestrictions,
  }) async {
    try {
      switch (platform) {
        case CloudKitchenPlatform.uberEats:
          return await _searchUberEatsMenu(query, location, dietaryRestrictions);
      }
    } catch (e) {
      debugPrint('❌ Search failed for $platform: $e');
      return [];
    }
  }

  // ============================================================================
  // PLATFORM-SPECIFIC IMPLEMENTATIONS
  // ============================================================================

  static Future<List<CloudKitchenMenuItem>> _searchUberEatsMenu(
    String query,
    Position location,
    Map<String, dynamic>? dietaryRestrictions,
  ) async {
    // 🏗️ PRODUCTION: Implement Uber Eats API
    // GET /api/v1/restaurants/search
    // {
    //   "query": "Grilled Chicken Salad",
    //   "lat": 25.2048,
    //   "lng": 55.2708,
    //   "dietary_filters": ["vegetarian", "gluten_free"]
    // }
    
    debugPrint('🔍 Searching Uber Eats menu for: $query');
    
    // Mock response
    return [
      CloudKitchenMenuItem(
        itemId: 'ubereats_001',
        itemName: query,
        platform: CloudKitchenPlatform.uberEats,
        brandName: 'Local Restaurant (via Uber Eats)',
        ingredients: [
          IngredientData(
            ingredientName: 'Grilled Chicken Breast',
            weightInGrams: 150.0,
            allergens: [],
            sourceCountry: 'UAE',
            brandOrSupplier: 'Al Rawdah Poultry',
          ),
          IngredientData(
            ingredientName: 'Romaine Lettuce',
            weightInGrams: 80.0,
            allergens: [],
            isOrganic: true,
          ),
          IngredientData(
            ingredientName: 'Cherry Tomatoes',
            weightInGrams: 50.0,
            allergens: [],
          ),
        ],
        macronutrients: {
          'protein': 35.5,
          'carbs': 12.3,
          'fat': 8.5,
          'fiber': 4.2,
          'calories': 265.0,
        },
        glycemicIndex: 35.0,
        glycemicLoad: 4.3,
        availability: MenuItemAvailability.available,
        priceInLocalCurrency: 45.0,
        currencyCode: 'AED',
        estimatedPrepTimeMinutes: 15,
        lastVerified: DateTime.now(),
        dataSource: 'ubereats_api',
        isScientificallyVerified: true,
      ),
    ];
  }

  // ============================================================================
  // ORDER PLACEMENT WITH DEEP LINKING
  // ============================================================================

  /// Place order through cloud kitchen platform with deep link
  static Future<CloudKitchenOrder?> placeOrder({
    required CloudKitchenMenuItem item,
    required String deliveryAddress,
    required Position deliveryLocation,
    required String userId,
  }) async {
    debugPrint('🛒 CloudKitchenService: Placing order for ${item.itemName} via ${item.platform}');

    try {
      switch (item.platform) {
        case CloudKitchenPlatform.uberEats:
          return await _placeUberEatsOrder(item, deliveryAddress, deliveryLocation, userId);
      }
    } catch (e) {
      debugPrint('❌ Order placement failed: $e');
      return null;
    }
  }

  static Future<CloudKitchenOrder> _placeUberEatsOrder(
    CloudKitchenMenuItem item,
    String deliveryAddress,
    Position deliveryLocation,
    String userId,
  ) async {
    // 🏗️ PRODUCTION: POST /api/v1/orders to Uber Eats
    // Returns order ID and deep link for tracking
    
    final orderId = 'metOS_${DateTime.now().millisecondsSinceEpoch}';
    final platformOrderId = 'ubereats_${DateTime.now().millisecondsSinceEpoch}';
    
    return CloudKitchenOrder(
      orderId: orderId,
      platform: CloudKitchenPlatform.uberEats,
      platformOrderId: platformOrderId,
      items: [item],
      totalPrice: item.priceInLocalCurrency,
      currencyCode: item.currencyCode,
      deliveryAddress: deliveryAddress,
      deepLink: 'ubereats://orders/$platformOrderId', // Deep link for tracking
      orderTime: DateTime.now(),
      estimatedDeliveryTime: DateTime.now().add(Duration(minutes: 30 + item.estimatedPrepTimeMinutes)),
    );
  }

  // ============================================================================
  // DEEP LINKING & TRACKING
  // ============================================================================

  /// Open platform-specific app/website via deep link
  static Future<bool> openPlatformDeepLink(String deepLink) async {
    debugPrint('🔗 Opening deep link: $deepLink');
    
    // 🏗️ PRODUCTION: Use url_launcher to open deep link
    // await launchUrl(Uri.parse(deepLink), mode: LaunchMode.externalApplication);
    
    return true; // Mock success
  }

  /// Track order status via platform API
  static Future<Map<String, dynamic>> trackOrder({
    required String platformOrderId,
    required CloudKitchenPlatform platform,
  }) async {
    debugPrint('📍 Tracking order: $platformOrderId on $platform');
    
    // 🏗️ PRODUCTION: Implement platform-specific tracking APIs
    return {
      'status': 'preparing',
      'estimatedDeliveryTime': DateTime.now().add(Duration(minutes: 25)).toIso8601String(),
      'driverLocation': null,
    };
  }
}
