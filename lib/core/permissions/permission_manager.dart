import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';

class PermissionManager {
  final Health health;

  PermissionManager({Health? health, Health? healthFactory})
      : health = health ?? healthFactory ?? Health();

  Future<bool> requestHealthPermissions(List<HealthDataType> types) async {
    try {
      // Check if we need Activity Recognition (Android) or Motion (iOS) for steps
      if (types.contains(HealthDataType.STEPS)) {
        final activityStatus = await Permission.activityRecognition.request();
        if (activityStatus.isDenied || activityStatus.isPermanentlyDenied) {
          return false;
        }
      }

      // Pre-check to see if already authorized
      bool? hasPermissions = await health.hasPermissions(types);
      if (hasPermissions == true) return true;

      // Request authorization via health package
      bool authorized = await health.requestAuthorization(types);
      return authorized;
    } catch (e) {
      // In enterprise grade, log this securely
      return false;
    }
  }

  Future<bool> checkActivityRecognition() async {
    final status = await Permission.activityRecognition.status;
    return status.isGranted;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
