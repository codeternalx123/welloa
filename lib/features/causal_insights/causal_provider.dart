import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/causal_insight.dart';

class CausalState {
  final bool isLoading;
  final CausalInsightResult? result;
  final String? error;
  final int selectedPreset;

  const CausalState({this.isLoading = false, this.result, this.error, this.selectedPreset = 0});

  CausalState copyWith({bool? isLoading, CausalInsightResult? result, String? error, int? selectedPreset}) {
    return CausalState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
      selectedPreset: selectedPreset ?? this.selectedPreset,
    );
  }
}

class CausalNotifier extends StateNotifier<CausalState> {
  CausalNotifier() : super(const CausalState());

  void selectPreset(int index) {
    state = state.copyWith(selectedPreset: index);
    runMockInference();
  }

  Future<void> runMockInference() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(seconds: 2));

    final result = CausalInsightResult(
      id: const Uuid().v4(),
      analyzedAt: DateTime.now(),
      inputVariables: [
        CausalVariable(name: 'Carbohydrate Load', value: '85g', unit: 'CHO', category: 'nutrition'),
        CausalVariable(name: 'Sleep Duration', value: '5.0', unit: 'hours', category: 'sleep'),
        CausalVariable(name: 'Activity Level', value: 'Sedentary', unit: '', category: 'exercise'),
      ],
      outcome: CausalOutcome(
        metric: 'Inflammatory Recovery Window',
        value: 18.4,
        unit: 'hours',
        temporalExtentHours: 18.4,
        description: 'Combined glycemic stress from 85g CHO load with 5h sleep causally extends post-meal inflammatory resolution by 18.4 hours. Synergistically amplified due to impaired IL-6 clearance during sleep deprivation.',
      ),
      causalConfidence: 0.87,
      doOperatorQuery: 'do(carb_load=high_glycemic_85gCHO, sleep=5.0h, activity=sedentary)',
      counterfactuals: [
        CounterfactualScenario(description: 'If sleep was 7.5 hours instead', changedVariable: 'Sleep Duration', changedValue: '7.5h', alternativeOutcome: 6.2, deltaVsActual: -12.2),
        CounterfactualScenario(description: 'If carb load was low-glycemic', changedVariable: 'Carbohydrate Load', changedValue: '35g low-GI', alternativeOutcome: 4.8, deltaVsActual: -13.6),
        CounterfactualScenario(description: 'If 30-min Zone 2 walk was added', changedVariable: 'Activity Level', changedValue: 'Zone 2 walk 30min', alternativeOutcome: 9.1, deltaVsActual: -9.3),
      ],
      narrative: 'By running adversarial inference on your bio-twin, we isolated the causal impact of sleep deprivation combined with high glycemic load. This is not a mere correlation; the do-calculus model confirms that the sleep deficit directly impaired the cortisol clearance required to resolve the inflammatory spike from the meal.',
    );
    state = state.copyWith(isLoading: false, result: result);
  }
}

final causalProvider = StateNotifierProvider<CausalNotifier, CausalState>((ref) {
  return CausalNotifier();
});
