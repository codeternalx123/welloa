import 'dart:math';

class HealthService {
  final Random _random = Random(DateTime.now().day * 7);

  Future<double> getOvernightHRV() async {
    return 45.0 + (_random.nextDouble() * 40);
  }

  Future<double> getSleepScore() async {
    return 55.0 + (_random.nextDouble() * 40);
  }

  Future<double> getWeightDeltaKg() async {
    return (_random.nextDouble() - 0.5) * 1.2;
  }

  Future<Map<String, dynamic>> getFullBiometrics() async {
    return {
      'hrv': await getOvernightHRV(),
      'sleepScore': await getSleepScore(),
      'weightDelta': await getWeightDeltaKg(),
      'steps': 4000 + _random.nextInt(8000),
      'restingHeartRate': 48 + _random.nextInt(24),
      'glucoseMgDl': 72.0 + (_random.nextDouble() * 38),
      'vo2max': 38.0 + (_random.nextDouble() * 17),
      'bodyFatPercent': 12.0 + (_random.nextDouble() * 12),
      'muscleMassKg': 55.0 + (_random.nextDouble() * 30),
    };
  }
}
