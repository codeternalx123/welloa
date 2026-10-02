import 'package:flutter/material.dart';

// Lightweight shim for the `confetti` package used as a compatibility fallback.
// This provides minimal types so UI files depending on Confetti don't fail
// static analysis. It's intentionally tiny and non-animated — replace with
// the real `confetti` package for full fidelity.

enum BlastDirectionality { directional, explosive }

class ConfettiController {
  final Duration? duration;
  ConfettiController({this.duration});
  void play() {}
  void stop() {}
  void dispose() {}
}

class ConfettiWidget extends StatelessWidget {
  final ConfettiController confettiController;
  final BlastDirectionality blastDirectionality;
  final bool shouldLoop;
  final List<Color>? colors;
  final int? numberOfParticles;
  final double? gravity;

  const ConfettiWidget({
    super.key,
    required this.confettiController,
    this.blastDirectionality = BlastDirectionality.explosive,
    this.shouldLoop = false,
    this.colors,
    this.numberOfParticles,
    this.gravity,
  });

  @override
  Widget build(BuildContext context) {
    // Minimal visual feedback: a subtle circle at the top center
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: (colors ?? [Colors.green, Colors.blue, Colors.orange]).map((c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          )).toList(),
        ),
      ),
    );
  }
}
