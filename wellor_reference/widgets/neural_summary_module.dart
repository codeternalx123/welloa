import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Data class for metabolic insights
class MetabolicInsight {
  final String title;
  final String description;
  final IconData icon;

  const MetabolicInsight({
    required this.title,
    required this.description,
    required this.icon,
  });
}

// ============================================
// COMPONENT 1: NEURAL SUMMARY MODULE
// ============================================

/// UNICORN UX: AI-Generated Metabolic Insight Aggregator.
/// Features: Kinetic Shimmer, Neural Glow Canvas, and Staggered Node Entry.
class NeuralSummaryModule extends StatefulWidget {
  final List<MetabolicInsight> insights;

  const NeuralSummaryModule({super.key, required this.insights});

  @override
  State<NeuralSummaryModule> createState() => _NeuralSummaryModuleState();
}

class _NeuralSummaryModuleState extends State<NeuralSummaryModule> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.05 * _glowController.value),
                blurRadius: 40,
                spreadRadius: 10,
              )
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    ...widget.insights.asMap().entries.map((entry) {
                      return _buildStaggeredInsight(entry.key, entry.value);
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 18),
        SizedBox(width: 8),
        Text(
          'NEURAL TELEMETRY SUMMARY',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildStaggeredInsight(int index, MetabolicInsight insight) {
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(index * 0.2, 0.8, curve: Curves.easeOutQuart),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(insight.icon, color: const Color(0xFF34D399), size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.description,
                      style: const TextStyle(fontSize: 12, height: 1.5, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// COMPONENT 2: EXPERT VERIFICATION WRAPPER
// ============================================

/// UNICORN UX: The Expert Verification Ripple.
/// Features: Golden Gaussian Bloom, Radial Waveform, and Clinical Haptic Pulse.
class ExpertVerificationWrapper extends StatefulWidget {
  final Widget child;
  final bool isEndorsed;
  final VoidCallback? onEndorse;
  final bool isDietitian;

  const ExpertVerificationWrapper({
    super.key,
    required this.child,
    required this.isEndorsed,
    this.onEndorse,
    this.isDietitian = false,
  });

  @override
  State<ExpertVerificationWrapper> createState() => _ExpertVerificationWrapperState();
}

class _ExpertVerificationWrapperState extends State<ExpertVerificationWrapper> with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    if (widget.isEndorsed) {
      _rippleController.forward(from: 1.0);
    }
  }

  @override
  void didUpdateWidget(ExpertVerificationWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEndorsed && !oldWidget.isEndorsed) {
      _triggerVerificationSequence();
    }
  }

  void _triggerVerificationSequence() {
    HapticFeedback.heavyImpact(); // The "Clinical Thump"
    _rippleController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rippleController, _glowController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. RADIAL RIPPLE LAYER (The Wave)
            if (_rippleController.isAnimating || widget.isEndorsed)
              Positioned.fill(
                child: CustomPaint(
                  painter: _VerificationRipplePainter(
                    progress: _rippleController.value,
                  ),
                ),
              ),

            // 2. THE CONTENT FRAME
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: widget.isEndorsed
                      ? Colors.amber.withValues(alpha: 0.3 + (0.2 * _glowController.value))
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: widget.isEndorsed
                    ? [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.1 * _glowController.value),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ]
                    : [],
              ),
              child: widget.child,
            ),

            // 3. DIETITIAN ENDORSEMENT TRIGGER
            if (widget.isDietitian && !widget.isEndorsed)
              Positioned(
                top: 15,
                right: 15,
                child: _buildEndorseButton(),
              ),

            // 4. VERIFIED BADGE (High-Authority Micro-copy)
            if (widget.isEndorsed)
              Positioned(
                top: -12,
                right: 24,
                child: _buildVerifiedBadge(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEndorseButton() {
    return GestureDetector(
      onTap: widget.onEndorse,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
        child: const Icon(Icons.verified_rounded, color: Colors.black, size: 20),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return FadeTransition(
      opacity: _rippleController,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_rounded, size: 14, color: Colors.black),
            SizedBox(width: 6),
            Text(
              'CLINICALLY ENDORSED',
              style: TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationRipplePainter extends CustomPainter {
  final double progress;
  _VerificationRipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.amber.withValues(alpha: 1 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawCircle(center, (size.width / 1.4) * progress, paint);

    final bloomPaint = Paint()
      ..color = Colors.amber.withValues(alpha: (1 - progress) * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25.0);

    canvas.drawCircle(center, (size.width / 1.2) * progress, bloomPaint);
  }

  @override
  bool shouldRepaint(covariant _VerificationRipplePainter oldDelegate) => true;
}