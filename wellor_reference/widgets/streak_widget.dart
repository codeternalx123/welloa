import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import 'package:provider/provider.dart';
import '../providers/streak_provider.dart';

/// UNICORN UX: The Streak Nexus.
/// Features: Spatial Glassmorphism, Kinetic Mesh Aperture, and Neural Triage Labels.
class StreakWidget extends StatefulWidget {
  const StreakWidget({super.key});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fluidAperture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _fluidAperture = CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lead Logic: Context selection prevents unnecessary rebuilds of the entire subtree
    final streak = context.select<StreakProvider, int>((p) => p.streak);
    final milestone = _MilestoneEngine.getMilestone(streak);

    return MouseRegion(
      onEnter: (_) => HapticFeedback.selectionClick(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: milestone.gradient.first.withValues(alpha: 0.25),
              blurRadius: 40,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Stack(
              children: [
                // 1. KINETIC MESH BACKGROUND (The "Unicorn" Living Surface)
                _buildMetabolicMesh(milestone.gradient),

                // 2. SPATIAL CONTENT LAYER
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    children: [
                      _LivingAperture(icon: milestone.icon, progress: _fluidAperture),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'NEURAL STREAK',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              milestone.title.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              milestone.message,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _NexusCounter(streak: streak, color: milestone.gradient.first),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetabolicMesh(List<Color> gradient) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.6,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                gradient.first.withValues(alpha: 0.8),
                gradient.last.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- ATOMIC UNICORN COMPONENTS ---

class _LivingAperture extends StatelessWidget {
  final IconData icon;
  final Animation<double> progress;
  const _LivingAperture({required this.icon, required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 20 * progress.value,
                spreadRadius: 2,
              )
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3 + (0.2 * progress.value)),
              width: 2,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        );
      },
    );
  }
}

class _NexusCounter extends StatelessWidget {
  final int streak;
  final Color color;
  const _NexusCounter({required this.streak, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$streak',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 34,
            letterSpacing: -2,
          ),
        ),
        const Text(
          'DAYS',
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// --- INTERNAL LOGIC & MATH ---

class _MilestoneData {
  final String title, message;
  final List<Color> gradient;
  final IconData icon;
  _MilestoneData({required this.title, required this.message, required this.gradient, required this.icon});
}

class _MilestoneEngine {
  static _MilestoneData getMilestone(int streak) {
    if (streak >= 30) {
      return _MilestoneData(
        title: 'Legendary Status',
        message: 'Bio-rhythm synchronized perfectly for 30 cycles.',
        gradient: [const Color(0xFF6366F1), const Color(0xFFA855F7)], 
        icon: Icons.auto_awesome,
      );
    } else if (streak >= 7) {
      return _MilestoneData(
        title: 'Vanguard',
        message: 'Metabolic momentum is achieving peak stability.',
        gradient: [const Color(0xFFEC4899), const Color(0xFF8B5CF6)], 
        icon: Icons.shutter_speed_rounded,
      );
    }
    return _MilestoneData(
      title: 'Neural link',
      message: 'Log today to strengthen the loop — your streak is the backbone of accurate coaching.',
      gradient: [const Color(0xFF10B981), const Color(0xFF3B82F6)], 
      icon: Icons.hub_rounded,
    );
  }
}