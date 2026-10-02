import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/neural_discovery_overlay.dart';
import '../widgets/neural_thread_painter.dart';
import '../widgets/glycemic_load_chart.dart';
import '../widgets/feature_restriction_widgets.dart';

// Models & Providers
import '../models/food_item_nutrition.dart';
import '../providers/streak_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/user_profile_provider.dart';

// Core Unicorn Services
import '../services/nutrition_data_service.dart';

// Legacy Feature Services
import '../services/auto_detection_service.dart';
import '../services/clinical_nutrition_advisor.dart';

// Responsive Design
import '../utils/responsive_utils.dart';

class AIFoodScannerScreen extends StatefulWidget {
  const AIFoodScannerScreen({super.key});

  @override
  State<AIFoodScannerScreen> createState() => _AIFoodScannerScreenState();
}

class _AIFoodScannerScreenState extends State<AIFoodScannerScreen>
    with SingleTickerProviderStateMixin {
  // Controllers & State
  CameraController? _cameraController;
  bool _isScanning = true;
  bool _isProcessing = false;
  String? _statusMessage;

  // Logic Engines
  final _clinicalAdvisor = ClinicalNutritionAdvisor();

  // Data Containers
  List<FoodItemNutrition> _editableFoodItems = [];
  ClinicalNutritionRecommendation? _clinicalRecommendation;
  final bool _safetyPassed = true;

  // Live detection coordinates for thread painter
  final List<LiveObjectDetection> _liveDetections = [];
  final List<Offset> _bubbleOffsets = []; // Screen coordinates for threads

  bool _isFlashOn = false;
  bool _isLogging = false;
  bool _barcodeMode = false;

  MobileScannerController? _barcodeController;
  String? _lastScannedBarcode;
  DateTime? _lastBarcodeScanAt;
  
  // Meal Type Selection
  String _selectedMealType = 'lunch';

  // Neural pulse controller for thread painter
  late final AnimationController _neuralPulseController;

  /// Returns true if the device has no internet connection
  Future<bool> _isOffline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Checks if an error is network/connectivity related
  bool _isNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    return error is SocketException ||
        error is TimeoutException ||
        msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('unreachable') ||
        msg.contains('failed host lookup') ||
        msg.contains('errno = 7') ||
        msg.contains('errno = 101') ||
        msg.contains('unavailable') ||
        msg.contains('deadline exceeded');
  }

  @override
  void initState() {
    super.initState();
    _initializeUnifiedCamera();
    AutoDetectionService.initialize(); // Added from second code

    _neuralPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _neuralPulseController.addListener(() {
      // Trigger a microscopic haptic tap when the energy bead "hits" the hub
      if (_neuralPulseController.value > 0.95 && _liveDetections.isNotEmpty) {
        HapticFeedback.selectionClick();
      }
    });
  }

  Future<void> _initializeUnifiedCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _statusMessage = 'No camera available');
      return;
    }

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeController?.dispose();
    _neuralPulseController.dispose();
    AutoDetectionService.dispose();
    super.dispose();
  }

  Future<void> _setBarcodeMode(bool enabled) async {
    if (_barcodeMode == enabled || _isProcessing) return;

    setState(() {
      _barcodeMode = enabled;
      _statusMessage = null;
      _lastScannedBarcode = null;
      _lastBarcodeScanAt = null;
    });

    if (enabled) {
      await _cameraController?.dispose();
      _cameraController = null;
      _barcodeController ??= MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    } else {
      await _barcodeController?.dispose();
      _barcodeController = null;
      await _initializeUnifiedCamera();
    }

    if (mounted) setState(() {});
  }

  // ============================================
  // UNICORN PIPELINE: THE FUSION LOGIC (COMMENTED OUT - UNUSED)
  // ============================================

  /* Future<void> _processCapturedMeal(List<String> paths) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Analyzing your meal...";
    });

    try {
      final userProfile = context.read<UserProfileProvider>();
      final registry = NutritionIntelligenceRegistry();

      // 1. AI DETECTION & REGISTRY RESOLUTION
      // We use the registry to intelligently route fresh food vs packaged goods
      final rawResult = await registry.resolveIntelligence("Detected Meal Items");

      // 2. NUTRITION NORMALIZATION
      // Convert the Map result to VerifiedNutritionData
      final verifiedData = VerifiedNutritionData.fromMap(rawResult);
      
      // Automatically scale the result to the detected portion volume
      final normalized = _normalizer.normalize(
        rawData: verifiedData, 
        targetWeightGrams: 250.0, // Example detected volume
      );

      // === Allergen Safety Audit (run immediately after AI returns ingredients)
      try {
        final profile = context.read<UserProfileProvider>();
        final ingredients = (rawResult['ingredients'] as List<dynamic>?)?.cast<String>() ?? [];
        final safetyReport = AllergenSafetyGuard().auditProduct(
            ingredients: ingredients,
            userAllergens: profile.userProfile?.diseases ?? [],
          );

          if (!safetyReport.isSafe) {
            // Show interruption dialog and prevent logging
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Safety Alert'),
                content: Text(safetyReport.message),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                ],
              ),
            );
            _safetyPassed = false;
            setState(() => _isProcessing = false);
            return;
          } else {
            _safetyPassed = true;
          }
        } catch (_) {
          // If audit fails unexpectedly, allow flow to continue but mark safety as unknown
          _safetyPassed = true;
        }

        // 3. METABOLIC INFERENCE
        // Calculate the impact on today's rings BEFORE saving
        final impact = await _balanceEngine.calculateBalance(
          mealLogs: [normalized],
          profile: userProfile
        );        
        setState(() {
          _editableFoodItems = [FoodItemNutrition.fromVerified(normalized)];
          _predictedBalance = impact;
          _isScanning = false;
        });
    } catch (e) {
      setState(() => _statusMessage = "We couldn't analyze this meal. Please try again.");
    } finally {
      setState(() => _isProcessing = false);
    }
  } */

  /// Capture and analyze with subscription check
  Future<void> _captureAndAnalyze() async {
    if (!_isScanning || _isProcessing || _cameraController == null) return;

    // Check subscription limits
    // ignore: use_build_context_synchronously
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final canScan = await subscriptionProvider.recordScan();

    if (!canScan) {
      _showUpgradeDialog();
      return;
    }

    // Check connectivity before proceeding
    if (await _isOffline()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'re offline. Please connect to the internet to scan food.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing with AI...';
    });

    try {
      // Capture image
      final XFile image = await _cameraController!.takePicture();

      final userProfileProvider = context.read<UserProfileProvider>();
      final detection = await AutoDetectionService.analyzeImage(
        image,
        userAllergens: userProfileProvider.userProfile?.diseases ?? [],
      );

      if (!mounted) return;

      final detectedItems = _mapAutoDetectionToFoodItems(detection);

      if (detectedItems.isNotEmpty) {
        setState(() {
          _editableFoodItems = detectedItems;
          _isScanning = false;
          _isProcessing = false;
          _statusMessage = null;
        });

        _generateClinicalRecommendation();

        // Fetch detailed nutrition data from database
        _fetchDetailedNutrition(_editableFoodItems);
      } else {
        setState(() {
          _statusMessage = 'No food detected. Try using better lighting.';
          _isProcessing = false;
        });
        return;
      }

      // Increment streak
      if (mounted) {
        // ignore: use_build_context_synchronously
        context.read<StreakProvider>().incrementStreak();
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        final message = _isNetworkError(e)
            ? 'You\'re offline. Please connect to the internet and try again.'
            : err.contains('GEMINI_API_KEY') || err.contains('not initialized')
                ? 'Food scanner needs GEMINI_API_KEY or ANTHROPIC_API_KEY in .env. Restart the app.'
                : err.contains('NO_FOOD_DETECTED')
                    ? 'No food detected. Try better lighting or switch to barcode mode for packaged foods.'
                    : 'We couldn\'t analyze this meal. Try barcode mode for packaged items.';
        setState(() {
          _statusMessage = message;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processBarcode(String barcode) async {
    if (!_isScanning || _isProcessing) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final canScan = await subscriptionProvider.recordScan();
    if (!canScan) {
      _showUpgradeDialog();
      return;
    }

    if (await _isOffline()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'re offline. Connect to the internet to look up barcodes.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Looking up product...';
    });

    try {
      final result = await NutritionDataService().fetchByBarcode(barcode);
      if (!mounted) return;

      if (!result.isSuccess || result.food == null) {
        setState(() {
          _statusMessage = result.isNotFound
              ? 'Product not found. Try AI scan for fresh meals.'
              : (result.error ?? 'Barcode lookup failed. Try again.');
          _isProcessing = false;
        });
        return;
      }

      final item = _foodItemFromWellor(result.food!);
      setState(() {
        _editableFoodItems = [item];
        _isScanning = false;
        _isProcessing = false;
        _statusMessage = null;
      });

      _generateClinicalRecommendation();
      if (mounted) {
        context.read<StreakProvider>().incrementStreak();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = _isNetworkError(e)
              ? 'You\'re offline. Connect and try again.'
              : 'Barcode lookup failed. Please try again.';
          _isProcessing = false;
        });
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_barcodeMode || _isProcessing || !_isScanning) return;

    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');

    if (code.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedBarcode == code &&
        _lastBarcodeScanAt != null &&
        now.difference(_lastBarcodeScanAt!) < const Duration(seconds: 3)) {
      return;
    }

    _lastScannedBarcode = code;
    _lastBarcodeScanAt = now;
    HapticFeedback.mediumImpact();
    _processBarcode(code);
  }

  FoodItemNutrition _foodItemFromWellor(WellorFoodItem item) {
    final grams = item.servingSize ?? 100.0;
    final factor = grams / 100.0;
    final displayName = item.brand != null && item.brand!.isNotEmpty
        ? '${item.brand} — ${item.name}'
        : item.name;

    return FoodItemNutrition(
      name: displayName,
      calories: item.calories * factor,
      proteinG: item.protein * factor,
      carbsG: item.carbs * factor,
      fatG: item.fat * factor,
      fiberG: (item.fiber ?? 0) * factor,
      servingGrams: grams,
    );
  }

  /* void _updateLiveDetections(List<LiveObjectDetection> newDetections) {
    setState(() {
      _liveDetections = newDetections;
      // Map bounding boxes to center Offsets for the Thread Painter
      final previewSize = _cameraController?.value.previewSize;
      if (previewSize != null) {
        _bubbleOffsets = newDetections.map((d) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          return Offset(
            (d.boundingBox.center.dx / previewSize.height) * screenWidth,
            (d.boundingBox.center.dy / previewSize.width) * screenHeight,
          );
        }).toList();
      }
    });
  } */

  // ============================================
  // PRODUCT INTELLIGENCE ROUTE (Barcode / Label) - COMMENTED OUT (UNUSED)
  // ============================================
  /* Future<void> _processIntelligence(String barcodeOrLabel, {bool isBarcode = true}) async {
    setState(() => _isProcessing = true);

    try {
      ClinicalFoodProduct? clinicalProduct;

      if (isBarcode) {
        clinicalProduct = await ProductIntelligenceService.getByBarcode(barcodeOrLabel);
      } else {
        final resolved = await ProductIntelligenceService.resolveLabels([barcodeOrLabel]);
        clinicalProduct = resolved.isNotEmpty ? resolved.first : null;
      }

      if (clinicalProduct != null) {
        // Simple Allergen Audit: compare product allergens with user profile diseases/allergies
        final profile = context.read<UserProfileProvider>().userProfile;
        final hasAllergenConflict = clinicalProduct.allergens.isNotEmpty && profile != null
            && profile.diseases.any((d) => clinicalProduct!.allergens.map((a) => a.toLowerCase()).contains(d.toLowerCase()));

        if (hasAllergenConflict) {
          // Show interruption dialog and stop
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Safety Alert'),
              content: const Text('This product may not be a good fit for your health profile. We stopped processing it for your safety.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
              ],
            ),
          );
          setState(() => _isProcessing = false);
          return;
        }

        // Map to editable UI state (adapter). If FoodItemNutrition.fromClinical exists, use it.
        setState(() {
          _editableFoodItems = [FoodItemNutrition.fromClinical(clinicalProduct!)];
          _isScanning = false;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() => _statusMessage = 'Intelligence pipeline error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  } */

  // ============================================
  // HELPER METHODS FROM SECOND CODE
  // ============================================

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => const FeatureRestrictionDialog(
        featureName: 'Food Scanning',
        featureDescription:
            'Unlock unlimited AI-powered food scanning and detailed nutrition analysis to reach your health goals faster.',
        icon: Icons.qr_code_scanner,
      ),
    );
  }

  /// Fetch detailed nutrition data for detected foods from NutritionDataService
  Future<void> _fetchDetailedNutrition(List<FoodItemNutrition> foods) async {
    try {
      final nutritionService = NutritionDataService();
      final updatedFoods = <FoodItemNutrition>[];

      for (final food in foods) {
        try {
          final result = await nutritionService.fetchFoodData(food.name);
          if (result.isSuccess && result.food != null) {
            final nutritionData = result.food!;
            updatedFoods.add(
              FoodItemNutrition(
                name: food.name,
                calories: nutritionData.calories,
                proteinG: nutritionData.protein,
                carbsG: nutritionData.carbs,
                fatG: nutritionData.fat,
                fiberG: food.fiberGrams, // Keep original fiber if available
                servingGrams: food.servingGrams,
              ),
            );
          } else {
            // Keep original if fetch fails
            updatedFoods.add(food);
          }
        } catch (e) {
          debugPrint('Failed to fetch nutrition for ${food.name}: $e');
          updatedFoods.add(food);
        }
      }

      if (mounted) {
        setState(() {
          _editableFoodItems = updatedFoods;
        });
        
        // Generate clinical nutrition recommendation after detailed nutrition is fetched
        _generateClinicalRecommendation();
      }
    } catch (e) {
      debugPrint('Error fetching detailed nutrition: $e');
    }
  }

  void _resetScanner() {
    setState(() {
      _editableFoodItems.clear();
      _isScanning = true;
      _statusMessage = null;
      _lastScannedBarcode = null;
      _lastBarcodeScanAt = null;
    });
  }

  Widget _buildScanModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scanModeChip(
            label: 'AI',
            icon: Icons.camera_alt_outlined,
            selected: !_barcodeMode,
            onTap: () => _setBarcodeMode(false),
          ),
          _scanModeChip(
            label: 'Barcode',
            icon: Icons.qr_code_scanner,
            selected: _barcodeMode,
            onTap: () => _setBarcodeMode(true),
          ),
        ],
      ),
    );
  }

  Widget _scanModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4CAF50) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if a product name is generic/invalid (not properly identified)
  bool _isGenericProductName(String? name) {
    if (name == null || name.isEmpty) return true;
    final lower = name.toLowerCase().trim();
    const genericNames = [
      'scanned product',
      'product',
      'food',
      'item',
      'unknown product',
      'generic',
      'barcode product',
      'packaged food',
      'packaged product',
    ];
    return genericNames.any((g) => lower == g || lower.contains('scanned product'));
  }

  List<FoodItemNutrition> _mapAutoDetectionToFoodItems(AutoDetectionResult detection) {
    if (detection.foods.isNotEmpty) {
      // Filter out foods with generic names
      final validFoods = detection.foods.where((dish) {
        if (!_isGenericProductName(dish.name)) return true;
        return dish.calories > 0 || dish.proteinG > 0 || dish.carbsG > 0 || dish.fatG > 0;
      }).toList();

      if (validFoods.isEmpty) return const [];

      return validFoods.map((dish) {
        final hasOwnNutrition = dish.calories > 0;
        return FoodItemNutrition(
          name: dish.name.trim().isEmpty || dish.name == 'Unknown'
              ? 'Detected food'
              : dish.name,
          calories: hasOwnNutrition 
              ? dish.calories.toDouble() 
              : (detection.macros?.calories ?? 0).toDouble(),
          proteinG: hasOwnNutrition 
              ? dish.proteinG 
              : (detection.macros?.protein ?? 0).toDouble(),
          carbsG: hasOwnNutrition 
              ? dish.carbsG 
              : (detection.macros?.carbs ?? 0).toDouble(),
          fatG: hasOwnNutrition 
              ? dish.fatG 
              : (detection.macros?.fat ?? 0).toDouble(),
          fiberG: 0,
          servingGrams: (dish.weightEstimate ?? 100).toDouble(),
        );
      }).toList();
    }

    return const [];
  }

  void _toggleFlash() {
    if (_cameraController == null) return;

    setState(() {
      _isFlashOn = !_isFlashOn;
    });

    try {
      if (_isFlashOn) {
        _cameraController!.setFlashMode(FlashMode.torch);
      } else {
        _cameraController!.setFlashMode(FlashMode.off);
      }
    } catch (e) {
      debugPrint('Flash control error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flash not available: $e')));
    }
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN STACK
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // LAYER 1: Raw Biometric Feed
            _buildCameraLayer(),

            // LAYER 2: Neural Thread Painter (Under the bubbles)
            if (_liveDetections.isNotEmpty)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _neuralPulseController,
                  builder: (context, _) => CustomPaint(
                    painter: NeuralThreadPainter(
                      bubblePositions: _bubbleOffsets,
                      hubPosition: Offset(
                        MediaQuery.of(context).size.width / 2,
                        MediaQuery.of(context).size.height - 120,
                      ),
                      pulseValue: _neuralPulseController.value,
                    ),
                  ),
                ),
              ),

            // LAYER 3: Neural Discovery Overlay (Floating Bubbles)
            if (_cameraController != null &&
                _cameraController!.value.isInitialized &&
                _cameraController!.value.previewSize != null)
              Positioned.fill(
                child: NeuralDiscoveryOverlay(
                  detections: _liveDetections,
                  previewSize: _cameraController!.value.previewSize!,
                ),
              ),

            // LAYER 4: The Static HUD & Controls
            _buildScanningHUD(),
            _buildTopApertureControls(),
          ],
        ),
      ),
    );
  }

  // Camera layer wrapper to keep stack tidy
  Widget _buildCameraLayer() {
    if (_barcodeMode && _barcodeController != null) {
      return Positioned.fill(
        child: MobileScanner(
          controller: _barcodeController!,
          onDetect: _onBarcodeDetected,
        ),
      );
    }
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return Positioned.fill(child: CameraPreview(_cameraController!));
    }
    return Positioned.fill(
      child: Center(
        child: _statusMessage != null
            ? Text(_statusMessage!, style: const TextStyle(color: Colors.white))
            : const CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
    );
  }

  // Group existing overlay widgets into a single HUD layer
  Widget _buildScanningHUD() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Scan Limit Banner from second code
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Consumer<SubscriptionProvider>(
              builder: (context, subProvider, child) {
                if (subProvider.isFree) {
                  return const ScanLimitBanner();
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          if (_isScanning) ...[
            _buildScanningReticle(),
            if (!_barcodeMode) _buildFlashToggle(),

            // Capture Button (AI mode) or barcode hint
            if (_isScanning && !_isProcessing && !_barcodeMode)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _captureAndAnalyze,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            if (_isScanning && !_isProcessing && _barcodeMode)
              Positioned(
                bottom: 40,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Point at a product barcode — scan happens automatically',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
          ],

          // Processing Indicator from second code
          if (_isProcessing)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            ),

          // Status Message from second code
          if (_statusMessage != null)
            Positioned(
              bottom: 200,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),

          if (!_isScanning) _buildNutritionResultsPanel(),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  // Top-level aperture controls (back/menus). Minimal placeholder using existing icons.
  Widget _buildTopApertureControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _isProcessing ? null : () => _resetScanner(),
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Reset Scanner',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Food Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _barcodeMode ? 'Barcode lookup (Open Food Facts)' : 'AI-powered food detection',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            _buildScanModeToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionResultsPanel() {
    if (_editableFoodItems.isEmpty) {
      return const SizedBox();
    }

    final maxHeight = ResponsiveUtils.getBottomSheetHeight(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: padding,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveHeight(context, 20),
              ),
              const Text(
                'Scan Results',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 12,
                  color: Colors.blueGrey,
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveHeight(context, 16),
              ),

              if (_hasScanMetadata) ...[
                _buildScanDetailsCard(),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveHeight(context, 16),
                ),
              ],

              // 1. DETECTED FOODS
              _buildDetectedFoodsSection(),
              SizedBox(
                height: ResponsiveUtils.getResponsiveHeight(context, 24),
              ),

              // 2. SERVING INFORMATION
              _buildServingInformation(),
              SizedBox(
                height: ResponsiveUtils.getResponsiveHeight(context, 24),
              ),

              // 3. MEAL INSIGHTS
              _buildMealInsights(),
              SizedBox(
                height: ResponsiveUtils.getResponsiveHeight(context, 24),
              ),

              // 4. ACTION BUTTONS
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectedFoodsSection() {
    if (_editableFoodItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
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
        color: const Color(0xFF10B981).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
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
                  'Detected ${_editableFoodItems.length} food${_editableFoodItems.length > 1 ? 's' : ''}',
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
          ..._editableFoodItems.asMap().entries.map((entry) {
            final food = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            const SizedBox(height: 6),
                            Text(
                              '${food.calories.toStringAsFixed(0)} kcal',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () => _showFoodEditDialog(
                            food,
                            _editableFoodItems.indexOf(food),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNutrientBadge(
                          'Protein',
                          '${food.proteinGrams.toStringAsFixed(1)}g',
                          Colors.red,
                        ),
                        _buildNutrientBadge(
                          'Carbs',
                          '${food.carbsGrams.toStringAsFixed(1)}g',
                          Colors.blue,
                        ),
                        _buildNutrientBadge(
                          'Fat',
                          '${food.fatGrams.toStringAsFixed(1)}g',
                          Colors.amber,
                        ),
                        _buildNutrientBadge(
                          'Fiber',
                          '${food.fiberGrams.toStringAsFixed(1)}g',
                          Colors.green,
                        ),
                      ],
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

  bool get _hasScanMetadata {
    return false;
  }

  Widget _buildScanDetailsCard() {
    return const SizedBox.shrink();
  }

  Widget _buildNutritionalAnalysisSection() {
    final totalCarbs = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.carbsGrams,
    );
    final totalFiber = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.fiberGrams,
    );
    final totalProtein = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.proteinGrams,
    );
    final totalFat = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.fatGrams,
    );

    // Check if we have any macro data
    final hasMacroData = totalCarbs > 0 || totalProtein > 0 || totalFat > 0;

    if (!hasMacroData) {
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
                'Macro data not available. Try editing foods to add nutrition details.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutritional Analysis',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 12,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 12),
        GlycemicLoadChart(
          carbs: totalCarbs,
          fiber: totalFiber,
          protein: totalProtein,
          fat: totalFat,
        ),
      ],
    );
  }

  Widget _buildServingInformation() {
    if (_editableFoodItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCalories = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.calories,
    );
    final totalProtein = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.proteinGrams,
    );
    final totalCarbs = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.carbsGrams,
    );
    final totalFat = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.fatGrams,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
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
                  'How Much To Eat',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Food items with serving recommendations
          ..._editableFoodItems.map((food) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildServingRecommendation(food),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildNutrientInfo(
                              'Calories',
                              '${food.calories.toInt()} kcal',
                              Colors.orange,
                            ),
                            _buildNutrientInfo(
                              'Protein',
                              '${food.proteinGrams.toInt()}g',
                              Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildNutrientInfo(
                              'Carbs',
                              '${food.carbsGrams.toInt()}g',
                              Colors.blue,
                            ),
                            _buildNutrientInfo(
                              'Fat',
                              '${food.fatGrams.toInt()}g',
                              Colors.amber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          // Total summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Meal Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.purple,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNutrientInfo(
                      'Total Calories',
                      '${totalCalories.toInt()} kcal',
                      Colors.orange,
                    ),
                    _buildNutrientInfo(
                      'Total Protein',
                      '${totalProtein.toInt()}g',
                      Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNutrientInfo(
                      'Total Carbs',
                      '${totalCarbs.toInt()}g',
                      Colors.blue,
                    ),
                    _buildNutrientInfo(
                      'Total Fat',
                      '${totalFat.toInt()}g',
                      Colors.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingRecommendation(FoodItemNutrition food) {
    // Generate human-readable serving size
    final servingSize = food.servingGrams;
    String servingText = _getHumanReadableServing(food.name, servingSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              servingText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.green[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHumanReadableServing(String foodName, double grams) {
    // Common food serving sizes in human-readable format
    final lowerName = foodName.toLowerCase();

    if (lowerName.contains('rice') ||
        lowerName.contains('pasta') ||
        lowerName.contains('oats')) {
      final cups = (grams / 150).toStringAsFixed(1);
      return '${cups} cups of cooked ${foodName}';
    }

    if (lowerName.contains('bread') || lowerName.contains('toast')) {
      final slices = (grams / 30).round();
      return '${slices} slice${slices != 1 ? 's' : ''} of ${foodName}';
    }

    if (lowerName.contains('chicken') ||
        lowerName.contains('beef') ||
        lowerName.contains('fish') ||
        lowerName.contains('meat')) {
      final oz = (grams / 28).toStringAsFixed(1);
      return '${oz} oz (about palm-sized portion) of ${foodName}';
    }

    if (lowerName.contains('apple') ||
        lowerName.contains('orange') ||
        lowerName.contains('banana')) {
      return '${grams.toInt()}g (about ${_fruitSize(grams)} fruit) of ${foodName}';
    }

    if (lowerName.contains('vegetable') ||
        lowerName.contains('broccoli') ||
        lowerName.contains('carrot') ||
        lowerName.contains('spinach')) {
      final cups = (grams / 100).toStringAsFixed(1);
      return '${cups} cups (about fist-sized portions) of ${foodName}';
    }

    if (lowerName.contains('yogurt') || lowerName.contains('milk')) {
      final cups = (grams / 240).toStringAsFixed(1);
      return '${cups} cups of ${foodName}';
    }

    if (lowerName.contains('cheese')) {
      final oz = (grams / 28).toStringAsFixed(1);
      return '${oz} oz (about thumb-sized) of ${foodName}';
    }

    if (lowerName.contains('nut') ||
        lowerName.contains('almond') ||
        lowerName.contains('peanut')) {
      return '${grams.toInt()}g (about handful) of ${foodName}';
    }

    if (lowerName.contains('egg')) {
      final eggs = (grams / 50).round();
      return '${eggs} egg${eggs != 1 ? 's' : ''} (${grams.toInt()}g)';
    }

    // Default serving format
    return '${grams.toInt()}g of ${foodName}';
  }

  String _fruitSize(double grams) {
    if (grams < 150) return 'small';
    if (grams < 250) return 'medium';
    return 'large';
  }

  Widget _buildNutrientInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 9,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMealInsights() {
    if (_editableFoodItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCalories = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.calories,
    );
    final totalCarbs = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.carbsGrams,
    );
    final totalProtein = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.proteinGrams,
    );
    final totalFat = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.fatGrams,
    );
    final totalFiber = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.fiberGrams,
    );
    final netCarbs = (totalCarbs - totalFiber).clamp(0.0, double.infinity);

    final totalMacros = totalCarbs + totalProtein + totalFat;
    final carbRatio = totalMacros > 0 ? (totalCarbs / totalMacros * 100) : 0.0;
    final proteinRatio = totalMacros > 0
        ? (totalProtein / totalMacros * 100)
        : 0.0;
    final fatRatio = totalMacros > 0 ? (totalFat / totalMacros * 100) : 0.0;

    // Nutritional scoring based on multiple factors
    int score = 0;
    if (proteinRatio >= 20) score += 20;
    if (totalFiber >= 5) score += 20;
    if (carbRatio <= 50) score += 20;
    if (totalCalories >= 200 && totalCalories <= 800) score += 20;
    if (fatRatio >= 20 && fatRatio <= 40) score += 20;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getScoreColor(score).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getScoreColor(score).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: _getScoreColor(score),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition Score: $score/100',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _getScoreColor(score),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMealAdvice(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Show detailed recommendation button if available
              if (_clinicalRecommendation != null)
                InkWell(
                  onTap: _showClinicalRecommendationDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Icon(
                          Icons.health_and_safety,
                          color: Colors.purple.shade600,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Macro ratio bars
          _buildMacroRatioBars(carbRatio, proteinRatio, fatRatio),
          const SizedBox(height: 12),

          // Key metrics
          _buildKeyMetrics(totalFiber, totalCalories, netCarbs),
        ],
      ),
    );
  }

  Widget _buildMacroRatioBars(double carbs, double protein, double fat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Macro Balance',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: carbs.toInt(),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    bottomLeft: Radius.circular(3),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: protein.toInt(),
              child: Container(height: 6, color: const Color(0xFF10B981)),
            ),
            Expanded(
              flex: fat.toInt(),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMacroLabel(
              'Carbs',
              carbs.toStringAsFixed(0),
              const Color(0xFF3B82F6),
            ),
            _buildMacroLabel(
              'Protein',
              protein.toStringAsFixed(0),
              const Color(0xFF10B981),
            ),
            _buildMacroLabel(
              'Fat',
              fat.toStringAsFixed(0),
              const Color(0xFFF59E0B),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroLabel(String label, String percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMetrics(double fiber, double calories, double netCarbs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricTile(
                'Fiber',
                '${fiber.toStringAsFixed(1)}g',
                fiber >= 5 ? Colors.green : Colors.orange,
              ),
              _buildMetricTile(
                'Net Carbs',
                '${netCarbs.toStringAsFixed(0)}g',
                netCarbs <= 30 ? Colors.green : Colors.red,
              ),
              _buildMetricTile(
                'Calories',
                calories.toStringAsFixed(0),
                calories >= 200 && calories <= 800
                    ? Colors.green
                    : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color statusColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getMealAdvice() {
    if (_editableFoodItems.isEmpty) return 'No advice available';

    // Use clinical nutrition advisor for personalized recommendations
    if (_clinicalRecommendation != null) {
      // Combine clinical summary with top flag if present
      final summary = _clinicalRecommendation!.summary;
      if (_clinicalRecommendation!.flags.isNotEmpty) {
        final topFlag = _clinicalRecommendation!.flags.first;
        final icon = topFlag.severity == 'critical' ? '🚨' : 
                     topFlag.severity == 'warning' ? '⚠️' : 'ℹ️';
        return '$icon ${topFlag.message}';
      }
      return summary;
    }

    // Fallback to basic analysis if clinical recommendation not available
    final totalCalories = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.calories,
    );
    final totalCarbs = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.carbsGrams,
    );
    final totalProtein = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.proteinGrams,
    );
    final totalFat = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.fatGrams,
    );
    final totalFiber = _editableFoodItems.fold<double>(
      0,
      (sum, item) => sum + item.fiberGrams,
    );

    final totalMacros = totalCarbs + totalProtein + totalFat;
    final proteinRatio = totalMacros > 0
        ? (totalProtein / totalMacros * 100)
        : 0;

    final List<String> insights = [];

    // Fiber assessment
    if (totalFiber < 3 && totalCarbs > 50) {
      insights.add('⚠️ Low fiber—add vegetables or whole grains');
    } else if (totalFiber >= 5) {
      insights.add('✓ Excellent fiber—sustained energy');
    }

    // Protein assessment
    if (proteinRatio < 15 && totalCalories > 300) {
      insights.add('⚠️ Low protein—add lean meat, eggs, or legumes');
    } else if (proteinRatio >= 25) {
      insights.add('✓ Strong protein—supports muscle and fullness');
    }

    // Glycemic load
    if (totalCarbs > 0 &&
        (totalCarbs / (totalFiber + 0.1)) > 10 &&
        (totalCarbs - totalFiber) > 30) {
      insights.add('🔥 High glycemic load—blood sugar will spike');
    } else if (totalFiber > (totalCarbs * 0.2)) {
      insights.add('✓ Good carb quality—slow energy release');
    }

    // Calorie assessment
    if (totalCalories > 800) {
      insights.add('📊 Large meal—great for post-workout recovery');
    } else if (totalCalories < 200) {
      insights.add('🍗 Light meal—pair with snack later');
    }

    if (insights.isEmpty) {
      return 'Balanced meal with good macro distribution';
    }

    return insights.take(2).join(' · ');
  }

  /// Generate personalized clinical nutrition recommendations based on user profile
  void _generateClinicalRecommendation() {
    if (_editableFoodItems.isEmpty) {
      setState(() => _clinicalRecommendation = null);
      return;
    }

    try {
      final userProfile = context.read<UserProfileProvider>().userProfile;
      
      final recommendation = _clinicalAdvisor.generateRecommendation(
        profile: userProfile,
        scannedFoods: _editableFoodItems,
      );
      
      setState(() => _clinicalRecommendation = recommendation);
      
      // Debug output (optional - can be removed in production)
      debugPrint('Clinical Recommendation Generated:');
      debugPrint('Summary: ${recommendation.summary}');
      debugPrint('Flags: ${recommendation.flags.length}');
      debugPrint('Refer to Professional: ${recommendation.referToProfessional}');
    } catch (e) {
      debugPrint('Error generating clinical recommendation: $e');
      setState(() => _clinicalRecommendation = null);
    }
  }

  /// Show detailed clinical nutrition recommendations in a dialog
  void _showClinicalRecommendationDialog() {
    if (_clinicalRecommendation == null) return;

    final rec = _clinicalRecommendation!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade600, Colors.purple.shade400],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Clinical Nutrition Advice',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary
                      Text(
                        rec.summary,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 20),

                      // Critical flags first
                      if (rec.flags.isNotEmpty) ...[
                        ...rec.flags.map((flag) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: flag.severity == 'critical'
                                ? Colors.red.shade50
                                : flag.severity == 'warning'
                                    ? Colors.orange.shade50
                                    : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: flag.severity == 'critical'
                                  ? Colors.red.shade300
                                  : flag.severity == 'warning'
                                      ? Colors.orange.shade300
                                      : Colors.blue.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                flag.severity == 'critical'
                                    ? Icons.warning
                                    : flag.severity == 'warning'
                                        ? Icons.warning_amber
                                        : Icons.info,
                                color: flag.severity == 'critical'
                                    ? Colors.red.shade700
                                    : flag.severity == 'warning'
                                        ? Colors.orange.shade700
                                        : Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  flag.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: flag.severity == 'critical'
                                        ? Colors.red.shade900
                                        : flag.severity == 'warning'
                                            ? Colors.orange.shade900
                                            : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Eat More
                      if (rec.eatMore.isNotEmpty) ...[
                        const Text(
                          '✅ Foods to Prioritize',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rec.eatMore.map((food) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ${food.food}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '  ${food.reason}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '  Serving: ${food.serving}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Eat Less
                      if (rec.eatLess.isNotEmpty) ...[
                        const Text(
                          '⚠️ Foods to Limit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rec.eatLess.map((food) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ${food.food}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '  ${food.reason}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Avoid Strictly
                      if (rec.avoidStrictly.isNotEmpty) ...[
                        const Text(
                          '🚫 Strictly Avoid',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rec.avoidStrictly.map((food) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• $food',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Daily Targets
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🎯 Your Daily Targets',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Calories: ${rec.caloricTarget.dailyKcal} kcal',
                                style: const TextStyle(fontSize: 14)),
                            Text('Protein: ${rec.macros.proteinG}g',
                                style: const TextStyle(fontSize: 14)),
                            Text('Carbs: ${rec.macros.carbsG}g',
                                style: const TextStyle(fontSize: 14)),
                            Text('Fat: ${rec.macros.fatG}g',
                                style: const TextStyle(fontSize: 14)),
                            Text('Fiber: ${rec.macros.fiberG}g',
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(
                              rec.caloricTarget.note,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Meal Timing
                      if (rec.mealTiming.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 20, color: Colors.purple),
                            const SizedBox(width: 8),
                            const Text(
                              'Meal Timing: ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(rec.mealTiming, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 16),
                      ],

                      // Micronutrients
                      if (rec.micronutrientWatch.isNotEmpty) ...[
                        const Text(
                          '💊 Micronutrient Watch',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rec.micronutrientWatch.map((micro) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ${micro.nutrient}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '  ${micro.action}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Professional referral warning
                      if (rec.referToProfessional) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_hospital, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Please consult your healthcare provider for personalized guidance based on your medical conditions.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Disclaimer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          rec.disclaimer,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981); // Green - Excellent
    if (score >= 60) return const Color(0xFF3B82F6); // Blue - Good
    if (score >= 40) return const Color(0xFFF59E0B); // Amber - Fair
    return const Color(0xFFEF4444); // Red - Needs improvement
  }

  void _showFoodEditDialog(FoodItemNutrition food, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Food Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Food Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                controller: TextEditingController(text: food.name),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Calories (kcal)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                controller: TextEditingController(
                  text: food.calories.toStringAsFixed(0),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBadge(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // Action Helpers
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Meal Type Selector
        _buildMealTypeSelector(),
        const SizedBox(height: 12),
        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (_safetyPassed && !_isLogging) ? () => _logMeal(_selectedMealType) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLogging
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Log as ${_selectedMealType[0].toUpperCase()}${_selectedMealType.substring(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _resetScanner,
              icon: const Icon(Icons.refresh, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMealTypeSelector() {
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealIcons = {
      'breakfast': Icons.free_breakfast_rounded,
      'lunch': Icons.lunch_dining_rounded,
      'dinner': Icons.dinner_dining_rounded,
      'snack': Icons.icecream_rounded,
    };
    final mealColors = {
      'breakfast': const Color(0xFFFF9800),
      'lunch': const Color(0xFF4CAF50),
      'dinner': const Color(0xFF9C27B0),
      'snack': const Color(0xFF2196F3),
    };
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: mealTypes.map((type) {
          final isSelected = _selectedMealType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedMealType = type);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? mealColors[type] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [BoxShadow(color: mealColors[type]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mealIcons[type],
                      size: 20,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type[0].toUpperCase() + type.substring(1),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _logMeal(String mealType) async {
    if (_editableFoodItems.isEmpty || _isLogging) return;

    setState(() => _isLogging = true);

    // Check connectivity before logging
    if (await _isOffline()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'re offline. Please connect to the internet to log your meal.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        setState(() => _isLogging = false);
      }
      return;
    }

    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLogging = false);
        }
        return;
      }

      // Save meal to Firestore
      final firestore = FirebaseFirestore.instance;
      final dateKey = _generateDateKey(DateTime.now());
      final mealsRef = firestore
          .collection('daily_nutrition')
          .doc(user.uid)
          .collection('days')
          .doc(dateKey)
          .collection('meals');

      // Create meal document with sodium tracking
      final totalSodium = _editableFoodItems.fold<double>(
        0,
        (total, item) {
          // Estimate sodium if not available: ~400mg per 100g of food as baseline
          final estimatedSodiumPerItem = (item.servingGrams / 100) * 150; // Conservative estimate
          return total + estimatedSodiumPerItem;
        },
      );
      
      final mealData = {
        'mealType': mealType,
        'timestamp': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
        'foodItems': _editableFoodItems
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
        'totalCalories': _editableFoodItems.fold<double>(
          0,
          (total, item) => total + item.calories,
        ),
        'totalProtein': _editableFoodItems.fold<double>(
          0,
          (total, item) => total + item.proteinGrams,
        ),
        'totalCarbs': _editableFoodItems.fold<double>(
          0,
          (total, item) => total + item.carbsGrams,
        ),
        'totalFat': _editableFoodItems.fold<double>(
          0,
          (total, item) => total + item.fatGrams,
        ),
        'totalFiber': _editableFoodItems.fold<double>(
          0,
          (total, item) => total + item.fiberGrams,
        ),
        'totalSodium': totalSodium,
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
          ((dayData['totalCalories'] ?? dayData['total_calories'] ?? 0.0) as num) +
          (mealData['totalCalories'] as num);
      final totalProtein =
          ((dayData['totalProtein'] ?? dayData['total_protein'] ?? 0.0) as num) +
          (mealData['totalProtein'] as num);
      final totalCarbs =
          ((dayData['totalCarbs'] ?? dayData['total_carbs'] ?? 0.0) as num) +
          (mealData['totalCarbs'] as num);
      final totalFat =
          ((dayData['totalFat'] ?? dayData['total_fat'] ?? 0.0) as num) + (mealData['totalFat'] as num);
      final totalFiber =
          ((dayData['totalFiber'] ?? dayData['total_fiber'] ?? 0.0) as num) +
          (mealData['totalFiber'] as num);
      final totalSodiumDay =
          ((dayData['totalSodium'] ?? dayData['total_sodium'] ?? 0.0) as num) +
          (mealData['totalSodium'] as num);

      // Store with both field name conventions for compatibility
      await dayRef.set({
        'date': FieldValue.serverTimestamp(),
        'userId': user.uid,
        // camelCase (for DailyNutritionTracker compatibility)
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'totalCarbs': totalCarbs,
        'totalFat': totalFat,
        'totalFiber': totalFiber,
        'totalSodium': totalSodiumDay,
        // snake_case (for DailyNutritionTracker.fromMap compatibility)
        'total_calories': totalCalories,
        'total_protein': totalProtein,
        'total_carbs': totalCarbs,
        'total_fat': totalFat,
        'total_fiber': totalFiber,
        'total_sodium': totalSodiumDay,
        'mealsLogged': ((dayData['mealsLogged'] ?? dayData['meals_logged'] ?? dayData['mealCount'] ?? 0) as num).toInt() + 1,
        'meals_logged': ((dayData['mealsLogged'] ?? dayData['meals_logged'] ?? dayData['mealCount'] ?? 0) as num).toInt() + 1,
      }, SetOptions(merge: true));

      // Update nutrition goals provider to refresh UI
      if (mounted) {
        // ignore: use_build_context_synchronously
        final nutritionProvider = context.read<NutritionGoalsProvider>();
        await nutritionProvider.loadTodayNutrition();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_editableFoodItems.length} food item(s) logged successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Reset scanner to allow logging another meal
        await Future.delayed(const Duration(milliseconds: 800));
        _resetScanner();
      }
    } catch (e) {
      debugPrint('Error logging meal: $e');
      if (mounted) {
        final message = _isNetworkError(e)
            ? 'You\'re offline. Please connect to the internet to log your meal.'
            : 'Something went wrong while logging your meal. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _isNetworkError(e) ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  String _generateDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================
  // UI BUILDER METHODS
  // ============================================

  /// Build scanning reticle for food detection
  Widget _buildScanningReticle() {
    return Center(
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.greenAccent, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            CustomPaint(
              painter: NeuralThreadPainter(
                bubblePositions: _liveDetections
                    .map((d) => d.boundingBox.center)
                    .toList(),
                hubPosition: const Offset(140, 140),
                pulseValue: 0.5,
              ),
            ),
            // Corner brackets from second code
            ..._buildCorners(),
          ],
        ),
      ),
    );
  }

  /// Build corner brackets - FROM SECOND CODE
  List<Widget> _buildCorners() {
    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF4CAF50), width: 4),
              left: BorderSide(color: Color(0xFF4CAF50), width: 4),
            ),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF4CAF50), width: 4),
              right: BorderSide(color: Color(0xFF4CAF50), width: 4),
            ),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF4CAF50), width: 4),
              left: BorderSide(color: Color(0xFF4CAF50), width: 4),
            ),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF4CAF50), width: 4),
              right: BorderSide(color: Color(0xFF4CAF50), width: 4),
            ),
          ),
        ),
      ),
    ];
  }

  /// Build flash toggle button
  Widget _buildFlashToggle() {
    return Positioned(
      bottom: 100,
      right: 20,
      child: FloatingActionButton(
        mini: true,
        onPressed: () => _toggleFlash(),
        backgroundColor: Colors.grey[700],
        child: Icon(
          _isFlashOn ? Icons.flash_off : Icons.flash_on,
          color: Colors.yellowAccent,
        ),
      ),
    );
  }

  /// Build processing overlay
  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      ),
    );
  }

  /// Build food item cards
  Widget _buildFoodItemCards() {
    if (_editableFoodItems.isEmpty) {
      return const Center(child: Text('No food items detected'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _editableFoodItems.length,
      itemBuilder: (context, index) {
        final item = _editableFoodItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(Icons.restaurant_menu, color: Colors.green[700]),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${item.calories.toInt()} cal • ${item.servingGrams.toInt()}g',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNutrientChip(
                    'Protein',
                    '${item.proteinGrams.toInt()}g',
                    Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _buildNutrientChip(
                    'Carbs',
                    '${item.carbsGrams.toInt()}g',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildNutrientChip(
                    'Fat',
                    '${item.fatGrams.toInt()}g',
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildNutrientChip(
                    'Fiber',
                    '${item.fiberGrams.toInt()}g',
                    Colors.green,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutrientChip(String label, String value, [Color? color]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color ?? Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Neural Forecast: AI prediction of meal impact
  Widget _buildNeuralForecast() {
    if (_editableFoodItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Consumer2<NutritionGoalsProvider, UserProfileProvider>(
      builder: (context, nutritionProvider, userProvider, _) {
        // Get user goals
        final userGoals = nutritionProvider.userGoals;
        final todayTracker = nutritionProvider.todayTracker;

        // Calculate totals from newly detected foods
        final newFoodCalories = _editableFoodItems.fold<double>(
          0,
          (sum, item) => sum + item.calories,
        );
        final newFoodProtein = _editableFoodItems.fold<double>(
          0,
          (sum, item) => sum + item.proteinGrams,
        );
        final newFoodCarbs = _editableFoodItems.fold<double>(
          0,
          (sum, item) => sum + item.carbsGrams,
        );
        final newFoodFat = _editableFoodItems.fold<double>(
          0,
          (sum, item) => sum + item.fatGrams,
        );

        // Get already consumed totals from today
        final consumedCalories = todayTracker?.totalCalories ?? 0.0;
        final consumedProtein = todayTracker?.totalProtein ?? 0.0;
        final consumedCarbs = todayTracker?.totalCarbs ?? 0.0;
        final consumedFat = todayTracker?.totalFat ?? 0.0;

        // Get goals (with sensible defaults)
        final calorieGoal = userGoals?.dailyCalorieGoal ?? 2000.0;
        final proteinGoal = userGoals?.proteinGoalGrams ?? 150.0;
        final carbsGoal = userGoals?.carbsGoalGrams ?? 200.0;
        final fatGoal = userGoals?.fatGoalGrams ?? 65.0;

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

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.indigo.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.indigo, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REMAINING CAPACITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.indigo,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'After this meal',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRemainingItem(
                    'Calories',
                    '${caloriesRemaining.toInt()} kcal',
                    Colors.orange,
                    Icons.local_fire_department,
                  ),
                  _buildRemainingItem(
                    'Protein',
                    '${proteinRemaining.toStringAsFixed(1)}g',
                    Colors.green,
                    Icons.fitness_center,
                  ),
                  _buildRemainingItem(
                    'Carbs',
                    '${carbsRemaining.toStringAsFixed(1)}g',
                    Colors.red,
                    Icons.grain,
                  ),
                  _buildRemainingItem(
                    'Fat',
                    '${fatRemaining.toStringAsFixed(1)}g',
                    Colors.amber,
                    Icons.opacity,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRemainingItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 70, maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
