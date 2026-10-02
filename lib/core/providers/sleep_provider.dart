import 'package:flutter_riverpod/flutter_riverpod.dart';

class SleepData {
  final String remDensity;
  final String deepSleepLatency;
  final String totalSleep;

  SleepData({
    this.remDensity = 'Low',
    this.deepSleepLatency = 'Delayed',
    this.totalSleep = 'Under 6 Hours',
  });

  SleepData copyWith({
    String? remDensity,
    String? deepSleepLatency,
    String? totalSleep,
  }) {
    return SleepData(
      remDensity: remDensity ?? this.remDensity,
      deepSleepLatency: deepSleepLatency ?? this.deepSleepLatency,
      totalSleep: totalSleep ?? this.totalSleep,
    );
  }
}

class SleepDataNotifier extends StateNotifier<SleepData> {
  SleepDataNotifier() : super(SleepData());

  void updateSleepData(String remDensity, String deepSleepLatency, String totalSleep) {
    state = state.copyWith(remDensity: remDensity, deepSleepLatency: deepSleepLatency, totalSleep: totalSleep);
  }
}

final sleepDataProvider = StateNotifierProvider<SleepDataNotifier, SleepData>((ref) {
  return SleepDataNotifier();
});
