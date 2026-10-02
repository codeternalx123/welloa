import 'dart:async';
import 'dart:math';
import 'package:health/health.dart';
import '../../error/failures.dart';
import '../../permissions/permission_manager.dart';

class HealthSyncService {
  final Health health;
  final PermissionManager permissionManager;

  static const List<HealthDataType> requiredTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  HealthSyncService({
    Health? health,
    Health? healthFactory,
    required this.permissionManager,
  }) : health = health ?? healthFactory ?? Health();

  /// Fetches health data with exponential backoff for fault tolerance.
  Future<List<HealthDataPoint>> fetchHealthDataWithBackoff({
    required DateTime start,
    required DateTime end,
    required List<HealthDataType> types,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        final authorized = await permissionManager.requestHealthPermissions(types);
        if (!authorized) {
          throw const AuthorizationFailure('Health permissions denied.');
        }

        List<HealthDataPoint> data = await health.getHealthDataFromTypes(
          types: types,
          startTime: start,
          endTime: end,
        );
        
        // Remove duplicates as recommended by health package
        return health.removeDuplicates(data);
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          if (e is AuthorizationFailure) rethrow;
          throw ServerFailure('Health sync failed after $maxRetries attempts: $e');
        }
        
        // Exponential backoff: 2^attempt seconds (2s, 4s, 8s...)
        final delaySeconds = pow(2, attempt).toInt();
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
    
    return [];
  }

  /// Syncs telemetry for the last 7 days for the core BioTwin algorithm
  Future<Map<String, dynamic>> syncWeeklyTelemetry() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final rawData = await fetchHealthDataWithBackoff(
      start: sevenDaysAgo,
      end: now,
      types: requiredTypes,
    );

    // Group by type
    final stepsData = rawData.where((d) => d.type == HealthDataType.STEPS).toList();
    final hrvData = rawData.where((d) => d.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN).toList();
    final sleepData = rawData.where((d) => d.type == HealthDataType.SLEEP_IN_BED).toList();

    // In a real scenario, we'd map these to exact daily averages using HealthDataMapper
    // Returning a summarized structured payload
    return {
      'syncTimestamp': now.toIso8601String(),
      'dataPointsFound': rawData.length,
      'metrics': {
        'steps': stepsData.length,
        'hrv': hrvData.length,
        'sleep': sleepData.length,
      }
    };
  }
}
