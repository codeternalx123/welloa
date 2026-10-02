import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auto_detection_service.dart';
import '../services/food_glucose_service.dart';
import '../services/gemini_food_detection_service.dart';
import '../widgets/glycemic_load_chart.dart';
import '../widgets/feature_restriction_widgets.dart';
import '../models/food_item_nutrition.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/subscription_provider.dart';

/// UNICORN UX: Immersive Metabolic HUD & Neural Recognition Aperture.
/// Features: Kinetic Reticle, Glassmorphic HUD, and Haptic-Neural Synchronization.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isScanning = true;
  bool _isProcessing = false;

  // High-Fidelity States
  List<FoodGlucoseImpact>? _glucoseImpacts;
  String? _mealAdvice;
  String? _scanStatus;
  bool _isFlashOn = false;
  GlobalNutrition? _mealNutrition;
  double _mealFiber = 0.0;
  List<FoodItemNutrition> _detectedFoods = [];
  bool _isLoggingMeal = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 2026 UX: Soft "Neural Pulse" animation for the reticle
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _initializeCamera();
    
    // Check subscription status on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSubscriptionStatus();
    });
  }
  
  void _checkSubscriptionStatus() {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    // Only show subscribe prompt for expired paid subscriptions, not for free tier users
    if (subscriptionProvider.shouldShowSubscribePrompt && !subscriptionProvider.isFree) {
      FeatureRestrictionDialog.showSubscriptionPrompt(context);
      subscriptionProvider.clearError();
    } else if (subscriptionProvider.shouldShowSubscribePrompt) {
      subscriptionProvider.clearError();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ============================================
  // CORE UI: THE METABOLIC HUD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. RAW BIOMETRIC FEED (Camera)
          _buildCameraLayer(),

          // 2. SPATIAL HUD OVERLAY (The Glassmorphic UI)
          if (_isScanning || _isProcessing) _buildScanningOverlay(),

          // 3. THE RESULT NEXUS (Post-Scan Intelligence)
          if (!_isScanning && !_isProcessing) _buildResultsPanel(),

          // 4. TOP NAVIGATION & STATUS
          _buildTopControls(),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }
    return GestureDetector(
      onTap: _captureAndAnalyzeImage,
      child: SizedBox.expand(child: CameraPreview(_cameraController!)),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2), // Subtle vignette
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // KINETIC VOLUMETRIC RETICLE
            ScaleTransition(
              scale: _pulseAnimation,
              child: _MetabolicReticle(
                isProcessing: _isProcessing,
              ),
            ),
            const SizedBox(height: 40),
            _buildStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isProcessing
                    ? 'Analyzing...'
                    : 'Detecting Food Items',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _scanStatus ?? 'Hold steady for accurate results',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _HUDButton(
              icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
              active: _isFlashOn,
              onTap: _toggleFlash,
            ),
            const Text(
              'Scan Food',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            _HUDButton(
              icon: Icons.close, 
              onTap: () {
                // Navigate to home instead of popping since we're in IndexedStack
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  // Go back to home screen by finding the main screen state
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // RESULT NEXUS: METABOLIC INTELLIGENCE
  // ============================================

  Widget _buildResultsPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 100 * value),
            child: child,
          );
        },
        child: _ResultGlassPanel(
          impacts: _glucoseImpacts,
          advice: _mealAdvice,
          nutrition: _mealNutrition,
          fiber: _mealFiber,
          foodItems: _detectedFoods,
          isLogging: _isLoggingMeal,
          onReset: () => setState(() => _isScanning = true),
          onLogToFirestore: _logMealToFirestore,
        ),
      ),
    );
  }

  // ============================================
  // LOGIC & ORCHESTRATION
  // ============================================

  Future<void> _captureAndAnalyzeImage() async {
    if (!_isScanning || _isProcessing) return;

    // Check scan limit for free users
    if (!checkScanLimitAccess(context)) {
      return;
    }

    // Record the scan usage
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final canProceed = await subscriptionProvider.recordScan();
    if (!canProceed) {
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isScanning = false;
      _isProcessing = true;
      _scanStatus = 'Analyzing food...';
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();

      // Gemini 2.5 Flash AI Detection
      final result = await AutoDetectionService.analyzeImage(
        imageFile,
        userAllergens: [],
      );

      if (result.foods.isNotEmpty) {
        final foodNames = result.foods.map((f) => f.name).toList();
        final impacts = await FoodGlucoseService.analyzeMealMetabolics(
          ingredients: foodNames,
          userGlucotype: 'Baseline',
        );
        final advice = FoodGlucoseService.getMealClinicalSummary(impacts);

        // Use Gemini's detected nutrition data directly
        final foodItems = result.foods.map((dish) => FoodItemNutrition(
          name: dish.name,
          calories: dish.calories.toDouble(),
          proteinG: dish.proteinG,
          carbsG: dish.carbsG,
          fatG: dish.fatG,
          fiberG: 0.0,
          servingGrams: (dish.weightEstimate ?? 100).toDouble(),
        )).toList();

        // Calculate totals from Gemini results
        final nutrition = result.macros ?? GlobalNutrition(
          calories: foodItems.fold<int>(0, (total, item) => total + item.calories.toInt()),
          carbs: foodItems.fold<double>(0, (total, item) => total + item.carbsGrams).toInt(),
          protein: foodItems.fold<double>(0, (total, item) => total + item.proteinGrams).toInt(),
          fat: foodItems.fold<double>(0, (total, item) => total + item.fatGrams).toInt(),
        );

        setState(() {
          _glucoseImpacts = impacts;
          _mealAdvice = advice;
          _mealNutrition = nutrition;
          _mealFiber = 0.0;
          _detectedFoods = foodItems;
          _isProcessing = false;
        });
        HapticFeedback.vibrate();
      } else {
        throw Exception('No foods detected');
      }
    } catch (e) {
      _handleScanError(e);
    }
  }

  void _handleScanError(dynamic e) {
    setState(() {
      _isScanning = true;
      _isProcessing = false;
      _scanStatus = 'Could not detect foods. Try again.';
    });
    HapticFeedback.heavyImpact();
  }

  Future<void> _logMealToFirestore() async {
    if (_detectedFoods.isEmpty) return;

    setState(() => _isLoggingMeal = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final firestore = FirebaseFirestore.instance;
      final dateKey = _generateDateKey(DateTime.now());
      final mealsRef = firestore
          .collection('daily_nutrition')
          .doc(user.uid)
          .collection('days')
          .doc(dateKey)
          .collection('meals');

      // Create meal document
      final mealData = {
        'mealType': 'Scanned',
        'timestamp': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
        'foodItems': _detectedFoods
            .map(
              (item) => {
                'name': item.name,
                'calories': item.calories,
                'proteinG': item.proteinGrams,
                'carbsG': item.carbsGrams,
                'fatG': item.fatGrams,
                'fiberG': item.fiberGrams,
                'servingGrams': item.servingGrams,
              },
            )
            .toList(),
        'totalCalories': _detectedFoods.fold<double>(
          0,
          (total, item) => total + item.calories,
        ),
        'totalProtein': _detectedFoods.fold<double>(
          0,
          (total, item) => total + item.proteinGrams,
        ),
        'totalCarbs': _detectedFoods.fold<double>(
          0,
          (total, item) => total + item.carbsGrams,
        ),
        'totalFat': _detectedFoods.fold<double>(
          0,
          (total, item) => total + item.fatGrams,
        ),
        'totalFiber': _detectedFoods.fold<double>(
          0,
          (total, item) => total + item.fiberGrams,
        ),
      };

      // Save to meals subcollection
      await mealsRef.add(mealData);

      // Update daily totals
      final dayRef = firestore
          .collection('daily_nutrition')
          .doc(user.uid)
          .collection('days')
          .doc(dateKey);

      final daySnapshot = await dayRef.get();
      final dayData = daySnapshot.data() ?? {};

      final totalCalories =
          ((dayData['totalCalories'] ?? 0.0) as num) +
          (mealData['totalCalories'] as num);
      final totalProtein =
          ((dayData['totalProtein'] ?? 0.0) as num) +
          (mealData['totalProtein'] as num);
      final totalCarbs =
          ((dayData['totalCarbs'] ?? 0.0) as num) +
          (mealData['totalCarbs'] as num);
      final totalFat =
          ((dayData['totalFat'] ?? 0.0) as num) + (mealData['totalFat'] as num);
      final totalFiber =
          ((dayData['totalFiber'] ?? 0.0) as num) +
          (mealData['totalFiber'] as num);

      await dayRef.set({
        'date': DateTime.now(),
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'totalCarbs': totalCarbs,
        'totalFat': totalFat,
        'totalFiber': totalFiber,
        'totalSodium': (dayData['totalSodium'] ?? 0.0),
        'mealsLogged': ((dayData['mealsLogged'] ?? dayData['mealCount'] ?? 0) as int) + 1,
      }, SetOptions(merge: true));

      // Refresh the nutrition provider to update home screen rings
      if (mounted) {
        // ignore: use_build_context_synchronously
        final nutritionProvider = context.read<NutritionGoalsProvider>();
        await nutritionProvider.loadTodayNutrition();
      }

      setState(() => _isLoggingMeal = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_detectedFoods.length} food item(s) logged successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoggingMeal = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log meal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Camera initialization helper...
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    _isFlashOn = !_isFlashOn;
    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
    setState(() {});
    HapticFeedback.lightImpact();
  }
}

