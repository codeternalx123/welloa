// lib/services/deep_link_cart_fulfillment.dart
// Deep-Link Cart Integration for Grocery Services
// Zero-friction ordering - auto-populate delivery app carts

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'transparent_kitchen_indexer.dart';
import 'restaurant_meal_matcher.dart';

/// ═══════════════════════════════════════════════════════════════════
/// DEEP LINK CART FULFILLMENT
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Problem**: Friction kills conversion
/// - User must manually search for meal in delivery app
/// - Risk of ordering wrong item (unverified)
/// - Multiple taps = decision fatigue = abandonment
/// 
/// **Solution**: Autonomous Cart Population
/// 1. Generate deep link to delivery platform (Glovo, UberEats, etc.)
/// 2. Link automatically opens app with meal in cart
/// 3. GlucoCoach Business API for direct restaurant orders
/// 4. One tap from suggestion → ready to checkout
/// 5. Zero manual search, zero wrong orders
/// 
/// **Key Innovation:**
/// - Not "here's the restaurant" but "here's your cart with exact meal"
/// - Platform-specific deep link generation
/// - Fallback chain: App → Web → GlucoCoach
/// ═══════════════════════════════════════════════════════════════════

class DeepLinkCartFulfillment {
  static final DeepLinkCartFulfillment _instance = DeepLinkCartFulfillment._internal();
  factory DeepLinkCartFulfillment() => _instance;
  DeepLinkCartFulfillment._internal();
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // ═══════════════════════════════════════════════════════════════════
  // DEEP LINK GENERATION
  // ═══════════════════════════════════════════════════════════════════
  
  /// Generate deep link to delivery platform with meal pre-added to cart
  Future<DeepLinkResult> generateDeepLink({
    required ScoredMealMatch mealMatch,
    required String preferredPlatform, // 'glovo', 'ubereats', 'doordash'
  }) async {
    try {
      debugPrint('🔗 Generating deep link for ${mealMatch.meal.name} on $preferredPlatform');
      
      // Check if restaurant is available on preferred platform
      if (!mealMatch.restaurant.deliveryPartners.contains(preferredPlatform)) {
        // Fallback to first available platform
        preferredPlatform = mealMatch.restaurant.deliveryPartners.first;
        debugPrint('⚠️ Restaurant not on preferred platform, using $preferredPlatform');
      }
      
      // Generate platform-specific deep link
      final deepLink = await _generatePlatformDeepLink(
        platform: preferredPlatform,
        restaurant: mealMatch.restaurant,
        meal: mealMatch.meal,
      );
      
      if (deepLink == null) {
        // Fallback to GlucoCoach
        return _generateGlucoCoachFallback(
          restaurant: mealMatch.restaurant,
          meal: mealMatch.meal,
        );
      }
      
      return DeepLinkResult(
        success: true,
        platform: preferredPlatform,
        deepLink: deepLink.url,
        linkType: deepLink.type,
        restaurantName: mealMatch.restaurant.name,
        mealName: mealMatch.meal.name,
        price: mealMatch.meal.price,
      );
      
    } catch (e) {
      debugPrint('❌ Error generating deep link: $e');
      return DeepLinkResult.error('Failed to generate deep link: $e');
    }
  }
  
  /// Launch deep link (opens delivery app with meal in cart)
  Future<bool> launchDeepLink(DeepLinkResult deepLinkResult) async {
    try {
      debugPrint('🚀 Launching deep link: ${deepLinkResult.deepLink}');
      
      final uri = Uri.parse(deepLinkResult.deepLink);
      
      // Try to launch native app first
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Open in native app
        );
        
        if (launched) {
          // Log successful order initiation
          await _logOrderInitiation(deepLinkResult);
          return true;
        }
      }
      
