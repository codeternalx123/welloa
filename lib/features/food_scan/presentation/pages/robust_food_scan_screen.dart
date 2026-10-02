import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/ai_trial_provider.dart';
import '../providers/food_scan_ddd_provider.dart';
import '../../../../shared/widgets/gamified_ai_coach_widget.dart';
import '../../../../shared/widgets/unicorn_glass_card.dart';
import '../../../../shared/widgets/animated_glow_border.dart';
import '../../../../shared/widgets/mesh_background.dart';

class RobustFoodScanScreen extends ConsumerStatefulWidget {
  const RobustFoodScanScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RobustFoodScanScreen> createState() => _RobustFoodScanScreenState();
}

class _RobustFoodScanScreenState extends ConsumerState<RobustFoodScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanAnimation;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _scanAnimation = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _cameraController = CameraController(
        cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first),
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _scanAnimation.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _triggerScan() async {
    final canUse = await ref.read(aiTrialProvider).canUseAIFeature(context, featureKey: 'nutrition');
    if (!canUse) return;

    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final profile = ref.read(profileProvider);
      ref.read(foodScanDDDNotifierProvider.notifier).analyzeRealImage(bytes, profile.age);
    } catch (e) {
      debugPrint('Error capturing picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodScanDDDNotifierProvider);

    final profile = ref.watch(profileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Real-Time Food Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: MeshBackground(
        tier: profile.tier,
        child: SafeArea(
          child: state.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Synthesizing Biological Impact...', style: TextStyle(color: Colors.grey)),
              Text('Gemini Perception -> Claude Reasoning', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
            child: AnimatedGlowBorder(
              glowColor: Colors.redAccent,
              child: UnicornGlassCard(
                padding: const EdgeInsets.all(24),
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text('Food Scan Failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 16),
                    _buildErrorDetailCard(err.toString()),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.2)),
                      onPressed: () => ref.read(foodScanDDDNotifierProvider.notifier).reset(),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
        data: (analysis) {
          if (analysis == null) {
            return GestureDetector(
              onTap: _triggerScan,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    CameraPreview(_cameraController!)
                  else
                    Container(color: Colors.black, child: const Center(child: CircularProgressIndicator())),
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: MediaQuery.of(context).size.height / 2 - 125 + (_scanAnimation.value * 250),
                        left: MediaQuery.of(context).size.width / 2 - 125,
                        child: Container(
                          width: 250,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent,
                            boxShadow: [
                              BoxShadow(color: Colors.cyanAccent, blurRadius: 10, spreadRadius: 2),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Icon(Icons.camera_alt, size: 48, color: Colors.cyanAccent),
                        SizedBox(height: 16),
                        Text(
                          'Point at meal and tap to scan',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final isPositive = analysis.biologicalAgeCostMinutes <= 0;
          final orbColor = isPositive ? Colors.greenAccent : Colors.redAccent;
          final impactStr = isPositive 
              ? '+${analysis.biologicalAgeCostMinutes.abs().toStringAsFixed(0)} Min'
              : '-${analysis.biologicalAgeCostMinutes.toStringAsFixed(0)} Min';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Gamified Impact Score
                Center(
                  child: AnimatedGlowBorder(
                    glowColor: orbColor,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: orbColor.withOpacity(0.5), width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(isPositive ? Icons.health_and_safety : Icons.warning_amber, size: 64, color: orbColor),
                          const SizedBox(height: 12),
                          Text(
                            isPositive ? 'Longevity Boost' : 'Biological Tax',
                            style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            impactStr,
                            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: orbColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. AI Question hook
                Text(
                  '💬 "${analysis.aiQuestion}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),

                // 3. Simplified Metrics
                Row(
                  children: [
                    Expanded(child: _buildGamifiedMetricCard((analysis as dynamic).metric1Label ?? 'Glucose', (analysis as dynamic).metric1Value ?? 'Normal', Colors.orangeAccent, Icons.timeline)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildGamifiedMetricCard((analysis as dynamic).metric2Label ?? 'Gut Health', (analysis as dynamic).metric2Value ?? 'Good', Colors.lightBlueAccent, Icons.bubble_chart)),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. Mission Goal
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.3)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amberAccent, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TODAY'S MISSION", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text(analysis.dailyGoal, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Actionable Tip
                UnicornGlassCard(
                  padding: const EdgeInsets.all(20),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.yellowAccent),
                          SizedBox(width: 8),
                          Text('AI Coach Insight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.yellowAccent)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        analysis.guidanceList.isNotEmpty ? analysis.guidanceList.first : 'Eat mindfully and chew well.',
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Chat Widget
                const GamifiedAICoachWidget(domainContext: 'Instant Meal Impact'),
                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('Scan Another Meal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ref.read(foodScanDDDNotifierProvider.notifier).reset();
                  },
                ),
              ],
            ),
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _buildGamifiedMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildErrorDetailCard(String errorString) {
    String errorType = 'API ERROR';
    String errorMessage = errorString;
    
    try {
      final jsonStartIndex = errorString.indexOf('{');
      if (jsonStartIndex != -1) {
        final jsonStr = errorString.substring(jsonStartIndex);
        final parsed = jsonDecode(jsonStr);
        if (parsed['error'] != null) {
          errorType = parsed['error']['type']?.toString().replaceAll('_', ' ').toUpperCase() ?? errorType;
          errorMessage = parsed['error']['message'] ?? errorMessage;
        }
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(errorType, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          Text(errorMessage, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
