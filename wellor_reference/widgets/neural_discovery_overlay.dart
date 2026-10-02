import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart'; // For 2026 Kinetic Spring Physics

/// UNICORN UX: The Spatial Synthesis Nexus.
/// Features: Inertial Dampening, Metabolic Triage HUD, and Neural Threading.
class NeuralDiscoveryOverlay extends StatelessWidget {
  final List<LiveObjectDetection> detections;
  final Size previewSize;

  const NeuralDiscoveryOverlay({
    super.key, 
    required this.detections, 
    required this.previewSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. NEURAL THREADS: Visualize the connection between food nodes
        CustomPaint(
          size: Size.infinite,
          painter: _NeuralThreadPainter(detections: detections, previewSize: previewSize),
        ),
        // 2. KINETIC NODES
        ...detections.map((obj) => _DiscoveryNode(
          detection: obj,
          previewSize: previewSize,
        )),
      ],
    );
  }
}

class _DiscoveryNode extends StatefulWidget {
  final LiveObjectDetection detection;
  final Size previewSize;

  const _DiscoveryNode({required this.detection, required this.previewSize});

  @override
  State<_DiscoveryNode> createState() => _DiscoveryNodeState();
}

class _DiscoveryNodeState extends State<_DiscoveryNode> with TickerProviderStateMixin {
  late AnimationController _springController;
  late SpringSimulation _springSim;
  
  // Coordinate Smoothing: LERP constants for 120Hz clinical fluidity
  double _smoothX = 0;
  double _smoothY = 0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(vsync: this, lowerBound: -double.infinity, upperBound: double.infinity);
    _initializeSpring();
  }

  void _initializeSpring() {
    // 2026 Lead Dev Note: Critically damped springs prevent visual "ringing" 
    // while maintaining a high-end physical feel.
    const springDescription = SpringDescription(mass: 1.0, stiffness: 500.0, damping: 25.0);
    _springSim = SpringSimulation(springDescription, 0, 1, 0);
    _springController.animateWith(_springSim);
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    
    // MATHEMATICAL MAPPING ENGINE
    // We map camera-space coordinates to the physical screen pixels:
    // $$x_{screen} = \frac{x_{cam}}{w_{preview}} \cdot w_{screen}$$
    // $$y_{screen} = \frac{y_{cam}}{h_{preview}} \cdot h_{screen}$$
    
    final targetX = (widget.detection.boundingBox.center.dx / widget.previewSize.width) * screen.width;
    final targetY = (widget.detection.boundingBox.center.dy / widget.previewSize.height) * screen.height;

    // Smoothed transition to target to eliminate camera "jitter"
    _smoothX = lerpDouble(_smoothX == 0 ? targetX : _smoothX, targetX, 0.15)!;
    _smoothY = lerpDouble(_smoothY == 0 ? targetY : _smoothY, targetY, 0.15)!;

    return Positioned(
      left: _smoothX - 20, // Offset for node center
      top: _smoothY - 20,
      child: ScaleTransition(
        scale: _springController.drive(CurveTween(curve: Curves.elasticOut)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildApertureNode(),
            const SizedBox(height: 12),
            _buildBiometricHUD(),
          ],
        ),
      ),
    );
  }

  Widget _buildApertureNode() {
    final color = _getMetabolicPriorityColor(widget.detection.label);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Center(
        child: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildBiometricHUD() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(
                widget.detection.label.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.amber, size: 10),
                  const SizedBox(width: 4),
                  Text(
                    '${(widget.detection.confidence * 100).toInt()}% SYNC',
                    style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMetabolicPriorityColor(String label) {
    // Lead UX Triage: Triage colors represent immediate metabolic impact
    final l = label.toLowerCase();
    if (l.contains('sugar') || l.contains('carb')) return const Color(0xFFFF5252);
    if (l.contains('protein') || l.contains('meat')) return const Color(0xFF448AFF);
    return const Color(0xFF69F0AE);
  }
}

class _NeuralThreadPainter extends CustomPainter {
  final List<LiveObjectDetection> detections;
  final Size previewSize;
  _NeuralThreadPainter({required this.detections, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.length < 2) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < detections.length - 1; i++) {
      final p1 = Offset(
        (detections[i].boundingBox.center.dx / previewSize.width) * size.width,
        (detections[i].boundingBox.center.dy / previewSize.height) * size.height,
      );
      final p2 = Offset(
        (detections[i+1].boundingBox.center.dx / previewSize.width) * size.width,
        (detections[i+1].boundingBox.center.dy / previewSize.height) * size.height,
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LiveObjectDetection {
  final String label;
  final Rect boundingBox;
  final double confidence;
  LiveObjectDetection({required this.label, required this.boundingBox, required this.confidence});
}