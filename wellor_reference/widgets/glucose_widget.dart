import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glucose_provider.dart';

/// UNICORN UX: The Metabolic Telemetry Node.
/// Features: Spatial Glassmorphism, Kinetic Breathing HUD, and Neural Triage badging.
class GlucoseWidget extends StatefulWidget {
  const GlucoseWidget({super.key});

  @override
  State<GlucoseWidget> createState() => _GlucoseWidgetState();
}

class _GlucoseWidgetState extends State<GlucoseWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // 1. KINETIC BIOLOGY: Create a 'breathing' effect to signify live metabolic sync
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GlucoseProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GlucoseProvider>(
      builder: (context, provider, child) {
        final glucoseValue = provider.currentGlucose ?? 0.0;
        // Lead Dev Logic: Determine triage color based on clinical thresholds
        final Color triageColor = _getTriageColor(glucoseValue);

        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: triageColor.withValues(alpha: 0.1 * _glowAnimation.value),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: triageColor.withValues(alpha: 0.2 * _glowAnimation.value),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildApertureHeader(triageColor),
                        const SizedBox(height: 28),
                        _buildMainTelemetry(provider, triageColor),
                        const SizedBox(height: 20),
                        _buildClinicalGuidance(provider.advice, triageColor),
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
  // COMPONENT: APERTURE HEADER
  // ============================================
  Widget _buildApertureHeader(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('METABOLIC TELEMETRY', 
                  style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                Text('Live Neural Sync', 
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
              ],
            ),
          ],
        ),
        _buildLiveIndicator(color),
      ],
    );
  }

  Widget _buildLiveIndicator(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: MAIN TELEMETRY
  // ============================================
  Widget _buildMainTelemetry(GlucoseProvider provider, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          provider.currentGlucose?.toStringAsFixed(0) ?? '--',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: -3,
            height: 1,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('mg/dL', 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
        ),
        const Spacer(),
        _buildTrendIcon(provider.currentGlucose, color),
      ],
    );
  }

  Widget _buildTrendIcon(double? value, Color color) {
    return Container(
      height: 40, width: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.trending_flat_rounded, color: color), // Would be dynamic in prod
    );
  }

  // ============================================
  // COMPONENT: CLINICAL GUIDANCE
  // ============================================
  Widget _buildClinicalGuidance(String advice, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              advice.toUpperCase(),
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTriageColor(double value) {
    if (value == 0) return const Color(0xFF10B981);
    if (value > 160) return const Color(0xFFEF4444); // Spike
    if (value < 70) return const Color(0xFF3B82F6); // Low
    return const Color(0xFF10B981); // Stabilized
  }
}