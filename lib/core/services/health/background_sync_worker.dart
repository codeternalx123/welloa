import 'dart:async';
import 'package:flutter/foundation.dart';
import 'health_sync_service.dart';

class BackgroundSyncWorker {
  final HealthSyncService healthSyncService;

  static const String taskName = "com.welloa.telemetry.sync";
  
  BackgroundSyncWorker({dynamic health, dynamic healthFactory, required this.healthSyncService})
      : health = health ?? healthFactory;
  
  // Note: we can't actually inject Riverpod directly into background isolates on Android.
  // We need to pass required references to a top-level callback in the future.
  final dynamic health;

  /// Initializes the background worker configuration
  Future<void> initialize() async {
    // In a real implementation we would configure `workmanager` here:
    // Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    debugPrint('BackgroundSyncWorker initialized.');
  }

  /// Registers a periodic task to sync telemetry every 4 hours
  Future<void> registerPeriodicSync() async {
    // Workmanager().registerPeriodicTask(
    //   "1",
    //   taskName,
    //   frequency: const Duration(hours: 4),
    //   constraints: Constraints(
    //     networkType: NetworkType.connected,
    //     requiresBatteryNotLow: true,
    //   ),
    // );
    debugPrint('Periodic health sync task registered.');
  }

  /// Entry point for the background task to execute
  Future<bool> executeSyncTask() async {
    try {
      debugPrint('Executing background health sync...');
      final result = await healthSyncService.syncWeeklyTelemetry();
      debugPrint('Background sync successful: ${result['dataPointsFound']} points extracted.');
      return true;
    } catch (e) {
      debugPrint('Background sync failed: $e');
      // Returning false tells the OS to retry this task later
      return false;
    }
  }
}
