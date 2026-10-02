import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Neural Haptics
import '../services/wearable_intelligence_hub.dart';

/// UNICORN UX: The Neural Metabolic Telemetry Nexus.
/// Features: Kinetic Biological Pulse, Spatial Glassmorphism, and Neural Triage.
class BiometricMirrorWidget extends StatefulWidget {
  const BiometricMirrorWidget({super.key});

  @override
  State<BiometricMirrorWidget> createState() => _BiometricMirrorWidgetState();
}

class _BiometricMirrorWidgetState extends State<BiometricMirrorWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // 1. BIOLOGICAL KINETICISM: A 'breathing' effect signifying live metabolic sync.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WearableIntelligenceHub>(
      builder: (context, hub, child) {
        final reading = hub.latestReading ?? 0.0;
        final triageColor = _getMetabolicTriageColor(reading);
        
        // Lead Dev Tip: Trigger a subtle haptic "Handshake" on new data packets
        if (reading > 0) HapticFeedback.lightImpact();

        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: triageColor.withValues(alpha: 0.12 * _glowAnimation.value),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: triageColor.withValues(alpha: 0.25 * _glowAnimation.value),
                        width: 1.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          triageColor.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildApertureHeader(hub, triageColor),
                        const SizedBox(height: 32),
                        _buildMainTelemetry(reading, hub.getTrendStatus(), triageColor),
                        const SizedBox(height: 32),
                        _buildDeviceAperture(hub),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================
  // COMPONENT: APERTURE HEADER (Sync Status)
  // ============================================
  Widget _buildApertureHeader(WearableIntelligenceHub hub, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NEURAL METABOLIC SYNC', 
              style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 9)),
            const SizedBox(height: 4),
            Text(hub.isAuthorized ? 'SYSTEM STABLE' : 'LINK DISRUPTED', 
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        _buildLivePulseIndicator(hub.isAuthorized, color),
      ],
    );
  }

  Widget _buildLivePulseIndicator(bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: isActive ? color : Colors.redAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(isActive ? 'LIVE' : 'OFFLINE', 
            style: TextStyle(color: isActive ? color : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: MAIN TELEMETRY (Data Hub)
  // ============================================
  Widget _buildMainTelemetry(double value, String trend, Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Orbitals
        SizedBox(
          width: 140, height: 140,
          child: CustomPaint(painter: _NexusOrbitalPainter(color: color, pulse: _glowAnimation.value)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value == 0.0 ? '--' : value.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -4,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('mg/dL', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(trend.toUpperCase(), 
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceAperture(WearableIntelligenceHub hub) {
    if (hub.activeDevices.isEmpty) return const SizedBox();
    final device = hub.activeDevices.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors_rounded, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text('${device.manufacturer.toUpperCase()} ${device.name.toUpperCase()}', 
            style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Spacer(),
          const Text('APERTURE SYNC ACTIVE', 
            style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Color _getMetabolicTriageColor(double value) {
    if (value == 0.0) return Colors.blueGrey;
    if (value < 70) return const Color(0xFFF59E0B); // Volatile Warning
    if (value > 140) return const Color(0xFFEF4444); // Acute Spike
    return const Color(0xFF10B981); // Stabilized Emerald
  }
}

// ============================================
// PAINTER: THE NEXUS ORBITAL
// ============================================
class _NexusOrbitalPainter extends CustomPainter {
  final Color color;
  final double pulse;
  _NexusOrbitalPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, (size.width / 2) * pulse, paint);
    
    final corePaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    
    canvas.drawCircle(center, (size.width / 3), corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}