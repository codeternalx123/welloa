import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glucose_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/glucose_service.dart';
import '../widgets/feature_restriction_widgets.dart';

/// UNICORN UX: Immersive Metabolic Command Center.
/// Features: Frosted Glass UI, Kinetic Pulse Scanner, and Semantic Glow States.
class WearableDevicesScreen extends StatefulWidget {
  const WearableDevicesScreen({super.key});

  @override
  State<WearableDevicesScreen> createState() => _WearableDevicesScreenState();
}

class _WearableDevicesScreenState extends State<WearableDevicesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check subscription access for wearable features
      final subProvider = context.read<SubscriptionProvider>();
      _hasAccess = subProvider.canAccessWearableSync;
      
      if (_hasAccess) {
        context.read<GlucoseProvider>().scanForConnectedDevices();
      }
    });
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
      appBar: AppBar(
        title: const Text('Device Nexus', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. PREMIUM BACKGROUND: Deep Kinetic Gradient
          _buildMetabolicBackground(),

          // Check subscription access
          Consumer<SubscriptionProvider>(
            builder: (context, subProvider, child) {
              if (subProvider.isFree) {
                return _buildPremiumRequiredOverlay();
              }
              
              return Consumer<GlucoseProvider>(
                builder: (context, provider, child) {
                  return SafeArea(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // 2. HERO SCANNER: The "Neural Radar"
                        SliverToBoxAdapter(
                          child: _buildNeuralScanner(provider),
                        ),

                        // 3. DEVICE LIST: Semantic Cards
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: provider.connectedDevices.isEmpty 
                            ? SliverToBoxAdapter(child: _buildUnicornEmptyState())
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildGlassDeviceCard(provider.connectedDevices[index]),
                                  childCount: provider.connectedDevices.length,
                                ),
                              ),
                        ),

                        // 4. ECOSYSTEM INTELLIGENCE FOOTER
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        SliverToBoxAdapter(child: _buildIntelligenceFooter()),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildPremiumRequiredOverlay() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.watch_rounded, color: Colors.greenAccent, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'WEARABLE SYNC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect Apple Watch, Fitbit, Garmin, and CGM devices to track your health data in real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              const UpgradeButton(text: 'UNLOCK WEARABLE SYNC'),
            ],
          ),
        ),
      ),
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
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)],
        ),
      ),
      child: Stack(
        children: [
          // Subtle Ambient Glows
          Positioned(top: -100, right: -50, child: _AmbientGlow(color: Colors.greenAccent.withValues(alpha: 0.1), size: 300)),
          Positioned(bottom: 100, left: -50, child: _AmbientGlow(color: Colors.blueAccent.withValues(alpha: 0.1), size: 400)),
        ],
      ),
    );
  }

  Widget _buildNeuralScanner(GlucoseProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Pulse Rings
              if (provider.isCheckingDevices)
                ...List.generate(3, (index) => AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final progress = (_pulseController.value + (index * 0.33)) % 1.0;
                    return Container(
                      width: 100 + (progress * 150),
                      height: 100 + (progress * 150),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 1 - progress), width: 2),
                      ),
                    );
                  },
                )),
              
              // Central Core
              GestureDetector(
                onTap: () => provider.scanForConnectedDevices(),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: provider.isCheckingDevices ? Colors.greenAccent : Colors.white10,
                    boxShadow: [
                      BoxShadow(
                        color: (provider.isCheckingDevices ? Colors.greenAccent : Colors.white24).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    provider.isCheckingDevices ? Icons.sensors : Icons.refresh_rounded,
                    size: 40,
                    color: provider.isCheckingDevices ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            provider.isCheckingDevices ? 'SYNCHRONIZING BIO-ARRAY...' : 'ECOSYSTEM STABLE',
            style: TextStyle(
              color: provider.isCheckingDevices ? Colors.greenAccent : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassDeviceCard(ConnectedDevice device) {
    final bool isCGM = device.type == 'cgm';
    final Color accentColor = isCGM ? Colors.blueAccent : Colors.purpleAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                colors: [accentColor.withValues(alpha: 0.1), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                _buildDeviceAvatar(device, accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(device.manufacturer.toUpperCase(), 
                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
                _StatusBadge(isActive: device.isActive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceAvatar(ConnectedDevice device, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        device.type == 'cgm' ? Icons.radar : Icons.watch_rounded,
        color: color,
        size: 28,
      ),
    );
  }

  Widget _buildUnicornEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.blur_on_rounded, size: 64, color: Colors.white24),
          SizedBox(height: 20),
          Text('No Biological Uplink', 
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('Connect your CGM or Smartwatch to begin real-time metabolic streaming.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildIntelligenceFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Opacity(
        opacity: 0.5,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_rounded, color: Colors.greenAccent, size: 14),
            SizedBox(width: 8),
            Text('End-to-End Encrypted Clinical Sync', 
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SUPPORTING UI WIDGETS
// ============================================

class _AmbientGlow extends StatelessWidget {
  final Color color;
  final double size;
  const _AmbientGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: size / 2, spreadRadius: size / 4)],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.orangeAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.greenAccent : Colors.orangeAccent)),
          const SizedBox(width: 6),
          Text(isActive ? 'LIVE' : 'IDLE', 
            style: TextStyle(color: isActive ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}