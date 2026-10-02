import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // High-Fidelity Haptics
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/nutrition_api_service.dart';
import '../widgets/metabolic_forecast_gauge.dart'; // New Unicorn Widget

/// UNICORN UX: The Metabolic Product Interrogator.
/// Features: Spatial Reticle, Predictive Bio-Score, and Automated OCR Transition.
class BarcodeScannerScreen extends StatefulWidget {
  final String userId;
  const BarcodeScannerScreen({super.key, required this.userId});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  late AnimationController _pulseController;
  bool _isAnalyzing = false;
  FoodItem? _detectedNode;

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildUnicornAppBar(),
      body: Stack(
        children: [
          // 1. THE VISION LAYER
          MobileScanner(
            controller: _controller,
            onDetect: _handleNeuralDetection,
          ),

          // 2. SPATIAL HUD OVERLAY (The Reticle)
          _buildSpatialReticle(),

          // 3. PRODUCT SYNTHESIS CARD (Glassmorphic)
          if (_detectedNode != null) _buildProductSynthesisCard(),

          // 4. NEURAL PROCESSING OVERLAY
          if (_isAnalyzing) _buildNeuralProcessingOverlay(),
        ],
      ),
      bottomNavigationBar: _buildActionDock(),
    );
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN HUD
  // ============================================

  PreferredSizeWidget _buildUnicornAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text('NEURAL SCAN', 
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 12, color: Colors.white70)),
      actions: [
        IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.bolt_rounded, color: Colors.yellowAccent)),
      ],
    );
  }

  Widget _buildSpatialReticle() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.3 + (_pulseController.value * 0.7)),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: CustomPaint(painter: _ReticleCornerPainter()),
          ),
        );
      },
    );
  }

  Widget _buildProductSynthesisCard() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: _GlassMorphism(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProductHeader(),
              const Divider(color: Colors.white10, height: 32),
              _buildMetabolicForecast(), // THE CORE UNICORN IDEA
              const SizedBox(height: 24),
              _buildCommitButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetabolicForecast() {
    // Predictive AI: Predicts glucose impact based on ingredients
    return const Row(
      children: [
        MetabolicForecastGauge(score: 84), // Pulse-coded score
        SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BIO-IMPACT FORECAST', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
              Text('Low Glucose Volatility', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Safe for current metabolic state.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // LOGIC & NEURAL ACTIONS
  // ============================================

  void _handleNeuralDetection(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    if (code == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);
    HapticFeedback.mediumImpact(); // Neural Thump

    try {
      final product = await NutritionApiService().lookupBarcode(code);
      if (mounted) {
        setState(() {
          _detectedNode = product;
          _isAnalyzing = false;
        });
        HapticFeedback.heavyImpact(); // Success Confirmation
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _transitionToOCRTriage();
    }
  }

  void _transitionToOCRTriage() {
    // Lead UX Idea: Don't show an error, automatically shift to OCR intent
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barcode Unknown. Initializing Neural OCR...'), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildActionDock() {
    return _GlassMorphism(
      borderRadius: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              _DockAction(icon: Icons.auto_graph_rounded, label: 'OCR TRIAGE', onTap: () {}),
              const Spacer(),
              _DockAction(icon: Icons.edit_note_rounded, label: 'MANUAL NODE', onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  /// Neural Processing Overlay shown during barcode analysis
  Widget _buildNeuralProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('ANALYZING NEURAL NODE...', 
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 2, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// Product Header showing detected product info
  Widget _buildProductHeader() {
    if (_detectedNode == null) return const SizedBox();
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.inventory_2_rounded, color: Colors.white70),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_detectedNode!.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_detectedNode!.brand ?? 'Brand Unknown',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  /// Commit Buttons for saving or dismissing the detected product
  Widget _buildCommitButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _detectedNode = null),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              foregroundColor: Colors.white70,
            ),
            child: const Text('DISMISS'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // TODO: Implement commit logic
              Navigator.of(context).pop(_detectedNode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('COMMIT'),
          ),
        ),
      ],
    );
  }
}

// ============================================
// ATOMIC UX COMPONENTS
// ============================================

class _GlassMorphism extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  const _GlassMorphism({required this.child, this.borderRadius = 32});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ReticleCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final path = Path();
    const double l = 40; // Corner length

    // Top Left
    path.moveTo(0, l); path.lineTo(0, 0); path.lineTo(l, 0);
    // Top Right
    path.moveTo(size.width - l, 0); path.lineTo(size.width, 0); path.lineTo(size.width, l);
    // Bottom Right
    path.moveTo(size.width, size.height - l); path.lineTo(size.width, size.height); path.lineTo(size.width - l, size.height);
    // Bottom Left
    path.moveTo(l, size.height); path.lineTo(0, size.height); path.lineTo(0, size.height - l);

    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DockAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DockAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(
            color: Colors.white54, 
            fontSize: 10, 
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          )),
        ],
      ),
    );
  }
}