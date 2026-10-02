import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/aeg_node.dart';

class GraphCanvas extends StatelessWidget {
  final AEGGraph graph;

  const GraphCanvas({Key? key, required this.graph}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      width: double.infinity,
      child: CustomPaint(
        painter: GraphCanvasPainter(graph: graph),
      ),
    );
  }
}

class GraphCanvasPainter extends CustomPainter {
  final AEGGraph graph;

  GraphCanvasPainter({required this.graph});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2.5;

    // Map node to its position
    final Map<String, Offset> nodePositions = {};
    final n = graph.nodes.length;
    final angleStep = 2 * pi / n;

    for (int i = 0; i < n; i++) {
      final angle = i * angleStep - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      nodePositions[graph.nodes[i].id] = Offset(x, y);
    }

    // Draw Edges
    for (var edge in graph.edges) {
      final p1 = nodePositions[edge.fromNodeId];
      final p2 = nodePositions[edge.toNodeId];
      if (p1 != null && p2 != null) {
        Color color = Colors.grey;
        double strokeWidth = 1.0;
        
        if (edge.strength > 0.7) {
          color = Colors.cyan;
          strokeWidth = 3.0;
        } else if (edge.strength > 0.4) {
          color = Colors.purpleAccent;
          strokeWidth = 2.0;
        }

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..quadraticBezierTo(
            center.dx + (p1.dx + p2.dx - 2 * center.dx) * 0.2,
            center.dy + (p1.dy + p2.dy - 2 * center.dy) * 0.2,
            p2.dx, p2.dy,
          );

        canvas.drawPath(path, Paint()..color = color.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = strokeWidth);

        // Arrow head logic simplified: just draw a dot at the end
        canvas.drawCircle(p2, 4, Paint()..color = color);
      }
    }

    // Draw Nodes
    for (var node in graph.nodes) {
      final pos = nodePositions[node.id]!;
      Color color = Colors.green;
      if (node.status == 'critical') color = Colors.red;
      if (node.status == 'suboptimal') color = Colors.amber;

      final nodeRadius = 15.0 + (node.impactScore * 10);

      if (node.status == 'critical') {
        canvas.drawCircle(pos, nodeRadius + 5, Paint()..color = color.withOpacity(0.3));
      }
      
      canvas.drawCircle(pos, nodeRadius, Paint()..color = color);
      canvas.drawCircle(pos, nodeRadius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

      final textPainter = TextPainter(
        text: TextSpan(text: node.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: 80);
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + nodeRadius + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
