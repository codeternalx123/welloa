import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/health_provider.dart';
import '../../data/models/sleep_data_model.dart';
import '../../data/services/sleep_ai_service.dart';

final sleepAIServiceProvider = Provider((ref) => SleepAIService());

class SleepNotifier extends StateNotifier<AsyncValue<SleepDataModel>> {
  final SleepAIService _aiService;
  final UserProfile _profile;
  final HealthData _healthData;

  SleepNotifier(this._aiService, this._profile, this._healthData) : super(const AsyncValue.loading()) {
    fetchSleepData();
  }

  Future<void> fetchSleepData() async {
    state = const AsyncValue.loading();
    try {
      final data = await _aiService.getSleepAnalysis(_profile.age, _profile.weight, _healthData.sleepMinutes);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final sleepNotifierProvider = StateNotifierProvider<SleepNotifier, AsyncValue<SleepDataModel>>((ref) {
  final aiService = ref.watch(sleepAIServiceProvider);
  final profile = ref.watch(profileProvider);
  final healthState = ref.watch(healthDataProvider);
  final healthData = healthState.value ?? HealthData();
  return SleepNotifier(aiService, profile, healthData);
});
