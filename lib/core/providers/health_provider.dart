import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_sync_service.dart';

final healthServiceProvider = Provider<HealthSyncService>((ref) {
  return HealthSyncService();
});

class HealthData {
  final int steps;
  final double activeEnergy;
  final double sleepMinutes;
  final bool isAuthorized;

  HealthData({
    this.steps = 0,
    this.activeEnergy = 0.0,
    this.sleepMinutes = 0.0,
    this.isAuthorized = false,
  });

  HealthData copyWith({
    int? steps,
    double? activeEnergy,
    double? sleepMinutes,
    bool? isAuthorized,
  }) {
    return HealthData(
      steps: steps ?? this.steps,
      activeEnergy: activeEnergy ?? this.activeEnergy,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      isAuthorized: isAuthorized ?? this.isAuthorized,
    );
  }
}

class HealthDataNotifier extends StateNotifier<AsyncValue<HealthData>> {
  final HealthSyncService _healthService;

  HealthDataNotifier(this._healthService) : super(const AsyncValue.loading());

  Future<void> syncHealthData() async {
    try {
      state = const AsyncValue.loading();
      bool authorized = await _healthService.requestPermissions();
      
      if (!authorized) {
        state = AsyncValue.data(HealthData(isAuthorized: false));
        return;
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final yesterday = now.subtract(const Duration(days: 1));
      
      // Fetch data
      final steps = await _healthService.fetchSteps(midnight, now);
      final energy = await _healthService.fetchActiveEnergy(midnight, now);
      final sleep = await _healthService.fetchSleepMinutes(yesterday, now);

      state = AsyncValue.data(HealthData(
        steps: steps,
        activeEnergy: energy,
        sleepMinutes: sleep,
        isAuthorized: true,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void manuallyUpdateHealthData(int steps, double sleepMinutes, double activeEnergy) {
    state = AsyncValue.data(HealthData(
      steps: steps,
      sleepMinutes: sleepMinutes,
      activeEnergy: activeEnergy,
      isAuthorized: false,
    ));
  }
}

final healthDataProvider = StateNotifierProvider<HealthDataNotifier, AsyncValue<HealthData>>((ref) {
  final service = ref.watch(healthServiceProvider);
  return HealthDataNotifier(service)..syncHealthData();
});
