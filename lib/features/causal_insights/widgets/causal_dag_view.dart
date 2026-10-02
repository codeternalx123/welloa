import 'package:flutter/material.dart';
import '../../../core/models/causal_insight.dart';

class CausalDAGView extends StatelessWidget {
  final List<CausalVariable> variables;
  final CausalOutcome outcome;

  const CausalDAGView({Key? key, required this.variables, required this.outcome}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: CustomPaint(
        painter: CausalDAGPainter(variables: variables, outcome: outcome),
      ),
    );
  }
}

class CausalDAGPainter extends CustomPainter {
  final List<CausalVariable> variables;
  final CausalOutcome outcome;

  CausalDAGPainter({required this.variables, required this.outcome});

  @override
  void paint(Canvas canvas, Size size) {
    final double leftNodeX = 60.0;
    final double rightNodeX = size.width - 80.0;
    final double outcomeY = size.height / 2;

    final varSpacing = size.height / (variables.length + 1);

    for (int i = 0; i < variables.length; i++) {
      final varY = varSpacing * (i + 1);
      final p1 = Offset(leftNodeX + 40, varY);
      final p2 = Offset(rightNodeX - 60, outcomeY);
      
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(
          p1.dx + (p2.dx - p1.dx) / 2, p1.dy,
          p1.dx + (p2.dx - p1.dx) / 2, p2.dy,
          p2.dx, p2.dy,
        );

      canvas.drawPath(path, Paint()..color = Colors.cyan..style = PaintingStyle.stroke..strokeWidth = 2);

      // Arrow head
      final pathArrow = Path()
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p2.dx - 10, p2.dy - 5)
        ..lineTo(p2.dx - 10, p2.dy + 5)
        ..close();
      canvas.drawPath(pathArrow, Paint()..color = Colors.cyan..style = PaintingStyle.fill);

      _drawRectNode(canvas, leftNodeX, varY, variables[i].name, '${variables[i].value} ${variables[i].unit}', const Color(0xFF1F2937), Colors.cyan);
    }

    _drawRectNode(canvas, rightNodeX, outcomeY, outcome.metric, '${outcome.value} ${outcome.unit}', const Color(0xFF7F1D1D), Colors.red);
  }

  void _drawRectNode(Canvas canvas, double x, double y, String title, String subtitle, Color bgColor, Color borderColor) {
    final rect = Rect.fromCenter(center: Offset(x, y), width: 100, height: 50);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    
    canvas.drawRRect(rrect, Paint()..color = bgColor..style = PaintingStyle.fill);
    canvas.drawRRect(rrect, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 2);

    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    );
    titlePainter.layout(maxWidth: 90);
    titlePainter.paint(canvas, Offset(x - titlePainter.width / 2, y - 14));

    final subPainter = TextPainter(
      text: TextSpan(text: subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    subPainter.layout(maxWidth: 90);
    subPainter.paint(canvas, Offset(x - subPainter.width / 2, y + 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
