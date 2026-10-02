import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_profile_provider.dart';
import '../providers/family_profile_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription_tier.dart';
import '../models/family_plan_models.dart';
import '../services/meal_planning_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/family_plan_setup_wizard.dart';
import '../utils/currency_utils.dart';
import '../utils/planner_hive_cache.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _days = 3;
  String _cuisine = 'Kenyan';
  String _diet = 'Balanced';
  List<String> _selectedFlavors = ['Umami']; // Multi-select flavor profiles
  String _cookingTime = 'Any Duration'; // Cooking time preference
  String _budgetLevel = 'No Budget'; // Budget constraint
  double? _budgetAmount; // Optional budget amount
  String _budgetCurrency = 'USD'; // Budget currency
  MealPlan? _currentMealPlan;
  bool _isGenerating = false;
  bool _showGroceryList = false;
  final List<Map<String, dynamic>> _mealPlans = [];
  bool _isLoadingFromFirestore = false;
  bool _includeFamily = false;
  final Set<String> _favoriteMeals = <String>{}; // Track favorite meals by ID
  final Set<String> _checkedMeals = <String>{}; // Track checked meals for deletion

  static const String _hiveKeyPlan = 'current_plan_json';
  static const String _hiveKeyPrefs = 'current_plan_prefs';
  static const String _hiveKeySavedPlans = 'saved_plans_list';

  @override
  void initState() {
    super.initState();
    _loadMealPlanPersisted();
  }

  /// Load meal plan: Hive first (single box open + one setState), then Firestore sync.
  Future<void> _loadMealPlanPersisted() async {
    setState(() => _isLoadingFromFirestore = true);

    try {
      await _hydrateFromLocalHive();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _loadMealPlanFromFirestore();
      }
    } catch (e) {
      debugPrint('Error loading persisted meal plan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFromFirestore = false);
      }
    }
  }

  /// One Hive read path — avoids repeated [Hive.openBox] and multiple rebuilds.
  Future<void> _hydrateFromLocalHive() async {
    try {
      final box = await PlannerHiveCache.ensureBox();
      final planJson = box.get(_hiveKeyPlan);
      final prefsJson = box.get(_hiveKeyPrefs);
      final savedPlansJson = box.get(_hiveKeySavedPlans);

      if (!mounted) return;

      MealPlan? plan;
      if (planJson != null) {
        plan = MealPlan.fromJson(jsonDecode(planJson) as Map<String, dynamic>);
      }

      setState(() {
        if (plan != null) {
          _currentMealPlan = plan;
        }
        if (prefsJson != null) {
          final prefs = jsonDecode(prefsJson) as Map<String, dynamic>;
          _days = prefs['days'] ?? _days;
          _cuisine = prefs['cuisine'] ?? _cuisine;
          _diet = prefs['diet'] ?? _diet;
          _selectedFlavors = List<String>.from(prefs['flavors'] ?? _selectedFlavors);
          _cookingTime = prefs['cookingTime'] ?? _cookingTime;
          _budgetLevel = prefs['budgetLevel'] ?? _budgetLevel;
          _budgetAmount = (prefs['budgetAmount'] as num?)?.toDouble();
          _budgetCurrency = prefs['budgetCurrency'] ?? _budgetCurrency;
          _includeFamily = prefs['includeFamily'] ?? _includeFamily;
        }
        if (savedPlansJson != null) {
          final decoded = jsonDecode(savedPlansJson) as List<dynamic>;
          _mealPlans
            ..clear()
            ..addAll(decoded.cast<Map<String, dynamic>>());
        }
      });
      debugPrint('Meal planner hydrated from Hive');
    } catch (e) {
      debugPrint('Error hydrating meal plan from Hive: $e');
    }
  }

  /// Save meal plan to local Hive cache
  Future<void> _saveMealPlanToHive(MealPlan mealPlan) async {
    try {
      final box = await PlannerHiveCache.ensureBox();

      // Save meal plan data
      final planJson = jsonEncode(mealPlan.toJson());
      await box.put(_hiveKeyPlan, planJson);

      // Save preferences alongside
      final prefsJson = jsonEncode({
        'days': _days,
        'cuisine': _cuisine,
        'diet': _diet,
        'flavors': _selectedFlavors,
        'cookingTime': _cookingTime,
        'budgetLevel': _budgetLevel,
        'budgetAmount': _budgetAmount,
        'budgetCurrency': _budgetCurrency,
        'includeFamily': _includeFamily,
      });
      await box.put(_hiveKeyPrefs, prefsJson);

      debugPrint('Meal plan saved to local Hive cache');
    } catch (e) {
      debugPrint('Error saving meal plan to Hive: $e');
    }
  }

  /// Persist saved plans list to Hive
  Future<void> _persistSavedPlans() async {
    try {
      final box = await PlannerHiveCache.ensureBox();
      final json = jsonEncode(_mealPlans);
      await box.put(_hiveKeySavedPlans, json);
      debugPrint('Persisted ${_mealPlans.length} saved plans to Hive');
    } catch (e) {
      debugPrint('Error persisting saved plans to Hive: $e');
    }
  }

  /// Load the last saved meal plan from Firestore (cloud sync)
  Future<void> _loadMealPlanFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final data = snapshot.docs.first.data();
        final mealPlan = MealPlan.fromJson(data);

        // Only update if we don't have a local plan, or the Firestore plan is newer
        final shouldUpdate = _currentMealPlan == null ||
            mealPlan.createdAt.isAfter(_currentMealPlan!.createdAt);

        if (shouldUpdate) {
          setState(() {
            _currentMealPlan = mealPlan;
            // Restore preferences
            if (data['preferences'] != null) {
              final prefs = data['preferences'] as Map<String, dynamic>;
              _days = prefs['days'] ?? _days;
              _cuisine = prefs['cuisine'] ?? _cuisine;
              _diet = prefs['diet'] ?? _diet;
              _selectedFlavors = List<String>.from(prefs['flavors'] ?? _selectedFlavors);
              _cookingTime = prefs['cookingTime'] ?? _cookingTime;
              _budgetLevel = prefs['budgetLevel'] ?? _budgetLevel;
              _budgetAmount = (prefs['budgetAmount'] as num?)?.toDouble();
              _budgetCurrency = prefs['budgetCurrency'] ?? _budgetCurrency;
              _includeFamily = prefs['includeFamily'] ?? _includeFamily;
            }
          });

          // Sync Firestore data to local Hive cache
          await _saveMealPlanToHive(mealPlan);
        }
      }
    } catch (e) {
      debugPrint('Error loading meal plan from Firestore: $e');
    }
  }

  /// Save the current meal plan to Firestore
  Future<void> _saveMealPlanToFirestore(MealPlan mealPlan) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .doc(mealPlan.id);

      final data = mealPlan.toJson();
      // Store preferences alongside the meal plan
      data['preferences'] = {
        'days': _days,
        'cuisine': _cuisine,
        'diet': _diet,
        'flavors': _selectedFlavors,
        'cookingTime': _cookingTime,
        'budgetLevel': _budgetLevel,
        'budgetAmount': _budgetAmount,
        'budgetCurrency': _budgetCurrency,
        'includeFamily': _includeFamily,
      };
      // Ensure createdAt is a Firestore Timestamp for reliable ordering
      data['createdAt'] = mealPlan.createdAt.toIso8601String();
      data['createdAtTimestamp'] = FieldValue.serverTimestamp();

      await docRef.set(data);
      debugPrint('Meal plan saved to Firestore: ${mealPlan.id}');
    } catch (e) {
      debugPrint('Error saving meal plan to Firestore: $e');
    }
  }

  // Mapping cuisine to country for localized meal planning
  final Map<String, String> _cuisineToCountry = {
    'Kenyan': 'Kenya',
    'Tanzanian': 'Tanzania',
    'Ugandan': 'Uganda',
    'Nigerian': 'Nigeria',
    'Ethiopian': 'Ethiopia',
    'Moroccan': 'Morocco',
    'South African': 'South Africa',
    'Egyptian': 'Egypt',
    'Chinese': 'China',
    'Japanese': 'Japan',
    'Korean': 'South Korea',
    'Thai': 'Thailand',
    'Vietnamese': 'Vietnam',
    'Indian': 'India',
    'Pakistani': 'Pakistan',
    'Indonesian': 'Indonesia',
    'Malaysian': 'Malaysia',
    'Filipino': 'Philippines',
    'Lebanese': 'Lebanon',
    'Turkish': 'Turkey',
    'Persian': 'Iran',
    'Israeli': 'Israel',
    'Arabic': 'Saudi Arabia',
    'Italian': 'Italy',
    'French': 'France',
    'Spanish': 'Spain',
    'Greek': 'Greece',
    'British': 'United Kingdom',
    'German': 'Germany',
    'Portuguese': 'Portugal',
    'Polish': 'Poland',
    'Russian': 'Russia',
    'American': 'United States',
    'Mexican': 'Mexico',
    'Brazilian': 'Brazil',
    'Argentinian': 'Argentina',
    'Caribbean': 'Jamaica',
    'Peruvian': 'Peru',
    'Mediterranean': 'Greece',
    'Fusion': 'United States',
    'International': 'United States',
  };

  final List<String> _cuisines = [
    // African
    'Kenyan',
    'Tanzanian',
    'Ugandan',
    'Nigerian',
    'Ethiopian',
    'Moroccan',
    'South African',
    'Egyptian',
    // Asian
    'Chinese',
    'Japanese',
    'Korean',
    'Thai',
    'Vietnamese',
    'Indian',
    'Pakistani',
    'Indonesian',
    'Malaysian',
    'Filipino',
    // Middle Eastern
    'Lebanese', 'Turkish', 'Persian', 'Israeli', 'Arabic',
    // European
    'Italian',
    'French',
    'Spanish',
    'Greek',
    'British',
    'German',
    'Portuguese',
    'Polish',
    'Russian',
    // American
    'American', 'Mexican', 'Brazilian', 'Argentinian', 'Caribbean', 'Peruvian',
    // Others
    'Mediterranean', 'Fusion', 'International',
  ];
  final List<String> _diets = [
    'Balanced',
    'Low-Carb',
    'Vegetarian',
    'Vegan',
    'Keto',
    'Paleo',
  ];
  final List<Map<String, dynamic>> _flavors = [
    {
      'name': 'Sweet',
      'icon': Icons.cake,
      'description': 'Sugar, honey, natural sweetness',
      'color': Color(0xFFE91E63),
    },
    {
      'name': 'Salty',
      'icon': Icons.grain,
      'description': 'Savory salt, seasoned depth',
      'color': Color(0xFF9E9E9E),
    },
    {
      'name': 'Sour',
      'icon': Icons.emoji_food_beverage,
      'description': 'Tangy, acidic, citrus notes',
      'color': Color(0xFFFFEB3B),
    },
    {
      'name': 'Bitter',
      'icon': Icons.local_cafe,
      'description': 'Coffee, dark greens, sharp edge',
      'color': Color(0xFF795548),
    },
    {
      'name': 'Umami',
      'icon': Icons.restaurant,
      'description': 'Deep savory, mushroom-soy blend',
      'color': Color(0xFF6D4C41),
    },
    {
      'name': 'Spicy',
      'icon': Icons.whatshot,
      'description': 'Hot peppers, heat, bold kick',
      'color': Color(0xFFFF5722),
    },
    {
      'name': 'Texture',
      'icon': Icons.dining,
      'description': 'Crunchy, creamy, varied mouthfeel',
      'color': Color(0xFF00BCD4),
    },
  ];
  final List<Map<String, dynamic>> _cookingTimes = [
    {
      'name': 'Any Duration',
      'icon': Icons.all_inclusive,
      'description': 'No time restrictions',
      'range': 'All',
      'color': Color(0xFF9C27B0),
    },
    {
      'name': 'Quick & Easy',
      'icon': Icons.speed,
      'description': 'Ready in 15-20 minutes',
      'range': '15-20 min',
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'Fast Cook',
      'icon': Icons.timer,
      'description': '20-30 minutes prep to plate',
      'range': '20-30 min',
      'color': Color(0xFF8BC34A),
    },
    {
      'name': 'Moderate',
      'icon': Icons.schedule,
      'description': '30-45 minutes cooking',
      'range': '30-45 min',
      'color': Color(0xFFFF9800),
    },
    {
      'name': 'Extended',
      'icon': Icons.access_time,
      'description': '45-60 minutes prep time',
      'range': '45-60 min',
      'color': Color(0xFFFF5722),
    },
    {
      'name': 'Slow Cook',
      'icon': Icons.hourglass_bottom,
      'description': 'Over 1 hour, worth the wait',
      'range': '60+ min',
      'color': Color(0xFF795548),
    },
  ];
  final List<Map<String, dynamic>> _budgetLevels = [
    {
      'name': 'No Budget',
      'icon': Icons.all_inclusive,
      'description': 'No budget constraints',
      'color': Color(0xFF9E9E9E),
    },
    {
      'name': 'Low Budget',
      'icon': Icons.money_off,
      'description': 'Budget-friendly meals',
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'Medium Budget',
      'icon': Icons.attach_money,
      'description': 'Balanced cost meals',
      'color': Color(0xFFFF9800),
    },
    {
      'name': 'High Budget',
      'icon': Icons.diamond,
      'description': 'Premium ingredients',
      'color': Color(0xFF9C27B0),
    },
    {
      'name': 'Custom Budget',
      'icon': Icons.edit,
      'description': 'Set your own budget',
      'color': Color(0xFF2196F3),
    },
  ];

  /// Map country to its primary currency
  final Map<String, String> _countryToCurrency = {
    // Africa
    'Kenya': 'KES',
    'Tanzania': 'TZS',
    'Uganda': 'UGX',
    'Nigeria': 'NGN',
    'Ethiopia': 'ETB',
    'Morocco': 'MAD',
    'South Africa': 'ZAR',
    'Egypt': 'EGP',
    'Ghana': 'GHS',
    'Rwanda': 'RWF',
    'Senegal': 'XOF',
    'Cameroon': 'XAF',
    'Ivory Coast': 'XOF',
    'Zimbabwe': 'ZWL',
    'Botswana': 'BWP',
    'Namibia': 'NAD',
    'Zambia': 'ZMW',
    'Malawi': 'MWK',
    'Mozambique': 'MZN',
    'Angola': 'AOA',
    'DRC': 'CDF',
    'Algeria': 'DZD',
    'Tunisia': 'TND',
    'Libya': 'LYD',
    'Sudan': 'SDG',
    
    // Asia
    'China': 'CNY',
    'Japan': 'JPY',
    'South Korea': 'KRW',
    'Thailand': 'THB',
    'Vietnam': 'VND',
    'India': 'INR',
    'Pakistan': 'PKR',
    'Indonesia': 'IDR',
    'Malaysia': 'MYR',
    'Philippines': 'PHP',
    'Singapore': 'SGD',
    'Bangladesh': 'BDT',
    'Sri Lanka': 'LKR',
    'Nepal': 'NPR',
    'Myanmar': 'MMK',
    'Cambodia': 'KHR',
    'Laos': 'LAK',
    'Taiwan': 'TWD',
    'Hong Kong': 'HKD',
    'Macau': 'MOP',
    'Mongolia': 'MNT',
    'Kazakhstan': 'KZT',
    'Uzbekistan': 'UZS',
    'Afghanistan': 'AFN',
    
    // Middle East
    'Lebanon': 'LBP',
    'Turkey': 'TRY',
    'Iran': 'IRR',
    'Israel': 'ILS',
    'Saudi Arabia': 'SAR',
    'UAE': 'AED',
    'United Arab Emirates': 'AED',
    'Qatar': 'QAR',
    'Kuwait': 'KWD',
    'Bahrain': 'BHD',
    'Oman': 'OMR',
    'Jordan': 'JOD',
    'Iraq': 'IQD',
    'Syria': 'SYP',
    'Palestine': 'ILS',
    'Yemen': 'YER',
    
    // Europe
    'Italy': 'EUR',
    'France': 'EUR',
    'Spain': 'EUR',
    'Greece': 'EUR',
    'United Kingdom': 'GBP',
    'Germany': 'EUR',
    'Portugal': 'EUR',
    'Poland': 'PLN',
    'Russia': 'RUB',
    'Netherlands': 'EUR',
    'Belgium': 'EUR',
    'Austria': 'EUR',
    'Switzerland': 'CHF',
    'Sweden': 'SEK',
    'Norway': 'NOK',
    'Denmark': 'DKK',
    'Finland': 'EUR',
    'Ireland': 'EUR',
    'Czech Republic': 'CZK',
    'Hungary': 'HUF',
    'Romania': 'RON',
    'Bulgaria': 'BGN',
    'Croatia': 'EUR',
    'Serbia': 'RSD',
    'Ukraine': 'UAH',
    'Belarus': 'BYN',
    'Slovakia': 'EUR',
    'Slovenia': 'EUR',
    'Lithuania': 'EUR',
    'Latvia': 'EUR',
    'Estonia': 'EUR',
    'Iceland': 'ISK',
    'Cyprus': 'EUR',
    'Malta': 'EUR',
    'Luxembourg': 'EUR',
    
    // Americas
    'United States': 'USD',
    'Canada': 'CAD',
    'Mexico': 'MXN',
    'Brazil': 'BRL',
    'Argentina': 'ARS',
    'Colombia': 'COP',
    'Peru': 'PEN',
    'Chile': 'CLP',
    'Venezuela': 'VES',
    'Ecuador': 'USD',
    'Bolivia': 'BOB',
    'Paraguay': 'PYG',
    'Uruguay': 'UYU',
    'Jamaica': 'JMD',
    'Cuba': 'CUP',
    'Dominican Republic': 'DOP',
    'Puerto Rico': 'USD',
    'Costa Rica': 'CRC',
    'Panama': 'USD',
    'Guatemala': 'GTQ',
    'Honduras': 'HNL',
    'El Salvador': 'USD',
    'Nicaragua': 'NIO',
    'Haiti': 'HTG',
    'Trinidad and Tobago': 'TTD',
    'Bahamas': 'BSD',
    'Barbados': 'BBD',
    
    // Oceania
    'Australia': 'AUD',
    'New Zealand': 'NZD',
    'Fiji': 'FJD',
    'Papua New Guinea': 'PGK',
  };

  /// Get regional daily food budget based on currency and budget level
  /// Based on World Bank food expenditure data, USDA Thrifty Food Plan, 
  /// FAO food price indices, and regional purchasing power parity (PPP)
  double _getRegionalDailyBudget(String currency, String level) {
    // Regional budget data: [low, medium, high] per day in local currency
    // Based on 2024-2025 food costs, local purchasing power, and cost of living indices
    // Low = Food assistance/poverty level (bottom 20% income)
    // Medium = Working class/lower middle class (40-60% income)
    // High = Comfortable/premium dining (top 20% income)
    final Map<String, List<double>> regionalBudgets = {
      // ============ AFRICA ============
      'KES': [200, 500, 1200],       // Kenya Shilling
      'TZS': [5000, 12000, 30000],   // Tanzania Shilling
      'UGX': [8000, 20000, 50000],   // Uganda Shilling
      'NGN': [2500, 6000, 15000],    // Nigeria Naira
      'ETB': [200, 500, 1200],       // Ethiopia Birr
      'MAD': [50, 120, 300],         // Morocco Dirham
      'ZAR': [80, 200, 500],         // South Africa Rand
      'EGP': [150, 350, 850],        // Egypt Pound
      'GHS': [45, 110, 280],         // Ghana Cedi
      'RWF': [2000, 5000, 12000],    // Rwanda Franc
      'XOF': [1500, 3500, 9000],     // West African CFA (Senegal, Ivory Coast, etc.)
      'XAF': [1500, 3500, 9000],     // Central African CFA (Cameroon, etc.)
      'ZWL': [5000, 12000, 30000],   // Zimbabwe Dollar
      'BWP': [50, 120, 300],         // Botswana Pula
      'NAD': [80, 200, 500],         // Namibia Dollar
      'ZMW': [80, 200, 500],         // Zambia Kwacha
      'MWK': [3000, 7500, 18000],    // Malawi Kwacha
      'MZN': [250, 600, 1500],       // Mozambique Metical
      'AOA': [3000, 7500, 18000],    // Angola Kwanza
      'CDF': [8000, 20000, 50000],   // DRC Franc
      'DZD': [500, 1200, 3000],      // Algeria Dinar
      'TND': [10, 25, 60],           // Tunisia Dinar
      'LYD': [15, 35, 90],           // Libya Dinar
      'SDG': [1500, 3500, 9000],     // Sudan Pound
      
      // ============ ASIA ============
      'CNY': [25, 65, 160],          // China Yuan
      'JPY': [700, 1600, 4000],      // Japan Yen
      'KRW': [7000, 16000, 40000],   // South Korea Won
      'THB': [100, 250, 650],        // Thailand Baht
      'VND': [70000, 180000, 450000], // Vietnam Dong
      'INR': [150, 400, 1000],       // India Rupee
      'PKR': [500, 1300, 3200],      // Pakistan Rupee
      'IDR': [35000, 90000, 225000], // Indonesia Rupiah
      'MYR': [12, 32, 80],           // Malaysia Ringgit
      'PHP': [180, 450, 1100],       // Philippines Peso
      'SGD': [8, 20, 50],            // Singapore Dollar
      'BDT': [180, 450, 1100],       // Bangladesh Taka
      'LKR': [800, 2000, 5000],      // Sri Lanka Rupee
      'NPR': [300, 750, 1900],       // Nepal Rupee
      'MMK': [4000, 10000, 25000],   // Myanmar Kyat
      'KHR': [12000, 30000, 75000],  // Cambodia Riel
      'LAK': [50000, 125000, 300000], // Laos Kip
      'TWD': [150, 380, 950],        // Taiwan Dollar
      'HKD': [50, 130, 320],         // Hong Kong Dollar
      'MOP': [50, 130, 320],         // Macau Pataca
      'MNT': [10000, 25000, 65000],  // Mongolia Tugrik
      'KZT': [1500, 3800, 9500],     // Kazakhstan Tenge
      'UZS': [40000, 100000, 250000], // Uzbekistan Som
      'AFN': [250, 650, 1600],       // Afghanistan Afghani
      
      // ============ MIDDLE EAST ============
      'LBP': [1500000, 4000000, 10000000], // Lebanon Pound (hyperinflation adjusted)
      'TRY': [150, 400, 1000],       // Turkey Lira
      'IRR': [1500000, 4000000, 10000000], // Iran Rial
      'ILS': [35, 90, 220],          // Israel Shekel
      'SAR': [20, 50, 130],          // Saudi Riyal
      'AED': [20, 55, 140],          // UAE Dirham
      'QAR': [20, 55, 140],          // Qatar Riyal
      'KWD': [2, 5, 13],             // Kuwait Dinar
      'BHD': [2, 5, 13],             // Bahrain Dinar
      'OMR': [2, 5, 13],             // Oman Rial
      'JOD': [4, 10, 25],            // Jordan Dinar
      'IQD': [5000, 12500, 32000],   // Iraq Dinar
      'SYP': [50000, 125000, 300000], // Syria Pound
      'YER': [2000, 5000, 12500],    // Yemen Rial
      
      // ============ EUROPE ============
      'EUR': [7, 18, 45],            // Euro (Italy, France, Spain, Germany, etc.)
      'GBP': [6, 16, 40],            // British Pound
      'PLN': [30, 80, 200],          // Poland Zloty
      'RUB': [450, 1100, 2800],      // Russia Ruble
      'CHF': [12, 32, 80],           // Swiss Franc
      'SEK': [70, 180, 450],         // Sweden Krona
      'NOK': [90, 230, 580],         // Norway Krone
      'DKK': [55, 140, 350],         // Denmark Krone
      'CZK': [120, 300, 750],        // Czech Koruna
      'HUF': [2000, 5000, 12500],    // Hungary Forint
      'RON': [30, 75, 190],          // Romania Leu
      'BGN': [12, 30, 75],           // Bulgaria Lev
      'RSD': [500, 1250, 3200],      // Serbia Dinar
      'UAH': [180, 450, 1100],       // Ukraine Hryvnia
      'BYN': [12, 30, 75],           // Belarus Ruble
      'ISK': [1200, 3000, 7500],     // Iceland Krona
      
      // ============ AMERICAS ============
      'USD': [6, 14, 35],            // US Dollar (USDA Thrifty Food Plan based)
      'CAD': [9, 22, 55],            // Canada Dollar
      'MXN': [100, 260, 650],        // Mexico Peso
      'BRL': [35, 90, 225],          // Brazil Real
      'ARS': [10000, 25000, 62000],  // Argentina Peso (high inflation adjusted)
      'COP': [20000, 50000, 130000], // Colombia Peso
      'PEN': [18, 45, 115],          // Peru Sol
      'CLP': [5500, 14000, 35000],   // Chile Peso
      'VES': [150, 380, 950],        // Venezuela Bolivar
      'BOB': [35, 90, 220],          // Bolivia Boliviano
      'PYG': [30000, 75000, 190000], // Paraguay Guarani
      'UYU': [250, 650, 1600],       // Uruguay Peso
      'JMD': [800, 2000, 5000],      // Jamaica Dollar
      'CUP': [500, 1250, 3200],      // Cuba Peso
      'DOP': [300, 750, 1900],       // Dominican Peso
      'CRC': [3500, 9000, 22000],    // Costa Rica Colon
      'GTQ': [40, 100, 250],         // Guatemala Quetzal
      'HNL': [120, 300, 750],        // Honduras Lempira
      'NIO': [180, 450, 1100],       // Nicaragua Cordoba
      'HTG': [600, 1500, 3800],      // Haiti Gourde
      'TTD': [50, 130, 320],         // Trinidad Dollar
      'BSD': [6, 14, 35],            // Bahamas Dollar
      'BBD': [12, 30, 75],           // Barbados Dollar
      
      // ============ OCEANIA ============
      'AUD': [10, 26, 65],           // Australia Dollar
      'NZD': [12, 30, 75],           // New Zealand Dollar
      'FJD': [15, 38, 95],           // Fiji Dollar
      'PGK': [25, 65, 160],          // Papua New Guinea Kina
    };
    
    // Get budget array for currency, default to USD if not found
    final budgets = regionalBudgets[currency] ?? regionalBudgets['USD']!;
    
    switch (level.toLowerCase()) {
      case 'low':
        return budgets[0];
      case 'medium':
        return budgets[1];
      case 'high':
        return budgets[2];
      default:
        return budgets[1]; // Default to medium
    }
  }
  
  /// Get the appropriate currency for a country
  String _getCurrencyForCountry(String country) {
    return _countryToCurrency[country] ?? 'USD';
  }

  Future<void> _saveMealPlan() async {
    if (_currentMealPlan == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No meal plan to save')));
      return;
    }

    try {
      final userProfile = context.read<UserProfileProvider>().userProfile;
      if (userProfile == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User profile not found')));
        return;
      }

      // Convert meal plan to saveable format
      final mealPlanData = {
        'days': _days,
        'cuisine': _cuisine,
        'diet': _diet,
        'flavors': _selectedFlavors,
        'cookingTime': _cookingTime,
        'budgetLevel': _budgetLevel,
        'budgetAmount': _budgetAmount,
        'budgetCurrency': _budgetCurrency,
        'includeFamily': _includeFamily,
        'plan': _currentMealPlan!.mealDays
            .map(
              (day) => {
                'dayNumber': day.dayNumber,
                'meals': day.meals
                    .map(
                      (meal) {
                        // Debug: Check if steps exist before saving
                        if (meal.steps.isEmpty) {
                          debugPrint('⚠️ SAVE WARNING: Meal "${meal.name}" (${meal.type}) has NO steps before saving!');
                        } else {
                          debugPrint('✅ SAVE OK: Meal "${meal.name}" has ${meal.steps.length} steps');
                        }
                        
                        return {
                          'type': meal.type,
                          'name': meal.name,
                          'localName': meal.localName,
                          'ingredients': meal.ingredients
                              .map((i) => i.name)
                              .toList(),
                          'steps': meal.steps,
                          'calories': meal.calories,
                          'protein': meal.protein,
                          'carbs': meal.carbs,
                          'fat': meal.fat,
                          'fiber': meal.fiber,
                          'youtubeLink': meal.youtubeLink,
                          'prepTime': meal.prepTime,
                          'estimatedCost': meal.estimatedCost,
                          'glycemicIndex': meal.glycemicIndex,
                        };
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Add to local list
      setState(() {
        _mealPlans.add(mealPlanData);
      });

      // Persist to Hive
      await _persistSavedPlans();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Meal plan saved successfully!'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Scroll to saved plans section
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save meal plan: $e')));
    }
  }

  Future<void> _generateMealPlan() async {
    setState(() => _isGenerating = true);

    try {
      final userProfileProvider = context.read<UserProfileProvider>();
      final familyProfileProvider = context.read<FamilyProfileProvider>();

      final userProfile = userProfileProvider.userProfile;
      final familyPlanSetup = familyProfileProvider.familyPlanSetup;

      if (userProfile == null || !userProfile.isComplete) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please complete your health profile first'),
              action: SnackBarAction(
                label: 'Go to Profile',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserProfileScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
        setState(() => _isGenerating = false);
        return;
      }

      // Check subscription limits for free users
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final plannerMealsPerDay =
          SubscriptionQuotas.mealsPerDay(subscriptionProvider.currentTier);
      if (subscriptionProvider.isFree) {
        // Free users: 1 meal plan per lifetime (lunch + dinner only)
        if (!subscriptionProvider.canGenerateMealPlan) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'You have used your free meal plan. Upgrade for more generations and 3 meals per day!',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Upgrade',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                    );
                  },
                ),
              ),
            );
          }
          setState(() => _isGenerating = false);
          return;
        }

        // Free users can only generate basic meal plans (up to 3 days)
        if (_days > 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Free plan limited to 3-day meal plans. Upgrade for longer plans!'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Upgrade',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                    );
                  },
                ),
              ),
            );
          }
          setState(() {
            _days = 3; // Reset to max free limit
            _isGenerating = false;
          });
          return;
        }
      }

      // Check family limits - Family planning requires Family tier
      if (_includeFamily && !subscriptionProvider.canAccessFamilyProfiles) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Family meal planning requires Family plan'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Upgrade',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                  );
                },
              ),
            ),
          );
        }
        setState(() {
          _includeFamily = false;
          _isGenerating = false;
        });
        return;
      }

      // Yield control to UI thread
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        // If family planning is enabled, validate family setup exists
        if (_includeFamily) {
          if (familyPlanSetup == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please complete family setup first'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            setState(() => _isGenerating = false);
            return;
          }

          if (familyPlanSetup.members.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please add at least one family member'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            setState(() => _isGenerating = false);
            return;
          }
        }

        debugPrint('Generating meal plan with parameters:');
        debugPrint('  Days: $_days');
        debugPrint('  Cuisine: $_cuisine');
        debugPrint('  Diet: $_diet');
        debugPrint('  Include Family: $_includeFamily');

        try {
          // Determine budget constraints from either family setup or custom budget
          BudgetConstraints? finalBudgetConstraints;

          if (_includeFamily && familyPlanSetup != null) {
            // Use family budget - calculate for selected days
            final dailyBudget = familyPlanSetup.monthlyBudget / 30; // Monthly to daily
            final totalForDays = dailyBudget * _days;
            final perMealBudget = dailyBudget / familyPlanSetup.mealsPerDay;
            
            // Currency-relative budget levels for family
            String budgetLevel;
            if (familyPlanSetup.budgetCurrency == 'KES') {
              budgetLevel = dailyBudget < 500 ? 'Low' : dailyBudget < 1500 ? 'Medium' : 'High';
            } else if (familyPlanSetup.budgetCurrency == 'NGN') {
              budgetLevel = dailyBudget < 3000 ? 'Low' : dailyBudget < 8000 ? 'Medium' : 'High';
            } else {
              budgetLevel = dailyBudget < 20 ? 'Low' : dailyBudget < 60 ? 'Medium' : 'High';
            }
            
            finalBudgetConstraints = BudgetConstraints(
              totalBudget: totalForDays,
              currency: familyPlanSetup.budgetCurrency,
              budgetLevel: budgetLevel,
              perMealBudget: perMealBudget,
              includeSnacks: false,
              costSavingPreferences: [],
              days: _days,
            );
          } else if (_budgetLevel == 'Custom Budget' && _budgetAmount != null && _budgetAmount! > 0) {
            // Use custom budget selected by user - budget is WEEKLY, calculate for selected days
            // Formula: (weekly budget / 7) * number of days
            final weeklyBudget = _budgetAmount!;
            final dailyBudget = weeklyBudget / 7; // Weekly budget divided by 7 days
            
            // 🚨 VALIDATION: Check if CUSTOM budget is unrealistically low
            final minDailyBudget = _getRegionalDailyBudget(_budgetCurrency, 'low');
            if (dailyBudget < minDailyBudget * 0.5) {
              // Custom budget is less than 50% of the minimum - show warning
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Custom budget too low! Minimum recommended: ${(minDailyBudget * 7).toStringAsFixed(0)} $_budgetCurrency/week. '
                      'Adjusting to minimum budget for better results.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
              // Use minimum budget instead
              final adjustedDailyBudget = minDailyBudget;
              final totalBudgetForPeriod = adjustedDailyBudget * _days;
              final perMealBudget = adjustedDailyBudget / 3;
              
              finalBudgetConstraints = BudgetConstraints(
                totalBudget: totalBudgetForPeriod,
                currency: _budgetCurrency,
                budgetLevel: 'Low',
                perMealBudget: perMealBudget,
                includeSnacks: false,
                costSavingPreferences: [],
                days: _days,
              );
              
              debugPrint('⚠️ CUSTOM budget adjusted: Weekly=$weeklyBudget (too low) -> Using minimum daily=$adjustedDailyBudget, Total for $_days days=$totalBudgetForPeriod');
            } else {
              final totalBudgetForPeriod = dailyBudget * _days; // Daily rate * selected days
              final perMealBudget = dailyBudget / plannerMealsPerDay;
              
              // Calculate budget level relative to currency using regional data
              // Compare user's daily budget with regional low/medium thresholds
              final lowThreshold = _getRegionalDailyBudget(_budgetCurrency, 'low');
              final medThreshold = _getRegionalDailyBudget(_budgetCurrency, 'medium');
              String budgetLevel;
              if (dailyBudget <= lowThreshold * 1.3) {
                budgetLevel = 'Low';
              } else if (dailyBudget <= medThreshold * 1.3) {
                budgetLevel = 'Medium';
              } else {
                budgetLevel = 'High';
              }
              
              finalBudgetConstraints = BudgetConstraints(
                totalBudget: totalBudgetForPeriod,
                currency: _budgetCurrency,
                budgetLevel: budgetLevel,
                perMealBudget: perMealBudget,
                includeSnacks: false,
                costSavingPreferences: [],
                days: _days,
              );
              
              debugPrint('Custom budget calculation: Weekly=$weeklyBudget, Daily=$dailyBudget, Total for $_days days=$totalBudgetForPeriod');
            }
          } else if (_budgetLevel != 'No Budget' && _budgetLevel != 'Custom Budget') {
            // Handle preset budget levels (Low, Medium, High Budget)
            // Calculate default daily budget based on level and currency
            double dailyBudget;
            String budgetLevel;
            
            if (_budgetLevel == 'Low Budget') {
              budgetLevel = 'Low';
              dailyBudget = _getRegionalDailyBudget(_budgetCurrency, 'low');
            } else if (_budgetLevel == 'Medium Budget') {
              budgetLevel = 'Medium';
              dailyBudget = _getRegionalDailyBudget(_budgetCurrency, 'medium');
            } else {
              // High Budget
              budgetLevel = 'High';
              dailyBudget = _getRegionalDailyBudget(_budgetCurrency, 'high');
            }
            
            final totalBudgetForPeriod = dailyBudget * _days;
            final perMealBudget = dailyBudget / plannerMealsPerDay;
            
            finalBudgetConstraints = BudgetConstraints(
              totalBudget: totalBudgetForPeriod,
              currency: _budgetCurrency,
              budgetLevel: budgetLevel,
              perMealBudget: perMealBudget,
              includeSnacks: false,
              costSavingPreferences: [],
              days: _days,
            );
            
            debugPrint('Preset budget level: $_budgetLevel -> $budgetLevel, Daily=$dailyBudget, Total for $_days days=$totalBudgetForPeriod');
          } else if (_budgetLevel == 'No Budget') {
            // Apply a default reasonable limit (High budget) for the selected country
            // so the AI does not hallucinate vague, unreasonable prices.
            final dailyBudget = _getRegionalDailyBudget(_budgetCurrency, 'high');
            final totalBudgetForPeriod = dailyBudget * _days;
            final perMealBudget = dailyBudget / plannerMealsPerDay;
            
            finalBudgetConstraints = BudgetConstraints(
              totalBudget: totalBudgetForPeriod,
              currency: _budgetCurrency,
              budgetLevel: 'Flexible',
              perMealBudget: perMealBudget,
              includeSnacks: false,
              costSavingPreferences: [],
              days: _days,
            );
            
            debugPrint('No Budget selected. Applying regional high cap: Daily=$dailyBudget, Total for $_days days=$totalBudgetForPeriod');
          }

          // Use ONE random flavor for variety (not combined)
          final random = Random();
          final selectedFlavor = _selectedFlavors.isEmpty 
              ? null 
              : _selectedFlavors[random.nextInt(_selectedFlavors.length)];
          
          final mealPlan = await MealPlanningService.generateMealPlan(
            userProfile: userProfile,
            familyPlanSetup: _includeFamily ? familyPlanSetup : null,
            budgetConstraints: finalBudgetConstraints,
            days: _days,
            cuisine: _cuisine,
            diet: _diet,
            flavor: selectedFlavor,
            cookingTime: _cookingTime,
            country: _cuisineToCountry[_cuisine] ?? 'Kenya',
            currency: _budgetCurrency,
            userTier: subscriptionProvider.currentTier,
            mealsPerDay: plannerMealsPerDay,
          );

          debugPrint('Meal plan generated successfully');
          debugPrint('Meal plan type: ${mealPlan.runtimeType}');

          if (mounted) {
            setState(() {
              _currentMealPlan = mealPlan;
              _showGroceryList = false;
            });

            // Persist cloud + local concurrently (lower wall-clock latency).
            await Future.wait([
              _saveMealPlanToFirestore(mealPlan),
              _saveMealPlanToHive(mealPlan),
            ]);

            // Record meal plan generation for monthly quota tracking
            await subscriptionProvider.recordMealPlanGeneration();

            debugPrint('Meal plan state updated: $_currentMealPlan != null');

            final quotaText = subscriptionProvider.remainingMealPlans >= 0
                ? ' (${subscriptionProvider.mealPlanQuotaLabel} remaining)'
                : '';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Meal plan generated successfully!$quotaText'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (serviceError) {
          debugPrint(
            'Service error during meal plan generation: $serviceError',
          );
          debugPrint('Service error type: ${serviceError.runtimeType}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Service Error: ${serviceError.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          rethrow;
        }
      } catch (e, stackTrace) {
        debugPrint('Meal plan generation error: $e');
        debugPrint('Stack trace: $stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate meal plan: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isGenerating = false);
        }
      }
    } catch (e) {
      debugPrint('Unexpected error in _generateMealPlan: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FA), Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
                  slivers: [
                    if (_isLoadingFromFirestore)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: Color(0xFF4CAF50),
                          backgroundColor: Color(0xFFE0E0E0),
                        ),
                      ),
                    // App Bar
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Meal Planner',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 20),

                          // Plan Creator Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.create,
                                        color: Color(0xFF4CAF50),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Create New Plan',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Selection Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSelectionCard(
                                        'Duration',
                                        '${_days} days',
                                        Icons.calendar_today,
                                        const Color(0xFF4CAF50),
                                        () => _showDurationPicker(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSelectionCard(
                                        'Cuisine',
                                        _cuisine,
                                        Icons.restaurant,
                                        const Color(0xFFFF9800),
                                        () => _showCuisinePicker(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSelectionCard(
                                        'Diet',
                                        _diet,
                                        Icons.health_and_safety,
                                        const Color(0xFF2196F3),
                                        () => _showDietPicker(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSelectionCard(
                                        'Cook Time',
                                        _cookingTime,
                                        Icons.timer,
                                        const Color(0xFF9C27B0),
                                        () => _showCookingTimePicker(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSelectionCard(
                                        'Flavor',
                                        _selectedFlavors.length == 1
                                            ? _selectedFlavors.first
                                            : '${_selectedFlavors.length} selected',
                                        Icons.restaurant_menu,
                                        const Color(0xFFE91E63),
                                        () => _showFlavorPicker(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSelectionCard(
                                        'Budget',
                                        _budgetLevel,
                                        Icons.account_balance_wallet,
                                        const Color(0xFF4CAF50),
                                        () => _showBudgetPicker(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 80,
                                        child: ElevatedButton(
                                          onPressed: _isGenerating
                                              ? null
                                              : _generateMealPlan,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF4CAF50,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 4,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                          child: _isGenerating
                                              ? const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(Colors.white),
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Generating...',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.auto_awesome,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Generate AI Plan',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Family Optimization Toggle (only for premium users)
                                Consumer<SubscriptionProvider>(
                                  builder: (context, subscriptionProvider, child) {
                                    if (subscriptionProvider.currentTier ==
                                        SubscriptionTier.free) {
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.lock,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Family Planning (Premium)',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Upgrade to include family health goals and restrictions',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const UserProfileScreen(),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFFF9800,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Upgrade',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF9800,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFF9800,
                                          ).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.family_restroom,
                                            color: Color(0xFFFF9800),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Family-Optimized Plan',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                                Text(
                                                  'Include family health goals and dietary restrictions',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Switch(
                                            value: _includeFamily,
                                            onChanged: (value) async {
                                              if (value) {
                                                // Navigate to family setup wizard
                                                final result = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const FamilyPlanSetupWizard(),
                                                  ),
                                                );
                                                if (result != null) {
                                                  setState(
                                                    () => _includeFamily = true,
                                                  );
                                                }
                                              } else {
                                                setState(
                                                  () => _includeFamily = false,
                                                );
                                              }
                                            },
                                            activeColor: const Color(
                                              0xFFFF9800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Generated Meal Plan Display
                          if (_currentMealPlan != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      const Icon(
                                        Icons.restaurant_menu,
                                        color: Color(0xFF4CAF50),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${_currentMealPlan!.days}-Day AI Generated Plan',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(
                                          _showGroceryList
                                              ? Icons.restaurant_menu
                                              : Icons.shopping_cart,
                                          color: const Color(0xFF4CAF50),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => setState(
                                          () => _showGroceryList =
                                              !_showGroceryList,
                                        ),
                                        tooltip: _showGroceryList
                                            ? 'Show Meals'
                                            : 'Show Grocery List',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Budget Summary Card
                                  if (_currentMealPlan != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF4CAF50,
                                            ).withOpacity(0.1),
                                            const Color(
                                              0xFF81C784,
                                            ).withOpacity(0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF4CAF50,
                                          ).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.account_balance_wallet,
                                                color: Color(0xFF4CAF50),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Budget Summary ($_days days)',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (_currentMealPlan!.budgetSummary !=
                                              null)
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _buildBudgetItem(
                                                    'Total ($_days days)',
                                                    _currentMealPlan!
                                                        .budgetSummary!
                                                        .formattedTotalCost,
                                                    Icons.payments,
                                                  ),
                                                  const SizedBox(width: 16),
                                                  _buildBudgetItem(
                                                    'Daily Avg',
                                                    _currentMealPlan!
                                                        .budgetSummary!
                                                        .formattedDailyost,
                                                    Icons.calendar_today,
                                                  ),
                                                  const SizedBox(width: 16),
                                                  _buildBudgetItem(
                                                    'Per Meal Avg',
                                                    _currentMealPlan!
                                                        .budgetSummary!
                                                        .formattedPerMealCost,
                                                    Icons.restaurant,
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                              child: Text(
                                                'Budget information not available',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Action Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _saveMealPlan,
                                            icon: const Icon(Icons.save),
                                            label: const Text('Save Plan'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF4CAF50,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              setState(
                                                () => _showGroceryList =
                                                    !_showGroceryList,
                                              );
                                            },
                                            icon: Icon(
                                              _showGroceryList
                                                  ? Icons.menu
                                                  : Icons.shopping_cart,
                                            ),
                                            label: Text(
                                              _showGroceryList
                                                  ? 'View Meals'
                                                  : 'Grocery List',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF2196F3,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  if (_showGroceryList)
                                    _buildGroceryList()
                                  else
                                    ..._currentMealPlan!.mealDays.map(
                                      (day) => _buildDayCard(day),
                                    ),
                                ],
                              ),
                            ),
                          ],

                          // Saved Plans Section
                          if (_mealPlans.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Your Meal Plans',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                if (_checkedMeals.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _deleteCheckedMeals,
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    label: Text(
                                      'Delete (${_checkedMeals.length})',
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Plans List
                          ..._mealPlans.asMap().entries.map((entry) {
                            final planIndex = entry.key;
                            final savedPlan = entry.value;
                            final planData = savedPlan['plan'] as List<dynamic>;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ExpansionTile(
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF9800,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.restaurant_menu,
                                        color: Color(0xFFFF9800),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${savedPlan['days']} Days - ${savedPlan['cuisine']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2E7D32),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            savedPlan['diet'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          // Remove any checked meals from this plan
                                          _checkedMeals.removeWhere((key) => key.startsWith('${planIndex}_'));
                                          _mealPlans.removeAt(planIndex);
                                        });
                                        _persistSavedPlans();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Meal plan deleted')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 44,
                                    top: 4,
                                  ),
                                  child: Text(
                                    'Created: ${DateTime.parse(savedPlan['createdAt']).toLocal().toString().split(' ')[0]}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                children: planData.asMap().entries.map<Widget>((dayEntry) {
                                  final day = dayEntry.value;
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ExpansionTile(
                                      title: Text(
                                        'Day ${day['dayNumber'] ?? (dayEntry.key + 1)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      children: (day['meals'] as List).asMap().entries.map<Widget>((
                                        mealEntry,
                                      ) {
                                        final meal = mealEntry.value;
                                        final mealKey = '${planIndex}_${dayEntry.key}_${mealEntry.key}';
                                        final isChecked = _checkedMeals.contains(mealKey);
                                        final youtubeLink = meal['youtubeLink'] as String? ?? '';
                                        final localName = meal['localName'] as String? ?? '';
                                        final prepTime = meal['prepTime'] as String? ?? '';
                                        final estimatedCost = (meal['estimatedCost'] as num?)?.toDouble() ?? 0;
                                        final glycemicIndex = (meal['glycemicIndex'] as num?)?.toInt() ?? 0;
                                        final steps = meal['steps'] as List? ?? [];
                                        
                                        // Debug: Check steps when displaying
                                        if (steps.isEmpty) {
                                          debugPrint('⚠️ DISPLAY WARNING: Meal "${meal['name']}" (${meal['type']}) has NO steps to display!');
                                          debugPrint('   Full meal data keys: ${meal.keys.toList()}');
                                          if (meal.containsKey('steps')) {
                                            debugPrint('   Steps field exists but is: ${meal['steps']}');
                                          } else {
                                            debugPrint('   Steps field is MISSING from meal data!');
                                          }
                                        } else {
                                          debugPrint('✅ DISPLAY OK: Meal "${meal['name']}" has ${steps.length} steps to display');
                                        }
                                        
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isChecked ? Colors.red.shade50 : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: isChecked ? Colors.red.shade200 : Colors.grey.shade200,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 32,
                                                    height: 32,
                                                    child: Checkbox(
                                                      value: isChecked,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          if (value == true) {
                                                            _checkedMeals.add(mealKey);
                                                          } else {
                                                            _checkedMeals.remove(mealKey);
                                                          }
                                                        });
                                                      },
                                                      activeColor: Colors.red,
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Wrap(
                                                          spacing: 6,
                                                          runSpacing: 4,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                meal['type'] ?? '',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: Color(0xFF4CAF50),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                '${meal['calories'] ?? 0} cal',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: Color(0xFF4CAF50),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          meal['name'] ?? '',
                                                          style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                              0xFF2E7D32,
                                                            ),
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        if (localName.isNotEmpty) ...[
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            '🍽️ $localName',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey.shade600,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  if (youtubeLink.isNotEmpty)
                                                    Tooltip(
                                                      message: 'Watch Recipe Video',
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.play_circle_filled,
                                                          color: Color(0xFFFF0000),
                                                          size: 28,
                                                        ),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                        onPressed: () async {
                                                          if (await canLaunchUrl(Uri.parse(youtubeLink))) {
                                                            await launchUrl(
                                                              Uri.parse(youtubeLink),
                                                              mode: LaunchMode.externalApplication,
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                    icon: Icon(
                                                      _favoriteMeals.contains(meal['name'])
                                                          ? Icons.favorite
                                                          : Icons.favorite_border,
                                                      color: const Color(0xFFFF9800),
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        if (_favoriteMeals.contains(meal['name'])) {
                                                          _favoriteMeals.remove(meal['name']);
                                                        } else {
                                                          _favoriteMeals.add(meal['name']);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              // Nutrition & meta row
                                              Padding(
                                                padding: const EdgeInsets.only(left: 36, top: 4),
                                                child: SingleChildScrollView(
                                                  scrollDirection: Axis.horizontal,
                                                  child: Row(
                                                    children: [
                                                      if (estimatedCost > 0) ...[
                                                        Icon(Icons.payments_outlined, size: 13, color: Colors.green.shade600),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          '${savedPlan['budgetCurrency'] ?? 'USD'} ${estimatedCost.toStringAsFixed(0)}',
                                                          style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w500),
                                                        ),
                                                        const SizedBox(width: 12),
                                                      ],
                                                      if (glycemicIndex > 0) ...[
                                                        Icon(Icons.speed, size: 13, color: Colors.orange.shade600),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          'GI: $glycemicIndex',
                                                          style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.w500),
                                                        ),
                                                        const SizedBox(width: 12),
                                                      ],
                                                      if (prepTime.isNotEmpty) ...[
                                                        Icon(Icons.timer_outlined, size: 13, color: Colors.blue.shade600),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          prepTime,
                                                          style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.w500),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Expandable recipe details
                                              Padding(
                                                padding: const EdgeInsets.only(left: 36),
                                                child: ExpansionTile(
                                                  tilePadding: EdgeInsets.zero,
                                                  title: const Text(
                                                    'Recipe & Ingredients',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                  ),
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 12),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          // Ingredients
                                                          const Text(
                                                            'Ingredients:',
                                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          ...(meal['ingredients'] as List).map<Widget>(
                                                            (ingredient) => Padding(
                                                              padding: const EdgeInsets.only(bottom: 4),
                                                              child: Row(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFF4CAF50)),
                                                                  const SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Text(
                                                                      ingredient.toString(),
                                                                      style: const TextStyle(fontSize: 13),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // Steps
                                                          if (steps.isNotEmpty) ...[
                                                            const SizedBox(height: 12),
                                                            const Text(
                                                              'Steps:',
                                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                            ),
                                                            const SizedBox(height: 6),
                                                            ...steps.asMap().entries.map<Widget>(
                                                              (stepEntry) => Padding(
                                                                padding: const EdgeInsets.only(bottom: 6),
                                                                child: Row(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Container(
                                                                      width: 22,
                                                                      height: 22,
                                                                      alignment: Alignment.center,
                                                                      decoration: BoxDecoration(
                                                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                                        borderRadius: BorderRadius.circular(6),
                                                                      ),
                                                                      child: Text(
                                                                        '${stepEntry.key + 1}',
                                                                        style: const TextStyle(
                                                                          fontSize: 11,
                                                                          fontWeight: FontWeight.w700,
                                                                          color: Color(0xFF4CAF50),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 8),
                                                                    Expanded(
                                                                      child: Text(
                                                                        stepEntry.value.toString(),
                                                                        style: const TextStyle(fontSize: 13, height: 1.4),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                          // Macros
                                                          const SizedBox(height: 12),
                                                          Wrap(
                                                            spacing: 10,
                                                            runSpacing: 6,
                                                            children: [
                                                              _buildMacroChip('Protein', '${meal['protein'] ?? 0}g'),
                                                              _buildMacroChip('Carbs', '${meal['carbs'] ?? 0}g'),
                                                              _buildMacroChip('Fat', '${meal['fat'] ?? 0}g'),
                                                              _buildMacroChip('Fiber', '${meal['fiber'] ?? 0}g'),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }),

                          // Empty State
                          if (_mealPlans.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.restaurant_menu,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No meal plans yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create your first meal plan above!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGroceryList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Grocery List',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _currentMealPlan!.groceryList.length,
              itemBuilder: (context, index) {
                final item = _currentMealPlan!.groceryList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_box_outline_blank, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 14),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _deleteCheckedMeals() {
    // Group checked meals by plan index
    final plansToRemoveMealsFrom = <int, Set<String>>{};
    for (final key in _checkedMeals) {
      final parts = key.split('_');
      final planIdx = int.parse(parts[0]);
      plansToRemoveMealsFrom.putIfAbsent(planIdx, () => <String>{}).add(key);
    }

    setState(() {
      // Process from highest index to lowest so removal doesn't shift indices
      final sortedPlanIndices = plansToRemoveMealsFrom.keys.toList()..sort((a, b) => b.compareTo(a));

      for (final planIdx in sortedPlanIndices) {
        if (planIdx >= _mealPlans.length) continue;
        final plan = _mealPlans[planIdx];
        final planData = plan['plan'] as List<dynamic>;

        for (var dayIdx = planData.length - 1; dayIdx >= 0; dayIdx--) {
          final dayMeals = planData[dayIdx]['meals'] as List<dynamic>;
          for (var mealIdx = dayMeals.length - 1; mealIdx >= 0; mealIdx--) {
            final mealKey = '${planIdx}_${dayIdx}_$mealIdx';
            if (_checkedMeals.contains(mealKey)) {
              dayMeals.removeAt(mealIdx);
            }
          }
          // Remove empty days
          if (dayMeals.isEmpty) {
            planData.removeAt(dayIdx);
          }
        }
        // Remove empty plans
        if (planData.isEmpty) {
          _mealPlans.removeAt(planIdx);
        }
      }
      _checkedMeals.clear();
    });

    _persistSavedPlans();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected meals deleted')),
    );
  }

  Widget _buildMacroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _buildDayCard(MealDay day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          'Day ${day.dayNumber}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        children: day.meals.map((meal) => _buildMealCard(meal)).toList(),
      ),
    );
  }

  Widget _buildMealCard(Meal meal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meal.type,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _favoriteMeals.contains('${meal.name}_${meal.type}')
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: const Color(0xFFFF9800),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    final mealId = '${meal.name}_${meal.type}';
                    if (_favoriteMeals.contains(mealId)) {
                      _favoriteMeals.remove(mealId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed from favorites')),
                      );
                    } else {
                      _favoriteMeals.add(mealId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to favorites')),
                      );
                    }
                  });
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${meal.calories} cal',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meal.localName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🍽️ ${meal.localName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4CAF50),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (meal.youtubeLink.isNotEmpty)
                Tooltip(
                  message: 'View Recipe Video',
                  child: IconButton(
                    icon: const Icon(
                      Icons.play_circle_filled,
                      color: Color(0xFFFF0000),
                    ),
                    iconSize: 28,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () async {
                      final url = meal.youtubeLink;
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open recipe video'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(Icons.payments_outlined, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  '${_currentMealPlan?.budgetSummary?.currency ?? _budgetCurrency} ${meal.estimatedCost.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Icon(Icons.speed, size: 14, color: Colors.orange.shade600),
                const SizedBox(width: 4),
                Text(
                  'GI: ${meal.glycemicIndex}',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Icon(Icons.timer_outlined, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text(
                  meal.prepTime.isNotEmpty ? meal.prepTime : '30 min',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text(
              'Recipe & Ingredients',
              style: TextStyle(fontSize: 14),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingredients:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...meal.ingredients.map(
                      (ingredient) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.fiber_manual_record,
                              size: 8,
                              color: Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${ingredient.name} - ${ingredient.quantity} ${ingredient.unit}',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50).withOpacity(0.1),
                            const Color(0xFF81C784).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Cooking Instructions',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (meal.steps.isNotEmpty)
                            ...meal.steps.asMap().entries.map(
                              (entry) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4CAF50),
                                            Color(0xFF81C784),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${entry.key + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: Color(0xFF1B5E20),
                                        ),
                                        maxLines: null,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Color(0xFF757575),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'No cooking steps available',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Consider ordering this meal
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: const Color(0xFF10B981),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Consider ordering',
                            style: TextStyle(
                              color: const Color(0xFF059669),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDurationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 3, 5].map((days) {
            return ListTile(
              title: Text('$days ${days == 1 ? 'Day' : 'Days'}'),
              leading: Icon(
                Icons.calendar_today,
                color: _days == days ? const Color(0xFF4CAF50) : Colors.grey,
              ),
              onTap: () {
                setState(() => _days = days);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCuisinePicker(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredCuisines = _cuisines
        .take(10)
        .toList(); // Show first 10 initially

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header
                    const Text(
                      'Select Cuisine',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search cuisines...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFFF9800),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF9800),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF9800),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          if (value.isEmpty) {
                            filteredCuisines = _cuisines.take(10).toList();
                          } else {
                            filteredCuisines = _cuisines
                                .where(
                                  (cuisine) => cuisine.toLowerCase().contains(
                                    value.toLowerCase(),
                                  ),
                                )
                                .toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Cuisine List
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredCuisines.length,
                        itemBuilder: (context, index) {
                          final cuisine = filteredCuisines[index];
                          return ListTile(
                            title: Text(cuisine),
                            leading: Icon(
                              Icons.restaurant,
                              color: _cuisine == cuisine
                                  ? const Color(0xFFFF9800)
                                  : Colors.grey,
                            ),
                            trailing: _cuisine == cuisine
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFFF9800),
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _cuisine = cuisine;
                                // Auto-set currency based on cuisine/country
                                final country = _cuisineToCountry[cuisine] ?? 'United States';
                                _budgetCurrency = _getCurrencyForCountry(country);
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDietPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _diets.map((diet) {
            return ListTile(
              title: Text(diet),
              leading: Icon(
                Icons.health_and_safety,
                color: _diet == diet ? const Color(0xFF2196F3) : Colors.grey,
              ),
              onTap: () {
                setState(() => _diet = diet);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFlavorPicker(BuildContext context) {
    // Use a local copy so we can update in the bottom sheet without closing
    final tempSelected = List<String>.from(_selectedFlavors);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Fixed header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      children: [
                        const Text(
                          'Select Flavor Profiles',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose one or more taste profiles',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // ── Scrollable flavor list ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: _flavors.map((flavor) {
                          final name = flavor['name'] as String;
                          final isSelected = tempSelected.contains(name);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (flavor['color'] as Color).withOpacity(0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? (flavor['color'] as Color)
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (flavor['color'] as Color).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  flavor['icon'] as IconData,
                                  color: flavor['color'] as Color,
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                              subtitle: Text(
                                flavor['description'] as String,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: flavor['color'] as Color,
                                    )
                                  : Icon(
                                      Icons.circle_outlined,
                                      color: Colors.grey.shade400,
                                    ),
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    tempSelected.remove(name);
                                  } else {
                                    tempSelected.add(name);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // ── Fixed Done button ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: tempSelected.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _selectedFlavors = List<String>.from(tempSelected);
                                });
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          tempSelected.isEmpty
                              ? 'Select at least one flavor'
                              : 'Done (${tempSelected.length} selected)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCookingTimePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Cooking Time',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your available preparation time',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ..._cookingTimes.map((timeOption) {
              final isSelected = _cookingTime == timeOption['name'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (timeOption['color'] as Color).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (timeOption['color'] as Color)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (timeOption['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      timeOption['icon'] as IconData,
                      color: timeOption['color'] as Color,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        timeOption['name'] as String,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (timeOption['color'] as Color).withOpacity(
                            0.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timeOption['range'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: timeOption['color'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    timeOption['description'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: timeOption['color'] as Color,
                        )
                      : null,
                  onTap: () {
                    setState(() => _cookingTime = timeOption['name'] as String);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showBudgetPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Budget Level',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set your meal planning budget',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ..._budgetLevels.map((budget) {
              final isSelected = _budgetLevel == budget['name'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (budget['color'] as Color).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (budget['color'] as Color)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (budget['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      budget['icon'] as IconData,
                      color: budget['color'] as Color,
                    ),
                  ),
                  title: Text(
                    budget['name'] as String,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  subtitle: Text(
                    budget['description'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: budget['color'] as Color,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _budgetLevel = budget['name'] as String;
                      if (_budgetLevel == 'Custom Budget') {
                        Navigator.pop(context);
                        _showCustomBudgetDialog(context);
                      } else {
                        // Clear custom budget amount when switching to preset budgets
                        _budgetAmount = null;
                      }
                    });
                    if (_budgetLevel != 'Custom Budget') {
                      Navigator.pop(context);
                    }
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showCustomBudgetDialog(BuildContext context) {
    String tempCurrency = _budgetCurrency; // Local copy for dialog state
    final controller = TextEditingController(
      text: _budgetAmount?.toStringAsFixed(0) ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Custom Budget'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tempCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items: CurrencyUtils.availableCurrencies.map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: SizedBox(
                        width: 250,
                        child: Text(
                          '$currency - ${CurrencyUtils.getCurrencyNameByCode(currency)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      tempCurrency = value ?? 'USD';
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Budget Amount per week',
                    border: const OutlineInputBorder(),
                    prefixText: '$tempCurrency ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _budgetCurrency = tempCurrency;
                  _budgetAmount = double.tryParse(controller.text);
                  _budgetLevel = _budgetAmount != null
                      ? '$_budgetCurrency ${_budgetAmount!.toStringAsFixed(0)}/week'
                      : 'Custom Budget';
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4CAF50)),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 70,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