// ============================================
// ATOMIC UX WIDGETS (The Unicorn Library)
// ============================================

class _MetabolicReticle extends StatelessWidget {
  final bool isProcessing;
  const _MetabolicReticle({
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isProcessing ? Colors.orangeAccent : Colors.greenAccent;
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(125),
      ),
      child: Stack(
        children: [
          _ReticleCorner(top: 0, left: 0, color: color, rotation: 0),
          _ReticleCorner(top: 0, right: 0, color: color, rotation: 1.57),
          _ReticleCorner(bottom: 0, left: 0, color: color, rotation: 4.71),
          _ReticleCorner(bottom: 0, right: 0, color: color, rotation: 3.14),
          if (isProcessing)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.orangeAccent,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultGlassPanel extends StatelessWidget {
  final List<FoodGlucoseImpact>? impacts;
  final String? advice;
  final GlobalNutrition? nutrition;
  final double fiber;
  final List<FoodItemNutrition> foodItems;
  final bool isLogging;
  final VoidCallback onReset;
  final VoidCallback onLogToFirestore;

  const _ResultGlassPanel({
    this.impacts,
    this.advice,
    this.nutrition,
    this.fiber = 0.0,
    required this.foodItems,
    this.isLogging = false,
    required this.onReset,
    required this.onLogToFirestore,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SCAN RESULTS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 16),
                // 1. DETECTED FOODS - Allow Editing
                _buildDetectedFoodsCard(),
                const SizedBox(height: 24),
                // 2. GLYCEMIC LOAD CHART
                if (nutrition != null) ...[
                  const Text(
                    'NUTRITIONAL ANALYSIS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlycemicLoadChart(
                    carbs: nutrition!.carbs.toDouble(),
                    fiber: fiber,
                    protein: nutrition!.protein.toDouble(),
                    fat: nutrition!.fat.toDouble(),
                  ),
                  const SizedBox(height: 24),
                ],
                // 3. PORTIONS & SERVING SIZES
                _buildPortionsSizeCard(),
                const SizedBox(height: 24),
                // 4. MEAL ADVICE
                if (advice != null) ...[
                  const Text(
                    'MEAL INSIGHTS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAdviceCard(advice!),
                  const SizedBox(height: 24),
                ],
                // 5. NEURAL METABOLIC FORECAST
                _buildNeuralForecast(context),
                const SizedBox(height: 24),
                // 6. ACTION BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLogging ? null : onLogToFirestore,
                        icon: isLogging
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(isLogging ? 'LOGGING...' : 'LOG MEAL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildActionButton()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdviceCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_rounded, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedFoodsCard() {
    if (foodItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_rounded, color: Colors.orange, size: 18),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No foods detected. Please try again.',
                style: TextStyle(fontSize: 14, color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Detected ${foodItems.length} food${foodItems.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...foodItems.asMap().entries.map((entry) {
            final index = entry.key;
            final food = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${food.calories.toStringAsFixed(0)} kcal',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: Builder(
                      builder: (ctx) => ElevatedButton(
                        onPressed: () => _showFoodEditDialog(food, index, ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPortionsSizeCard() {
    if (foodItems.isEmpty || nutrition == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_rounded,
                color: Colors.purple,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Serving Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _buildPortionInfo(
                'SERVING SIZE',
                '${foodItems.first.servingGrams.toStringAsFixed(0)}g',
                Colors.purple,
              ),
              _buildPortionInfo(
                'CALORIES',
                '${nutrition!.calories.toStringAsFixed(0)} kcal',
                Colors.orange,
              ),
              _buildPortionInfo(
                'PROTEIN',
                '${nutrition!.protein.toStringAsFixed(1)}g',
                Colors.green,
              ),
              _buildPortionInfo(
                'CARBS',
                '${nutrition!.carbs.toStringAsFixed(1)}g',
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortionInfo(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 9,
              color: Colors.blueGrey,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showFoodEditDialog(
    FoodItemNutrition food,
    int index,
    BuildContext parentContext,
  ) {
    showDialog(
      context: parentContext,
      builder: (context) => _FoodEditDialog(
        food: food,
        onSave: (updatedFood) {
          // Update the food item
          final updatedItems = List<FoodItemNutrition>.from(foodItems);
          updatedItems[index] = updatedFood;
          // Update parent state - would need to be passed as callback
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildNeuralForecast(BuildContext context) {
    return Consumer2<NutritionGoalsProvider, UserProfileProvider>(
      builder: (context, nutritionProvider, userProvider, _) {
        // Get user goals
        final userGoals = nutritionProvider.userGoals;
        final todayTracker = nutritionProvider.todayTracker;

        // Calculate totals from newly detected foods
        final newFoodCalories = foodItems.fold<double>(
          0,
          (total, item) => total + item.calories,
        );
        final newFoodProtein = foodItems.fold<double>(
          0,
          (total, item) => total + item.proteinGrams,
        );
        final newFoodCarbs = foodItems.fold<double>(
          0,
          (total, item) => total + item.carbsGrams,
        );
        final newFoodFat = foodItems.fold<double>(
          0,
          (total, item) => total + item.fatGrams,
        );

        // Get already consumed totals from today
        final consumedCalories = todayTracker?.totalCalories ?? 0.0;
        final consumedProtein = todayTracker?.totalProtein ?? 0.0;
        final consumedCarbs = todayTracker?.totalCarbs ?? 0.0;
        final consumedFat = todayTracker?.totalFat ?? 0.0;

        // Get goals - prioritize saved goals, then compute from profile, then defaults
        final userProfile = userProvider.userProfile;
        final calorieGoal = userGoals?.dailyCalorieGoal 
            ?? userProfile?.dailyCalorieTarget.toDouble() 
            ?? 2000.0;
        final proteinGoal = userGoals?.proteinGoalGrams 
            ?? userProfile?.dailyProteinTarget.toDouble() 
            ?? 150.0;
        final carbsGoal = userGoals?.carbsGoalGrams 
            ?? userProfile?.dailyCarbsTarget.toDouble() 
            ?? 200.0;
        final fatGoal = userGoals?.fatGoalGrams 
            ?? userProfile?.dailyFatTarget.toDouble() 
            ?? 65.0;

        // Calculate remaining after adding new food
        final caloriesRemaining =
            (calorieGoal - consumedCalories - newFoodCalories).clamp(
              0.0,
              double.infinity,
            );
        final proteinRemaining =
            (proteinGoal - consumedProtein - newFoodProtein).clamp(
              0.0,
              double.infinity,
            );
        final carbsRemaining = (carbsGoal - consumedCarbs - newFoodCarbs).clamp(
          0.0,
          double.infinity,
        );
        final fatRemaining = (fatGoal - consumedFat - newFoodFat).clamp(
          0.0,
          double.infinity,
        );

        // Calculate percentages
        final caloriesPercent =
            ((consumedCalories + newFoodCalories) / calorieGoal * 100)
                .clamp(0, 100)
                .toInt();
        final proteinPercent =
            ((consumedProtein + newFoodProtein) / proteinGoal * 100)
                .clamp(0, 100)
                .toInt();
        final carbsPercent = ((consumedCarbs + newFoodCarbs) / carbsGoal * 100)
            .clamp(0, 100)
            .toInt();
        final fatPercent = ((consumedFat + newFoodFat) / fatGoal * 100)
            .clamp(0, 100)
            .toInt();

        // Debug logging
        debugPrint('=== REMAINING CAPACITY DEBUG ===');
        debugPrint('User Goals Loaded: ${userGoals != null}');
        debugPrint('Daily Calorie Goal: $calorieGoal');
        debugPrint(
          'Consumed Today: $consumedCalories | New Food: $newFoodCalories | Remaining: $caloriesRemaining',
        );
        debugPrint('===================================');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.withValues(alpha: 0.08),
                Colors.purple.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.indigo.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REMAINING CAPACITY',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: Colors.indigo,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          userGoals != null 
                            ? 'Based on your daily goals'
                            : (userProfile != null 
                              ? 'Based on your health profile (${calorieGoal.toStringAsFixed(0)} kcal/day)'
                              : 'Using default targets'),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 8,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bars for each macro with explicit remaining display
              _buildMacroProgress(
                'Calories',
                caloriesPercent,
                '${(consumedCalories + newFoodCalories).toStringAsFixed(0)}/${calorieGoal.toStringAsFixed(0)} | ${caloriesRemaining.toStringAsFixed(0)} kcal left',
                Colors.orange,
              ),
              const SizedBox(height: 8),
              _buildMacroProgress(
                'Protein',
                proteinPercent,
                '${(consumedProtein + newFoodProtein).toStringAsFixed(1)}/${proteinGoal.toStringAsFixed(1)}g | ${proteinRemaining.toStringAsFixed(1)}g left',
                Colors.green,
              ),
              const SizedBox(height: 8),
              _buildMacroProgress(
                'Carbs',
                carbsPercent,
                '${(consumedCarbs + newFoodCarbs).toStringAsFixed(1)}/${carbsGoal.toStringAsFixed(1)}g | ${carbsRemaining.toStringAsFixed(1)}g left',
                Colors.red,
              ),
              const SizedBox(height: 8),
              _buildMacroProgress(
                'Fat',
                fatPercent,
                '${(consumedFat + newFoodFat).toStringAsFixed(1)}/${fatGoal.toStringAsFixed(1)}g | ${fatRemaining.toStringAsFixed(1)}g left',
                Colors.amber,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroProgress(
    String label,
    int percent,
    String details,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Colors.blueGrey,
              ),
            ),
            Flexible(
              child: Text(
                details,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$percent% of daily goal',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 8,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onReset,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'NEW ANALYSIS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }
}

// ============================================
// FOOD EDIT DIALOG
// ============================================
class _FoodEditDialog extends StatefulWidget {
  final FoodItemNutrition food;
  final Function(FoodItemNutrition) onSave;

  const _FoodEditDialog({required this.food, required this.onSave});

  @override
  State<_FoodEditDialog> createState() => _FoodEditDialogState();
}

class _FoodEditDialogState extends State<_FoodEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _servingController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.food.name);
    _caloriesController = TextEditingController(
      text: widget.food.calories.toStringAsFixed(0),
    );
    _proteinController = TextEditingController(
      text: widget.food.proteinG.toStringAsFixed(1),
    );
    _carbsController = TextEditingController(
      text: widget.food.carbsG.toStringAsFixed(1),
    );
    _fatController = TextEditingController(
      text: widget.food.fatG.toStringAsFixed(1),
    );
    _servingController = TextEditingController(
      text: widget.food.servingGrams.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit Food Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTextField('Food Name', _nameController),
              const SizedBox(height: 16),
              const Text(
                'Nutrition Per ${100}g',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildNutritionField('Calories (kcal)', _caloriesController),
                  _buildNutritionField('Protein (g)', _proteinController),
                  _buildNutritionField('Carbs (g)', _carbsController),
                  _buildNutritionField('Fat (g)', _fatController),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField('Serving Size (g)', _servingController),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveFoodEdits,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  void _saveFoodEdits() {
    try {
      final updatedFood = FoodItemNutrition(
        name: _nameController.text,
        calories:
            double.tryParse(_caloriesController.text) ?? widget.food.calories,
        proteinG:
            double.tryParse(_proteinController.text) ?? widget.food.proteinG,
        carbsG: double.tryParse(_carbsController.text) ?? widget.food.carbsG,
        fatG: double.tryParse(_fatController.text) ?? widget.food.fatG,
        fiberG: widget.food.fiberG,
        servingGrams:
            double.tryParse(_servingController.text) ??
            widget.food.servingGrams,
      );

      widget.onSave(updatedFood);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food details updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating food: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _HUDButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _HUDButton({
    required this.icon,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? Colors.greenAccent
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReticleCorner extends StatelessWidget {
  final double? top, bottom, left, right;
  final Color color;
  final double rotation;
  const _ReticleCorner({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.color,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 4),
              left: BorderSide(color: color, width: 4),
            ),
          ),
        ),
      ),
    );
  }
}
