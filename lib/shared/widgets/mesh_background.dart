import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/providers/profile_provider.dart';

class MeshBackground extends StatefulWidget {
  final Widget child;
  final SubscriptionTier tier;

  const MeshBackground({
    Key? key,
    required this.child,
    required this.tier,
  }) : super(key: key);

  @override
  State<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<MeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color1;
    Color color2;
    Color color3;

    switch (widget.tier) {
      case SubscriptionTier.ultra:
        color1 = const Color(0xFF9D4EDD); // Purple
        color2 = const Color(0xFFFF006E); // Pink
        color3 = const Color(0xFF3A0CA3); // Deep Blue
        break;
      case SubscriptionTier.premium:
        color1 = const Color(0xFFFFBE0B); // Amber
        color2 = const Color(0xFFFB5607); // Orange
        color3 = const Color(0xFFFF006E); // Pink
        break;
      case SubscriptionTier.freemium:
      default:
        color1 = const Color(0xFF00B4D8); // Cyan
        color2 = const Color(0xFF4361EE); // Indigo
        color3 = const Color(0xFF4CC9F0); // Light Blue
        break;
    }

    return Stack(
      children: [
        // Base dark background
        Container(
          color: const Color(0xFF0F172A),
        ),
        // Animated Mesh Orbs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _MeshPainter(
                progress: _controller.value,
                color1: color1,
                color2: color2,
                color3: color3,
              ),
              child: Container(),
            );
          },
        ),
        // Heavy Blur to create the mesh effect
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
          child: Container(
            color: Colors.transparent,
          ),
        ),
        // The actual content
        widget.child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;
  final Color color3;

  _MeshPainter({
    required this.progress,
    required this.color1,
    required this.color2,
    required this.color3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = color1.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    
    final paint2 = Paint()
      ..color = color2.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
      
    final paint3 = Paint()
      ..color = color3.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    // Orb 1
    final double x1 = size.width * 0.5 + cos(progress * 2 * pi) * size.width * 0.3;
    final double y1 = size.height * 0.3 + sin(progress * 2 * pi) * size.height * 0.2;
    canvas.drawCircle(Offset(x1, y1), size.width * 0.6, paint1);

    // Orb 2
    final double x2 = size.width * 0.5 + cos((progress + 0.33) * 2 * pi) * size.width * 0.4;
    final double y2 = size.height * 0.7 + sin((progress + 0.33) * 2 * pi) * size.height * 0.3;
    canvas.drawCircle(Offset(x2, y2), size.width * 0.5, paint2);

    // Orb 3
    final double x3 = size.width * 0.2 + cos((progress + 0.66) * 2 * pi) * size.width * 0.2;
    final double y3 = size.height * 0.5 + sin((progress + 0.66) * 2 * pi) * size.height * 0.4;
    canvas.drawCircle(Offset(x3, y3), size.width * 0.4, paint3);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color1 != color1 ||
           oldDelegate.color2 != color2 ||
           oldDelegate.color3 != color3;
  }
}
