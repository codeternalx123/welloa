import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/claude_service.dart';

class CoachAdvice {
  final String exerciseAdvice;
  final String foodAdvice;

  CoachAdvice({required this.exerciseAdvice, required this.foodAdvice});
}

class CoachNotifier extends StateNotifier<AsyncValue<CoachAdvice?>> {
  final ClaudeService _claudeService;

  CoachNotifier(this._claudeService) : super(const AsyncData(null));

  Future<void> getAdvice(int age, double weight) async {
    state = const AsyncValue.loading();
    try {
      final result = await _claudeService.getCoachAdvice(age: age, weight: weight);
      final advice = CoachAdvice(
        exerciseAdvice: result['exerciseAdvice'] ?? 'No exercise advice provided.',
        foodAdvice: result['foodAdvice'] ?? 'No food advice provided.',
      );
      state = AsyncValue.data(advice);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final coachClaudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());

final coachNotifierProvider = StateNotifierProvider<CoachNotifier, AsyncValue<CoachAdvice?>>((ref) {
  return CoachNotifier(ref.read(coachClaudeServiceProvider));
});
