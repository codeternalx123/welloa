import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FoodNutrition {
  final String name;
  final String? barcode;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? sodium;
  final String? servingSize;
  final String? imageUrl;
  final List<String>? allergens;
  final List<String>? ingredients;
  final String? brand;
  final int? glycemicIndex;

  FoodNutrition({
    required this.name,
    this.barcode,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.sodium,
    this.servingSize,
    this.imageUrl,
    this.allergens,
    this.ingredients,
    this.brand,
    this.glycemicIndex,
  });

  factory FoodNutrition.fromOpenFoodFacts(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] as Map<String, dynamic>?;
    
    return FoodNutrition(
      name: product['product_name'] ?? 'Unknown Product',
      barcode: product['code'],
      calories: _parseDouble(nutriments?['energy-kcal_100g']),
      protein: _parseDouble(nutriments?['proteins_100g']),
      carbs: _parseDouble(nutriments?['carbohydrates_100g']),
      fat: _parseDouble(nutriments?['fat_100g']),
      fiber: _parseDouble(nutriments?['fiber_100g']),
      sugar: _parseDouble(nutriments?['sugars_100g']),
      sodium: _parseDouble(nutriments?['sodium_100g']),
      servingSize: product['serving_size'],
      imageUrl: product['image_url'],
      allergens: _parseList(product['allergens_tags']),
      ingredients: _parseIngredients(product['ingredients_text']),
      brand: product['brands'],
      glycemicIndex: _estimateGI(nutriments),
    );
  }

  factory FoodNutrition.fromFoodLabel(String foodLabel) {
    // Use USDA FoodData Central database estimates
    final nutrition = _getUSDANutritionEstimate(foodLabel);
    
    return FoodNutrition(
      name: foodLabel,
      calories: nutrition['calories'],
      protein: nutrition['protein'],
      carbs: nutrition['carbs'],
      fat: nutrition['fat'],
      fiber: nutrition['fiber'],
      sugar: nutrition['sugar'],
      sodium: nutrition['sodium'],
      servingSize: nutrition['servingSize'],
      glycemicIndex: nutrition['glycemicIndex'],
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String>? _parseList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  static List<String>? _parseIngredients(dynamic ingredientsText) {
    if (ingredientsText == null) return null;
    if (ingredientsText is String && ingredientsText.isNotEmpty) {
      return ingredientsText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return null;
  }

  static int? _estimateGI(Map<String, dynamic>? nutriments) {
    if (nutriments == null) return null;
    
    final carbs = _parseDouble(nutriments['carbohydrates_100g']);
    final fiber = _parseDouble(nutriments['fiber_100g']);
    final sugar = _parseDouble(nutriments['sugars_100g']);
    
    if (carbs == null || carbs < 1) return null;
    
    // Simple GI estimation based on fiber and sugar content
    double estimatedGI = 70; // Default medium GI
    
    if (fiber != null && fiber > 5) {
      estimatedGI -= 15; // High fiber reduces GI
    }
    
    if (sugar != null && sugar > carbs * 0.7) {
      estimatedGI += 15; // High sugar increases GI
    }
    
    return estimatedGI.clamp(0, 100).toInt();
  }

  /// Get nutrition estimates from USDA database
  static Map<String, dynamic> _getUSDANutritionEstimate(String foodLabel) {
    final foodLower = foodLabel.toLowerCase();
    
    // Common food nutrition database (per 100g serving)
    final nutritionDb = <String, Map<String, dynamic>>{
      // Fruits
      'apple': {'calories': 52.0, 'protein': 0.3, 'carbs': 14.0, 'fat': 0.2, 'fiber': 2.4, 'sugar': 10.0, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 36},
      'banana': {'calories': 89.0, 'protein': 1.1, 'carbs': 23.0, 'fat': 0.3, 'fiber': 2.6, 'sugar': 12.0, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 51},
      'orange': {'calories': 47.0, 'protein': 0.9, 'carbs': 12.0, 'fat': 0.1, 'fiber': 2.4, 'sugar': 9.0, 'sodium': 0.0, 'servingSize': '100g', 'glycemicIndex': 43},
      'strawberry': {'calories': 32.0, 'protein': 0.7, 'carbs': 8.0, 'fat': 0.3, 'fiber': 2.0, 'sugar': 4.9, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 40},
      'grape': {'calories': 69.0, 'protein': 0.7, 'carbs': 18.0, 'fat': 0.2, 'fiber': 0.9, 'sugar': 15.0, 'sodium': 2.0, 'servingSize': '100g', 'glycemicIndex': 59},
      'watermelon': {'calories': 30.0, 'protein': 0.6, 'carbs': 8.0, 'fat': 0.2, 'fiber': 0.4, 'sugar': 6.0, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 76},
      'mango': {'calories': 60.0, 'protein': 0.8, 'carbs': 15.0, 'fat': 0.4, 'fiber': 1.6, 'sugar': 14.0, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 51},
      'pineapple': {'calories': 50.0, 'protein': 0.5, 'carbs': 13.0, 'fat': 0.1, 'fiber': 1.4, 'sugar': 10.0, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 59},
      
      // Vegetables
      'tomato': {'calories': 18.0, 'protein': 0.9, 'carbs': 3.9, 'fat': 0.2, 'fiber': 1.2, 'sugar': 2.6, 'sodium': 5.0, 'servingSize': '100g', 'glycemicIndex': 38},
      'potato': {'calories': 77.0, 'protein': 2.0, 'carbs': 17.0, 'fat': 0.1, 'fiber': 2.1, 'sugar': 0.8, 'sodium': 6.0, 'servingSize': '100g', 'glycemicIndex': 78},
      'carrot': {'calories': 41.0, 'protein': 0.9, 'carbs': 10.0, 'fat': 0.2, 'fiber': 2.8, 'sugar': 4.7, 'sodium': 69.0, 'servingSize': '100g', 'glycemicIndex': 39},
      'broccoli': {'calories': 34.0, 'protein': 2.8, 'carbs': 7.0, 'fat': 0.4, 'fiber': 2.6, 'sugar': 1.7, 'sodium': 33.0, 'servingSize': '100g', 'glycemicIndex': 10},
      'lettuce': {'calories': 15.0, 'protein': 1.4, 'carbs': 2.9, 'fat': 0.2, 'fiber': 1.3, 'sugar': 0.8, 'sodium': 28.0, 'servingSize': '100g', 'glycemicIndex': 15},
      'spinach': {'calories': 23.0, 'protein': 2.9, 'carbs': 3.6, 'fat': 0.4, 'fiber': 2.2, 'sugar': 0.4, 'sodium': 79.0, 'servingSize': '100g', 'glycemicIndex': 15},
      'cucumber': {'calories': 16.0, 'protein': 0.7, 'carbs': 3.6, 'fat': 0.1, 'fiber': 0.5, 'sugar': 1.7, 'sodium': 2.0, 'servingSize': '100g', 'glycemicIndex': 15},
      
      // Proteins
      'chicken': {'calories': 165.0, 'protein': 31.0, 'carbs': 0.0, 'fat': 3.6, 'fiber': 0.0, 'sugar': 0.0, 'sodium': 74.0, 'servingSize': '100g', 'glycemicIndex': 0},
      'beef': {'calories': 250.0, 'protein': 26.0, 'carbs': 0.0, 'fat': 17.0, 'fiber': 0.0, 'sugar': 0.0, 'sodium': 72.0, 'servingSize': '100g', 'glycemicIndex': 0},
      'fish': {'calories': 206.0, 'protein': 22.0, 'carbs': 0.0, 'fat': 13.0, 'fiber': 0.0, 'sugar': 0.0, 'sodium': 47.0, 'servingSize': '100g', 'glycemicIndex': 0},
      'salmon': {'calories': 208.0, 'protein': 20.0, 'carbs': 0.0, 'fat': 13.0, 'fiber': 0.0, 'sugar': 0.0, 'sodium': 59.0, 'servingSize': '100g', 'glycemicIndex': 0},
      'egg': {'calories': 155.0, 'protein': 13.0, 'carbs': 1.1, 'fat': 11.0, 'fiber': 0.0, 'sugar': 1.1, 'sodium': 124.0, 'servingSize': '100g', 'glycemicIndex': 0},
      'tofu': {'calories': 76.0, 'protein': 8.0, 'carbs': 1.9, 'fat': 4.8, 'fiber': 0.3, 'sugar': 0.7, 'sodium': 7.0, 'servingSize': '100g', 'glycemicIndex': 15},
      
      // Grains
      'bread': {'calories': 265.0, 'protein': 9.0, 'carbs': 49.0, 'fat': 3.2, 'fiber': 2.7, 'sugar': 5.0, 'sodium': 491.0, 'servingSize': '100g', 'glycemicIndex': 75},
      'rice': {'calories': 130.0, 'protein': 2.7, 'carbs': 28.0, 'fat': 0.3, 'fiber': 0.4, 'sugar': 0.1, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 73},
      'pasta': {'calories': 131.0, 'protein': 5.0, 'carbs': 25.0, 'fat': 1.1, 'fiber': 1.8, 'sugar': 0.6, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 49},
      'oat': {'calories': 389.0, 'protein': 17.0, 'carbs': 66.0, 'fat': 6.9, 'fiber': 11.0, 'sugar': 0.0, 'sodium': 2.0, 'servingSize': '100g', 'glycemicIndex': 55},
      
      // Dairy
      'milk': {'calories': 42.0, 'protein': 3.4, 'carbs': 5.0, 'fat': 1.0, 'fiber': 0.0, 'sugar': 5.0, 'sodium': 44.0, 'servingSize': '100ml', 'glycemicIndex': 39},
      'cheese': {'calories': 402.0, 'protein': 25.0, 'carbs': 1.3, 'fat': 33.0, 'fiber': 0.0, 'sugar': 0.5, 'sodium': 621.0, 'servingSize': '100g', 'glycemicIndex': 0},
      'yogurt': {'calories': 59.0, 'protein': 10.0, 'carbs': 3.6, 'fat': 0.4, 'fiber': 0.0, 'sugar': 3.2, 'sodium': 36.0, 'servingSize': '100g', 'glycemicIndex': 36},
      
      // Nuts
      'almond': {'calories': 579.0, 'protein': 21.0, 'carbs': 22.0, 'fat': 50.0, 'fiber': 12.0, 'sugar': 4.4, 'sodium': 1.0, 'servingSize': '100g', 'glycemicIndex': 0},
      'walnut': {'calories': 654.0, 'protein': 15.0, 'carbs': 14.0, 'fat': 65.0, 'fiber': 6.7, 'sugar': 2.6, 'sodium': 2.0, 'servingSize': '100g', 'glycemicIndex': 15},
      
      // Sweets
      'chocolate': {'calories': 546.0, 'protein': 4.9, 'carbs': 61.0, 'fat': 31.0, 'fiber': 7.0, 'sugar': 48.0, 'sodium': 24.0, 'servingSize': '100g', 'glycemicIndex': 44},
      'cookie': {'calories': 502.0, 'protein': 5.6, 'carbs': 64.0, 'fat': 24.0, 'fiber': 2.0, 'sugar': 36.0, 'sodium': 390.0, 'servingSize': '100g', 'glycemicIndex': 64},
      'cake': {'calories': 257.0, 'protein': 3.8, 'carbs': 42.0, 'fat': 8.5, 'fiber': 0.6, 'sugar': 29.0, 'sodium': 301.0, 'servingSize': '100g', 'glycemicIndex': 66},
    };

    // Try exact match first
    for (var entry in nutritionDb.entries) {
      if (foodLower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default unknown food
    return {
      'calories': null,
      'protein': null,
      'carbs': null,
      'fat': null,
      'fiber': null,
      'sugar': null,
      'sodium': null,
      'servingSize': '100g',
      'glycemicIndex': null,
    };
  }

  bool get isHealthy {
    if (calories == null) return true;
    
    // Simple health score based on nutrients
    int healthScore = 0;
    
    if (protein != null && protein! > 5) healthScore += 1;
    if (fiber != null && fiber! > 3) healthScore += 1;
    if (sugar != null && sugar! < 10) healthScore += 1;
    if (sodium != null && sodium! < 200) healthScore += 1;
    if (fat != null && fat! < 10) healthScore += 1;
    
    return healthScore >= 3;
  }

  String get glycemicImpact {
    if (glycemicIndex == null) return 'Unknown';
    if (glycemicIndex! < 55) return 'Low';
    if (glycemicIndex! < 70) return 'Medium';
    return 'High';
  }
}

class NutritionService {
  /// Get nutrition from barcode using Open Food Facts API
  static Future<FoodNutrition?> getNutritionFromBarcode(String barcode) async {
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          return FoodNutrition.fromOpenFoodFacts(data['product']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching nutrition from barcode: $e');
    }
    return null;
  }

  /// Get nutrition estimate from food label
  static FoodNutrition getNutritionFromLabel(String foodLabel) {
    return FoodNutrition.fromFoodLabel(foodLabel);
  }

  /// Get multiple nutrition data for detected foods
  static Future<List<FoodNutrition>> getBulkNutrition(List<String> foodLabels) async {
    final nutritionList = <FoodNutrition>[];
    
    for (var label in foodLabels) {
      final nutrition = getNutritionFromLabel(label);
      nutritionList.add(nutrition);
    }
    
    return nutritionList;
  }
}