      // Fallback to web browser
      if (deepLinkResult.linkType == DeepLinkType.web) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        
        if (launched) {
          await _logOrderInitiation(deepLinkResult);
          return true;
        }
      }
      
      debugPrint('❌ Failed to launch deep link');
      return false;
      
    } catch (e) {
      debugPrint('❌ Error launching deep link: $e');
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // PLATFORM-SPECIFIC DEEP LINKS
  // ═══════════════════════════════════════════════════════════════════
  
  Future<PlatformDeepLink?> _generatePlatformDeepLink({
    required String platform,
    required VerifiedRestaurant restaurant,
    required VerifiedMeal meal,
  }) async {
    switch (platform.toLowerCase()) {
      case 'glovo':
        return _generateGlovoDeepLink(restaurant, meal);
      
      case 'ubereats':
        return _generateUberEatsDeepLink(restaurant, meal);
      
      case 'doordash':
        return _generateDoorDashDeepLink(restaurant, meal);
      
      default:
        return null;
    }
  }
  
  /// Glovo deep link format
  /// glovo://store/{storeId}/product/{productId}
  Future<PlatformDeepLink?> _generateGlovoDeepLink(
    VerifiedRestaurant restaurant,
    VerifiedMeal meal,
  ) async {
    // In production: Use Glovo API to get storeId and productId
    // For now, generate based on IDs
    
    final storeId = _encodeRestaurantId(restaurant.id, 'glovo');
    final productId = _encodeMealId(meal.id, 'glovo');
    
    // Try native app deep link first
    final appDeepLink = 'glovo://store/$storeId/product/$productId';
    
    // Fallback to web
    final webUrl = 'https://glovoapp.com/en/store/$storeId/product/$productId';
    
    return PlatformDeepLink(
      url: appDeepLink,
      type: DeepLinkType.app,
      fallbackUrl: webUrl,
    );
  }
  
  /// UberEats deep link format
  /// ubereats://restaurant/{restaurantId}/item/{itemId}
  Future<PlatformDeepLink?> _generateUberEatsDeepLink(
    VerifiedRestaurant restaurant,
    VerifiedMeal meal,
  ) async {
    final restaurantId = _encodeRestaurantId(restaurant.id, 'ubereats');
    final itemId = _encodeMealId(meal.id, 'ubereats');
    
    final appDeepLink = 'ubereats://restaurant/$restaurantId/item/$itemId';
    final webUrl = 'https://www.ubereats.com/store/$restaurantId/item/$itemId';
    
    return PlatformDeepLink(
      url: appDeepLink,
      type: DeepLinkType.app,
      fallbackUrl: webUrl,
    );
  }
  
  /// DoorDash deep link format
  /// doordash://store/{storeId}/item/{itemId}
  Future<PlatformDeepLink?> _generateDoorDashDeepLink(
    VerifiedRestaurant restaurant,
    VerifiedMeal meal,
  ) async {
    final storeId = _encodeRestaurantId(restaurant.id, 'doordash');
    final itemId = _encodeMealId(meal.id, 'doordash');
    
    final appDeepLink = 'doordash://store/$storeId/item/$itemId';
    final webUrl = 'https://www.doordash.com/store/$storeId/item/$itemId';
    
    return PlatformDeepLink(
      url: appDeepLink,
      type: DeepLinkType.app,
      fallbackUrl: webUrl,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // WHATSAPP BUSINESS API FALLBACK
  // ═══════════════════════════════════════════════════════════════════
  
  /// Generate GlucoCoach Business deep link for direct restaurant order
  DeepLinkResult _generateGlucoCoachFallback({
    required VerifiedRestaurant restaurant,
    required VerifiedMeal meal,
  }) {
    // In production: Get restaurant's GlucoCoach Business number from database
    final glucoCoachNumber = _getRestaurantGlucoCoachNumber(restaurant.id);
    
    if (glucoCoachNumber == null) {
      return DeepLinkResult.error('Restaurant not available for direct order');
    }
    
    // Generate pre-filled message
    final message = Uri.encodeComponent(
      'Hi! I would like to order:\n\n'
      '${meal.name}\n'
      'Price: ${meal.currency} ${meal.price.toStringAsFixed(2)}\n\n'
      'This order was suggested by BiteLab for optimal metabolic health. '
      'Please confirm availability and delivery time.'
    );
    
    // GlucoCoach deep link format
    final deepLink = 'https://wa.me/$glucoCoachNumber?text=$message';
    
    return DeepLinkResult(
      success: true,
      platform: 'glucoCoach',
      deepLink: deepLink,
      linkType: DeepLinkType.glucoCoach,
      restaurantName: restaurant.name,
      mealName: meal.name,
      price: meal.price,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // ORDER TRACKING
  // ═══════════════════════════════════════════════════════════════════
  
  Future<void> _logOrderInitiation(DeepLinkResult result) async {
    try {
      await _db.collection('restaurant_order_initiations').add({
        'platform': result.platform,
        'restaurantName': result.restaurantName,
        'mealName': result.mealName,
        'price': result.price,
        'linkType': result.linkType.name,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to log order initiation: $e');
    }
  }
  
  /// Track whether user completed the order
  Future<void> trackOrderCompletion({
    required String orderId,
    required String platform,
    required double finalPrice,
    required bool completed,
  }) async {
    try {
      await _db.collection('restaurant_order_completions').add({
        'orderId': orderId,
        'platform': platform,
        'finalPrice': finalPrice,
        'completed': completed,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to track order completion: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════
  
  String _encodeRestaurantId(String restaurantId, String platform) {
    // In production: Map BiteLab restaurant ID to platform-specific ID
    // via API lookup or database mapping
    return '${platform}_$restaurantId';
  }
  
  String _encodeMealId(String mealId, String platform) {
    // In production: Map BiteLab meal ID to platform-specific item ID
    return '${platform}_$mealId';
  }
  
  String? _getRestaurantGlucoCoachNumber(String restaurantId) {
    // In production: Query database for restaurant's GlucoCoach Business number
    // For now, return mock number
    return '1234567890'; // Format: international without +
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// DATA MODELS
/// ═══════════════════════════════════════════════════════════════════

enum DeepLinkType {
  app,
  web,
  glucoCoach,
}

class PlatformDeepLink {
  final String url;
  final DeepLinkType type;
  final String? fallbackUrl;
  
  const PlatformDeepLink({
    required this.url,
    required this.type,
    this.fallbackUrl,
  });
}

class DeepLinkResult {
  final bool success;
  final String platform;
  final String deepLink;
  final DeepLinkType linkType;
  final String restaurantName;
  final String mealName;
  final double price;
  final String? errorMessage;
  
  const DeepLinkResult({
    required this.success,
    required this.platform,
    required this.deepLink,
    required this.linkType,
    required this.restaurantName,
    required this.mealName,
    required this.price,
    this.errorMessage,
  });
  
  factory DeepLinkResult.error(String message) => DeepLinkResult(
    success: false,
    platform: '',
    deepLink: '',
    linkType: DeepLinkType.web,
    restaurantName: '',
    mealName: '',
    price: 0.0,
    errorMessage: message,
  );
  
  String get platformDisplayName {
    switch (platform) {
      case 'glovo': return 'Glovo';
      case 'ubereats': return 'Uber Eats';
      case 'doordash': return 'DoorDash';
      case 'glucoCoach': return 'GlucoCoach';
      default: return platform;
    }
  }
}
