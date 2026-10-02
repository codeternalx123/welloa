import 'package:flutter/material.dart';
import '../../../core/models/kinematic_dose.dart';

class WorkoutRecompilerCard extends StatelessWidget {
  final PlannedWorkout original;
  final RecompiledWorkout? recompiled;
  final bool wasIntercepted;

  const WorkoutRecompilerCard({
    Key? key,
    required this.original,
    this.recompiled,
    required this.wasIntercepted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!wasIntercepted || recompiled == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          border: Border.all(color: const Color(0xFF10B981)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text('CLEARED ✔', style: TextStyle(color: Color(0xFF10B981), fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Proceed with planned workout'),
            Text('${original.type} - ${original.durationMinutes} min @ ${original.intensityPercent}%'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text('INTERCEPTOR ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('INTERCEPTED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(original.type, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                    Text('${original.durationMinutes} min @ ${original.intensityPercent}%', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.arrow_forward, color: Colors.white),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('RECOMPILED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(recompiled!.type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${recompiled!.durationMinutes} min @ ${recompiled!.intensityPercent}%', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(recompiled!.rationale, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12), textAlign: TextAlign.center),
      ],
    );
  }
}
