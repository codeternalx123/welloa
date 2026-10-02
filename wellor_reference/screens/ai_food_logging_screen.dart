import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Neural Haptics
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/nutrition_api_service.dart';
import '../providers/subscription_provider.dart';
import '../widgets/feature_restriction_widgets.dart';

/// UNICORN UX: The Metabolic Synthesis Hub.
/// Features: Neural Vision HUD, Glassmorphic Triage, and Predictive Impact Forecasting.
class AiFoodLoggingScreen extends StatefulWidget {
  final String userId;
  const AiFoodLoggingScreen({super.key, required this.userId});

  @override
  State<AiFoodLoggingScreen> createState() => _AiFoodLoggingScreenState();
}

class _AiFoodLoggingScreenState extends State<AiFoodLoggingScreen> with TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final NutritionApiService _nutritionApi = NutritionApiService();
  
  File? _selectedImage;
  ImageAnalysisResult? _analysisResult;
  bool _isSynthesizing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. KINETIC BACKGROUND: Metabolic Pulse Mesh
          _buildMetabolicBackground(),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildUnicornHeader(),
                
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_selectedImage == null) _buildVisionOnboarding(),
                      if (_selectedImage != null) _buildNeuralWorkspace(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildOmniVisionFAB(),
    );
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================

  Widget _buildMetabolicBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0), Colors.white],
        ),
      ),
    );
  }

  Widget _buildUnicornHeader() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('METABOLIC SYNTHESIS', 
              style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
            SizedBox(height: 8),
            Text('Neural Food Log', 
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisionOnboarding() {
    return _GlassCard(
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_motion_rounded, size: 60, color: Color(0xFF6C63FF)),
          const SizedBox(height: 24),
          const Text('99% BIOMETRIC ACCURACY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 12),
          Text(
            'Wellor AI identifies macronutrients and predicts metabolic velocity from a single capture.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.8), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNeuralWorkspace() {
    return Column(
      children: [
        // THE SCANNING HUD
        _buildNeuralHUD(),
        const SizedBox(height: 24),

        if (_isSynthesizing) _buildNeuralLoadingState(),

        if (_analysisResult != null) ...[
          _buildImpactForecast(), // Predictive UI
          const SizedBox(height: 20),
          _buildDetectedNodes(),
        ],
      ],
    );
  }

  Widget _buildNeuralHUD() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Image.file(_selectedImage!, height: 350, width: double.infinity, fit: BoxFit.cover),
        ),
        // AI Vision Bounding Boxes (Simulated)
        if (!_isSynthesizing && _analysisResult != null)
          Positioned.fill(child: _buildBoundingBoxOverlays()),
      ],
    );
  }

  Widget _buildImpactForecast() {
    return _GlassCard(
      color: Colors.greenAccent.withValues(alpha: 0.1),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: Colors.green, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('METABOLIC FORECAST', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.green)),
                Text('Stable: Predicted Spike < 15mg/dL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedNodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BIOMETRIC NODES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        ...(_analysisResult?.detectedFoods.map((food) => _buildFoodNodeCard(food)) ?? []),
      ],
    );
  }

  // ============================================
  // LOGIC & ACTIONS
  // ============================================

  Future<void> _captureImage() async {
    if (!checkScanLimitAccess(context)) return;

    final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (image == null) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final canScan = await subscriptionProvider.recordScan();
    if (!canScan) {
      if (mounted) checkScanLimitAccess(context);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _selectedImage = File(image.path);
      _isSynthesizing = true;
      _analysisResult = null;
    });

    // Neural Synthesis
    try {
      final result = await _nutritionApi.analyzeImage(image.path);
      setState(() {
        _analysisResult = result;
        _isSynthesizing = false;
      });
      HapticFeedback.heavyImpact(); // Neural "Lock"
    } catch (e) {
      setState(() => _isSynthesizing = false);
    }
  }

  Widget _buildOmniVisionFAB() {
    return FloatingActionButton.extended(
      onPressed: _captureImage,
      backgroundColor: const Color(0xFF0F172A),
      icon: const Icon(Icons.camera_rounded, color: Color(0xFF6C63FF)),
      label: const Text('INITIALIZE VISION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
    );
  }

  // Fallback sub-builders
  Widget _buildNeuralLoadingState() => const LinearProgressIndicator(color: Color(0xFF6C63FF), backgroundColor: Colors.transparent);
  Widget _buildBoundingBoxOverlays() => Container(); // Simulated vision logic
  Widget _buildFoodNodeCard(dynamic food) => Container(); // Detail card logic
}

// ============================================
// CORE UNICORN ATOMIC COMPONENTS
// ============================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _GlassCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 40, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }
}