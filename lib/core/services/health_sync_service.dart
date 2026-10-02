import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthSyncService {
  // Use Health() constructor since HealthFactory is deprecated in newer versions of health package.
  final Health _health = Health();

  HealthSyncService() {
    _health.configure();
  }

  final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WEIGHT,
    HealthDataType.HEART_RATE,
  ];

  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      print('Exception in installHealthConnect: $e');
    }
  }

  Future<bool> requestPermissions() async {
    // Request basic activity recognition permission on Android first
    await Permission.activityRecognition.request();
    
    final permissions = _dataTypes.map((e) => HealthDataAccess.READ).toList();
    
    try {
      bool authorized = await _health.requestAuthorization(_dataTypes, permissions: permissions);
      return authorized;
    } catch (e) {
      print('Exception in requestPermissions: $e');
      return false;
    }
  }

  Future<int> fetchSteps(DateTime start, DateTime end) async {
    try {
      int? steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (e) {
      print('Exception in fetchSteps: $e');
      return 0;
    }
  }

  Future<double> fetchActiveEnergy(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      double totalCalories = 0.0;
      for (var data in healthData) {
        final val = data.value as NumericHealthValue;
        totalCalories += val.numericValue.toDouble();
      }
      return totalCalories;
    } catch (e) {
      print('Exception in fetchActiveEnergy: $e');
      return 0.0;
    }
  }

  Future<double> fetchSleepMinutes(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.SLEEP_ASLEEP],
      );
      
      int totalMinutes = 0;
      for (var data in healthData) {
        totalMinutes += data.dateTo.difference(data.dateFrom).inMinutes;
      }
      return totalMinutes.toDouble();
    } catch (e) {
      print('Exception in fetchSleepMinutes: $e');
      return 0.0;
    }
  }
}
