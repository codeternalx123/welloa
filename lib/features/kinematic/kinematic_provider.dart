import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/kinematic_dose.dart';

class KinematicState {
  final bool isLoading;
  final KinematicDoseResult? result;
  final String? error;

  const KinematicState({this.isLoading = false, this.result, this.error});

  KinematicState copyWith({bool? isLoading, KinematicDoseResult? result, String? error}) {
    return KinematicState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
    );
  }
}

class KinematicNotifier extends StateNotifier<KinematicState> {
  KinematicNotifier() : super(const KinematicState());

  Future<void> evaluateMockIntake() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(seconds: 2));

    final result = KinematicDoseResult(
      id: const Uuid().v4(),
      generatedAt: DateTime.now(),
      hrvScore: 52.0,
      sleepScore: 61.0,
      weightDeltaKg: 0.4,
      cnsReadinessScore: 44.0,
      hormeticZone: 2,
      originalPlan: PlannedWorkout(type: 'HIIT', durationMinutes: 45, intensityPercent: 85),
      wasIntercepted: true,
      recompiledWorkout: RecompiledWorkout(
        type: 'Zone 2 Aerobic',
        durationMinutes: 55,
        intensityPercent: 62,
        targetHeartRateZone: 2,
        rationale: 'CNS readiness at 44/100 indicates central nervous system fatigue. High-intensity training would trigger cortisol dysregulation and impair recovery. Zone 2 aerobic work at 62% MHR will stimulate mitochondrial biogenesis without further HPA axis stress.'
      ),
      readinessNarrative: 'Your central nervous system (CNS) is currently in a state of fatigue due to suboptimal sleep (61/100) and depressed HRV (52ms). Proceeding with the planned HIIT session risks pushing your physiology beyond the optimal hormetic zone, resulting in prolonged inflammation rather than adaptation.',
      zone2Exercises: ['Brisk walking 55 min', 'Easy cycling (indoor)', 'Elliptical low resistance', 'Swimming easy laps'],
    );
    state = state.copyWith(isLoading: false, result: result);
  }
}

final kinematicProvider = StateNotifierProvider<KinematicNotifier, KinematicState>((ref) {
  return KinematicNotifier();
});
