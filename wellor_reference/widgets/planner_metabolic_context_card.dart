import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/glucose_provider.dart';
import '../providers/user_profile_provider.dart' show UserProfile, UserProfileProvider;
import '../services/meal_planning_service.dart';
import 'feature_restriction_widgets.dart';
import 'glucose_nexus_gate.dart';

/// Glycemic + live glucose context for the meal planner (compact, low rebuild cost).
class PlannerMetabolicContextCard extends StatelessWidget {
  const PlannerMetabolicContextCard({
    super.key,
    required this.currentPlan,
    required this.isGenerating,
  });

  final MealPlan? currentPlan;
  final bool isGenerating;

  static bool _profileSuggestsGlycemicCare(UserProfile? p) {
    if (p == null) return false;
    final diseases = p.diseases;
    if (diseases.isEmpty) return false;
    return diseases.any(
      (d) => d.toLowerCase().contains('diabet') || d.toLowerCase().contains('glucose'),
    );
  }

  static double? _averagePlanGi(MealPlan? plan) {
    if (plan == null || plan.mealDays.isEmpty) return null;
    var sum = 0;
    var n = 0;
    for (final day in plan.mealDays) {
      for (final m in day.meals) {
        sum += m.glycemicIndex;
        n++;
      }
    }
    if (n == 0) return null;
    return sum / n;
  }

  Future<void> _previewFirstMealImpact(BuildContext context) async {
    final plan = currentPlan;
    if (plan == null || plan.mealDays.isEmpty) return;
    final meals = plan.mealDays.first.meals;
    if (meals.isEmpty) return;
    final names = meals.first.ingredients.map((e) => e.name).where((s) => s.isNotEmpty).toList();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ingredients listed for the first meal yet.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _MealImpactPreviewSheet(ingredientNames: names, mealName: meals.first.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avgGi = _averagePlanGi(currentPlan);
    final userProfile = context.watch<UserProfileProvider>().userProfile;
    final glycemicCare = _profileSuggestsGlycemicCare(userProfile);

    return Selector<GlucoseProvider, ({double? g, String advice, bool sync})>(
      selector: (_, g) => (
        g: g.currentGlucose,
        advice: g.advice,
        sync: g.isSynchronizing,
      ),
      builder: (context, snap, _) {
        final adviceShort = snap.advice.length > 96 ? '${snap.advice.substring(0, 93)}…' : snap.advice;

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.92),
                  const Color(0xFF312E81).withValues(alpha: 0.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bubble_chart_rounded,
                        color: Colors.cyanAccent.shade100, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Metabolic lens',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    if (snap.sync)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (glycemicCare)
                      Chip(
                        label: const Text('Low-GI bias in planner AI'),
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (avgGi != null)
                      Chip(
                        label: Text('Plan avg GI ${avgGi.toStringAsFixed(0)}'),
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        backgroundColor: Colors.tealAccent.withValues(alpha: 0.2),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snap.g != null ? '${snap.g!.toStringAsFixed(0)} mg/dL' : 'No recent glucose',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adviceShort,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            backgroundColor: Colors.white.withValues(alpha: 0.9),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: isGenerating
                              ? null
                              : () {
                                  if (!checkGlucoseNexusAccess(context)) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const GlucoseNexusGate(),
                                    ),
                                  );
                                },
                          child: const Text('Glucose Nexus'),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: isGenerating || currentPlan == null
                              ? null
                              : () => _previewFirstMealImpact(context),
                          child: Text(
                            'Sample meal impact',
                            style: TextStyle(
                              color: Colors.cyanAccent.shade100,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Wellness insights only — not a substitute for medical advice.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: snap.sync
                        ? null
                        : () => context.read<GlucoseProvider>().refreshMetabolicTelemetry(),
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                    label: const Text('Sync', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MealImpactPreviewSheet extends StatefulWidget {
  const _MealImpactPreviewSheet({
    required this.ingredientNames,
    required this.mealName,
  });

  final List<String> ingredientNames;
  final String mealName;

  @override
  State<_MealImpactPreviewSheet> createState() => _MealImpactPreviewSheetState();
}

class _MealImpactPreviewSheetState extends State<_MealImpactPreviewSheet> {
  String? _text;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final g = context.read<GlucoseProvider>();
      final advice = await g.getClinicalTriageAdvice(widget.ingredientNames);
      if (mounted) setState(() {
        _text = advice;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = 'Could not run preview: $e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.mealName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Text(
              _text ?? '',
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
        ],
      ),
    );
  }
}
