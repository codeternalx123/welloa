import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

/// ============================================================================
/// WearableDataService — Real-time Health Data from Smartwatch / CGM
/// ============================================================================
///
/// Reads all biometric data types via the `health` package (Health Connect on
/// Android, HealthKit on iOS) and persists snapshots to Firestore so the
/// Multi-Agent System always has fresh data.
///
/// ─── SUPPORTED DEVICES & DATA AVAILABILITY ─────────────────────────────────
///
/// ANDROID (via Health Connect):
///   Samsung Galaxy Watch 4/5/6/7/Ultra
///     ✅ HR, Resting HR, HRV, SpO2, Steps, Sleep, Calories, Workout, BP*, Temp*
///     * BP requires Samsung Health Monitor (Galaxy Watch 4+)
///     * Temp on Galaxy Watch 5+ (infrared sensor)
///
///   Google Pixel Watch / Pixel Watch 2/3
///     ✅ HR, Resting HR, HRV, SpO2, Steps, Sleep, Calories, Workout
///     ❌ Blood Pressure, Body Temperature
///
///   Fitbit Sense / Sense 2 / Versa 4 / Charge 6
///     ✅ HR, Resting HR, HRV (Sense only), SpO2, Steps, Sleep, Calories, Workout
///     ❌ Blood Pressure, Body Temperature
///
///   Garmin Venu 3 / Forerunner / Fenix / Epix
///     ✅ HR, Resting HR, HRV, SpO2, Steps, Sleep, Calories, Workout, Temp (some)
///     ❌ Blood Pressure (requires Health Connect sync via Garmin Connect)
///
///   Xiaomi / Amazfit (with Health Connect enabled)
///     ✅ HR, SpO2, Steps, Sleep, Calories
///     ⚠️ Limited HRV/Body Temp depending on model
///
///   Withings ScanWatch / ScanWatch 2
///     ✅ HR, SpO2, Steps, Sleep, Calories, Body Temp (medical-grade)
///     ❌ HRV (ScanWatch 2 only), Blood Pressure (ScanWatch Nova only)
///
///   WHOOP 4.0 (via Health Connect)
///     ✅ HR, Resting HR, HRV, Sleep, Calories, Workout
///     ❌ SpO2, Blood Pressure, Temperature
///
///   Oura Ring Gen 3
///     ✅ HR, Resting HR, HRV, SpO2, Sleep, Body Temp, Steps
///     ❌ Blood Pressure, Workout (limited)
///
/// iOS (via HealthKit):
///   Apple Watch Series 4–10 / Ultra / Ultra 2
///     ✅ HR, Resting HR, HRV, SpO2, Steps, Sleep, Calories, Workout, Temp (S8+)
///     ✅ Blood Pressure (Series 10 — FDA-cleared)
///     Best overall coverage — all 15 data types supported on Series 10+
///
///   Withings ScanWatch (syncs to HealthKit)
///     ✅ Same as Android listing above
///
///   Oura Ring Gen 3 (syncs to HealthKit)
///     ✅ Same as Android listing above
///
/// ─── CGM (Continuous Glucose Monitors) ─────────────────────────────────────
///   Abbott FreeStyle Libre 2 / Libre 3
///     ✅ Blood Glucose, GlucoseHistory — via LibreLink → Health Connect/HealthKit
///
///   Medtronic Guardian 4
///     ⚠️ Blood Glucose — requires Medtronic app to sync to Health Connect
///
///   Eversense E3
///     ⚠️ Blood Glucose — sync via companion app
///
/// ─── BLOOD PRESSURE MONITORS (BPM) ────────────────────────────────────────
///   Withings BPM Connect / BPM Core
///     ✅ Systolic, Diastolic — syncs to Health Connect / HealthKit
///
///   Omron Complete / Evolv (Bluetooth models)
///     ✅ Systolic, Diastolic — via OMRON connect → Health Connect/HealthKit
///
///   Samsung Galaxy Watch 4+ (built-in)
///     ✅ Systolic, Diastolic — requires calibration with cuff
///
/// ─── SMART SCALES ──────────────────────────────────────────────────────────
///   Withings Body+ / Body Comp / Body Scan
///     ✅ Weight — syncs to Health Connect / HealthKit
///
///   Garmin Index S2 / BPM
///     ✅ Weight — via Garmin Connect → Health Connect
///
///   Eufy Smart Scale P2 Pro
///     ✅ Weight — via EufyLife → Health Connect
///
/// ─── HYDRATION TRACKING ────────────────────────────────────────────────────
///   Manual logging via Samsung Health, Apple Health, or Wellor
///     ✅ Water intake (WATER data type)
///
///   HidrateSpark smart water bottle
///     ✅ Automatic water tracking → syncs to Apple Health / Health Connect
///
/// NOTE: All devices must sync their data to Health Connect (Android) or
/// HealthKit (iOS) for Wellor to read it. The `health` Flutter package
/// reads from these platform aggregators — not directly from the watch.
/// ============================================================================
class WearableDataService {
  static final WearableDataService _instance = WearableDataService._internal();
  factory WearableDataService() => _instance;
  WearableDataService._internal();

  final Health _health = Health();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _authorized = false;
  bool get isAuthorized => _authorized;

  /// Detected source device name from the last read
  String? _detectedDevice;
  String? get detectedDevice => _detectedDevice;

  /// Which data types were actually available in the last read
  final Set<String> _availableMetrics = {};
  Set<String> get availableMetrics => Set.unmodifiable(_availableMetrics);

  // ──────────────────────────────────────────────────────────────────
  // SUPPORTED DEVICE REGISTRY
  // ──────────────────────────────────────────────────────────────────

  /// Structured registry of supported devices and their capabilities.
  /// Each entry maps a recognized source name pattern to a device profile.
  static const List<SupportedDevice> supportedDevices = [
    // ── Android Watches ──
    SupportedDevice(
      name: 'Samsung Galaxy Watch 4/5/6/7/Ultra',
      platform: DevicePlatform.android,
      category: DeviceCategory.smartwatch,
      sourcePatterns: ['samsung', 'galaxy watch', 'galaxy_watch', 's health'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': true, 'workout': true, 'weight': false,
        'bloodPressure': true, 'bodyTemperature': true,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'BP requires Samsung Health Monitor app (Watch 4+). '
             'Temperature on Watch 5+ only (infrared sensor).',
    ),
    SupportedDevice(
      name: 'Google Pixel Watch / Pixel Watch 2/3',
      platform: DevicePlatform.android,
      category: DeviceCategory.smartwatch,
      sourcePatterns: ['pixel watch', 'pixel_watch', 'google fit', 'fitbit'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': true, 'workout': true, 'weight': false,
        'bloodPressure': false, 'bodyTemperature': false,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Uses Fitbit health services. No BP or temperature sensors.',
    ),
    SupportedDevice(
      name: 'Fitbit Sense / Sense 2 / Versa 4 / Charge 6',
      platform: DevicePlatform.android,
      category: DeviceCategory.smartwatch,
      sourcePatterns: ['fitbit'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': true, 'workout': true, 'weight': false,
        'bloodPressure': false, 'bodyTemperature': true,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'HRV available on Sense/Sense 2 only. Temp is skin temperature deviation.',
    ),
    SupportedDevice(
      name: 'Garmin Venu 3 / Forerunner / Fenix / Epix',
      platform: DevicePlatform.android,
      category: DeviceCategory.smartwatch,
      sourcePatterns: ['garmin', 'garmin connect'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': true, 'workout': true, 'weight': false,
        'bloodPressure': false, 'bodyTemperature': true,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Requires Garmin Connect → Health Connect sync. '
             'Temp on select models (Venu 3, Fenix 7+).',
    ),
    SupportedDevice(
      name: 'Xiaomi / Amazfit Smart Band & Watch',
      platform: DevicePlatform.android,
      category: DeviceCategory.smartwatch,
      sourcePatterns: ['xiaomi', 'amazfit', 'mi fitness', 'zepp'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': false, 'hrv': false,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': true, 'workout': true, 'weight': false,
        'bloodPressure': false, 'bodyTemperature': false,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Limited advanced metrics. Must enable Health Connect in Zepp/Mi Fitness.',
    ),
    SupportedDevice(
      name: 'Withings ScanWatch / ScanWatch 2 / Nova',
      platform: DevicePlatform.both,
      category: DeviceCategory.smartwatch,
      sourcePatterns: ['withings', 'scanwatch', 'health mate'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': true, 'workout': false, 'weight': false,
        'bloodPressure': true, 'bodyTemperature': true,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Medical-grade SpO2 and temperature. '
             'BP on ScanWatch Nova only. HRV on ScanWatch 2+.',
    ),
    SupportedDevice(
      name: 'WHOOP 4.0',
      platform: DevicePlatform.both,
      category: DeviceCategory.fitnessTracker,
      sourcePatterns: ['whoop'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': false, 'steps': false, 'sleep': true,
        'calories': true, 'workout': true, 'weight': false,
        'bloodPressure': false, 'bodyTemperature': true,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Requires Health Connect sync. No SpO2 or steps. Excellent HRV/recovery data.',
    ),
    SupportedDevice(
      name: 'Oura Ring Gen 3',
      platform: DevicePlatform.both,
      category: DeviceCategory.smartRing,
      sourcePatterns: ['oura'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': false, 'workout': false, 'weight': false,
        'bloodPressure': false, 'bodyTemperature': true,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Excellent sleep and HRV tracking. Limited workout detection.',
    ),
    // ── iOS Watch ──
    SupportedDevice(
      name: 'Apple Watch Series 4–10 / Ultra / Ultra 2',
      platform: DevicePlatform.ios,
      category: DeviceCategory.smartwatch,
      sourcePatterns: ['apple watch', 'apple_watch', 'apple health', 'com.apple.health'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': true, 'hrv': true,
        'bloodOxygen': true, 'steps': true, 'sleep': true,
        'calories': true, 'workout': true, 'weight': false,
        'bloodPressure': true, 'bodyTemperature': true,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Best overall coverage. BP on Series 10+ (FDA-cleared). '
             'Temp on Series 8+ (wrist temperature). SpO2 on Series 6+.',
    ),
    // ── CGM Devices ──
    SupportedDevice(
      name: 'Abbott FreeStyle Libre 2 / Libre 3',
      platform: DevicePlatform.both,
      category: DeviceCategory.cgm,
      sourcePatterns: ['freestyle', 'libre', 'abbott', 'librelink'],
      capabilities: {
        'heartRate': false, 'restingHeartRate': false, 'hrv': false,
        'bloodOxygen': false, 'steps': false, 'sleep': false,
        'calories': false, 'workout': false, 'weight': false,
        'bloodPressure': false, 'bodyTemperature': false,
        'bloodGlucose': true, 'hydration': false,
      },
      notes: 'Requires LibreLink app to sync to Health Connect/HealthKit.',
    ),
    // ── Blood Pressure Monitors ──
    SupportedDevice(
      name: 'Withings BPM Connect / BPM Core',
      platform: DevicePlatform.both,
      category: DeviceCategory.bpMonitor,
      sourcePatterns: ['withings bpm', 'bpm connect', 'bpm core'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': false, 'hrv': false,
        'bloodOxygen': false, 'steps': false, 'sleep': false,
        'calories': false, 'workout': false, 'weight': false,
        'bloodPressure': true, 'bodyTemperature': false,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'FDA-cleared. Syncs via Health Mate → Health Connect/HealthKit.',
    ),
    SupportedDevice(
      name: 'Omron Complete / Evolv (Bluetooth)',
      platform: DevicePlatform.both,
      category: DeviceCategory.bpMonitor,
      sourcePatterns: ['omron'],
      capabilities: {
        'heartRate': true, 'restingHeartRate': false, 'hrv': false,
        'bloodOxygen': false, 'steps': false, 'sleep': false,
        'calories': false, 'workout': false, 'weight': false,
        'bloodPressure': true, 'bodyTemperature': false,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Syncs via OMRON connect app.',
    ),
    // ── Smart Scales ──
    SupportedDevice(
      name: 'Withings Body+ / Body Comp / Body Scan',
      platform: DevicePlatform.both,
      category: DeviceCategory.scale,
      sourcePatterns: ['withings body', 'body+', 'body comp', 'body scan'],
      capabilities: {
        'heartRate': false, 'restingHeartRate': false, 'hrv': false,
        'bloodOxygen': false, 'steps': false, 'sleep': false,
        'calories': false, 'workout': false, 'weight': true,
        'bloodPressure': false, 'bodyTemperature': false,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Weight syncs via Health Mate.',
    ),
    SupportedDevice(
      name: 'Garmin Index S2',
      platform: DevicePlatform.both,
      category: DeviceCategory.scale,
      sourcePatterns: ['garmin index'],
      capabilities: {
        'heartRate': false, 'restingHeartRate': false, 'hrv': false,
        'bloodOxygen': false, 'steps': false, 'sleep': false,
        'calories': false, 'workout': false, 'weight': true,
        'bloodPressure': false, 'bodyTemperature': false,
        'bloodGlucose': false, 'hydration': false,
      },
      notes: 'Syncs via Garmin Connect.',
    ),
  ];

  /// All data types the agents need for full-spectrum health monitoring
  static const List<HealthDataType> _readTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WATER,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.WORKOUT,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.WEIGHT,
  ];

  // ──────────────────────────────────────────────────────────────────
  // AUTHORIZATION
  // ──────────────────────────────────────────────────────────────────

  /// Request permissions for all health data types the agents need.
  /// Returns true if permissions were granted.
  Future<bool> requestAuthorization() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    try {
      // On Android, check Health Connect availability first
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailable) {
          debugPrint('[WearableData] Health Connect not available on this device');
          return false;
        }
        if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          debugPrint('[WearableData] Health Connect needs update');
          await _health.installHealthConnect();
          return false;
        }
      }

      // Configure the health plugin
      await _health.configure();

      final permissions = _readTypes.map((_) => HealthDataAccess.READ).toList();
      _authorized = await _health.requestAuthorization(
        _readTypes,
        permissions: permissions,
      );

      debugPrint('[WearableData] Authorization: $_authorized');
      return _authorized;
    } catch (e) {
      debugPrint('[WearableData] Authorization error: $e');
      return false;
    }
  }

  /// Open the Health Connect settings page (Android) so users can
  /// manage permissions directly. Returns true if navigation succeeded.
  Future<bool> openHealthSettings() async {
    try {
      if (Platform.isAndroid) {
        // Use the correct Android intent URI to open Health Connect settings
        final intentUri = Uri.parse(
          'intent:#Intent;action=androidx.health.ACTION_HEALTH_CONNECT_SETTINGS;end',
        );
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri);
          return true;
        }
        // Fallback: open Health Connect via its package on Play Store
        final playStore = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
        );
        await launchUrl(playStore, mode: LaunchMode.externalApplication);
        return true;
      }
      // On iOS, HealthKit permissions are managed via the system prompt;
      // there's no dedicated settings page to open.
      return false;
    } catch (e) {
      debugPrint('[WearableData] Open health settings error: $e');
      return false;
    }
  }

  /// Check if we already have permissions without prompting.
  Future<bool> hasPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      await _health.configure();
      final result = await _health.hasPermissions(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      _authorized = result ?? false;
      return _authorized;
    } catch (e) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // DATA READING — Full Biometric Snapshot
  // ──────────────────────────────────────────────────────────────────

  /// Read all available health data and return a unified biometric map.
  /// This is what the agents consume via AgentState.
  Future<Map<String, dynamic>> readAllBiometrics({
    Duration lookback = const Duration(hours: 24),
  }) async {
    if (!_authorized) {
      debugPrint('[WearableData] Not authorized — returning empty biometrics');
      return {};
    }

    final now = DateTime.now();
    final start = now.subtract(lookback);
    final biometrics = <String, dynamic>{};

    try {
      final dataPoints = await _health.getHealthDataFromTypes(
        types: _readTypes,
        startTime: start,
        endTime: now,
      );

      // De-duplicate
      final unique = _health.removeDuplicates(dataPoints);

      // Process each data type
      biometrics['heartRate'] = _latestNumeric(unique, HealthDataType.HEART_RATE);
      biometrics['restingHeartRate'] = _latestNumeric(unique, HealthDataType.RESTING_HEART_RATE);
      biometrics['heartRateVariability'] = _latestNumeric(unique, HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      biometrics['glucose'] = _latestNumeric(unique, HealthDataType.BLOOD_GLUCOSE);
      biometrics['bloodOxygen'] = _latestNumeric(unique, HealthDataType.BLOOD_OXYGEN);
      biometrics['bodyTemperature'] = _latestNumeric(unique, HealthDataType.BODY_TEMPERATURE);
      biometrics['weight'] = _latestNumeric(unique, HealthDataType.WEIGHT);

      // Blood pressure (systolic / diastolic)
      biometrics['bloodPressureSystolic'] = _latestNumeric(unique, HealthDataType.BLOOD_PRESSURE_SYSTOLIC);
      biometrics['bloodPressureDiastolic'] = _latestNumeric(unique, HealthDataType.BLOOD_PRESSURE_DIASTOLIC);

      // Aggregated values over the period
      biometrics['stepsToday'] = _sumNumeric(unique, HealthDataType.STEPS);
      biometrics['caloriesBurned'] = _sumNumeric(unique, HealthDataType.ACTIVE_ENERGY_BURNED);
      biometrics['hydrationLiters'] = _sumHydration(unique);

      // Sleep
      final sleepData = _calculateSleep(unique);
      biometrics['sleepHours'] = sleepData['hours'];
      biometrics['sleepQuality'] = sleepData['quality'];

      // Glucose history (recent readings for trend analysis)
      biometrics['glucoseHistory'] = _getGlucoseHistory(unique);

      // Heart rate history (for resting / active comparison)
      biometrics['heartRateHistory'] = _getHeartRateHistory(unique);

      // Workout sessions today
      biometrics['workoutMinutesToday'] = _getWorkoutMinutes(unique);

      // Source device info
      _detectedDevice = unique.isNotEmpty ? unique.first.sourceName : null;
      biometrics['sourcePlatform'] = _detectedDevice;
      biometrics['lastSyncTime'] = now.toIso8601String();

      // Track which metrics actually had data
      _availableMetrics.clear();
      biometrics.forEach((key, value) {
        if (value != null && key != 'sourcePlatform' && key != 'lastSyncTime' &&
            key != 'glucoseHistory' && key != 'heartRateHistory') {
          _availableMetrics.add(key);
        }
      });

      // Attach matched device info
      final matched = identifyDevice(_detectedDevice);
      biometrics['matchedDevice'] = matched?.name;
      biometrics['deviceCategory'] = matched?.category.label;
      biometrics['deviceNotes'] = matched?.notes;

      debugPrint('[WearableData] Read ${unique.length} data points across ${_readTypes.length} types');
    } catch (e) {
      debugPrint('[WearableData] Read error: $e');
    }

    return biometrics;
  }

  /// Sync biometric data to Firestore so background agents can access it.
  /// Writes to: users/{uid}/biometrics/current
  Future<void> syncToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final biometrics = await readAllBiometrics();
    if (biometrics.isEmpty) return;

    biometrics['updatedAt'] = FieldValue.serverTimestamp();

    await _db
        .collection('users')
        .doc(uid)
        .collection('biometrics')
        .doc('current')
        .set(biometrics, SetOptions(merge: true));

    // Also write glucose reading to the glucose_readings collection
    // for the LangGraph pipeline compatibility
    final glucose = biometrics['glucose'];
    if (glucose != null) {
      await _db.collection('glucose_readings').add({
        'user_id': uid,
        'glucose_level': glucose,
        'source': 'wearable',
        'device': biometrics['sourcePlatform'] ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    debugPrint('[WearableData] Synced biometrics to Firestore for $uid');
  }

  // ──────────────────────────────────────────────────────────────────
  // DATA EXTRACTION HELPERS
  // ──────────────────────────────────────────────────────────────────

  /// Get the most recent numeric value for a given data type.
  double? _latestNumeric(List<HealthDataPoint> points, HealthDataType type) {
    final matching = points
        .where((p) => p.type == type)
        .toList()
      ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    if (matching.isEmpty) return null;

    final value = matching.first.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  }

  /// Sum all numeric values for a given type (e.g., steps, calories).
  int _sumNumeric(List<HealthDataPoint> points, HealthDataType type) {
    return points
        .where((p) => p.type == type)
        .fold<int>(0, (sum, p) {
      final value = p.value;
      if (value is NumericHealthValue) {
        return sum + value.numericValue.toInt();
      }
      return sum;
    });
  }

  /// Sum hydration data (WATER type, value in liters).
  double _sumHydration(List<HealthDataPoint> points) {
    return points
        .where((p) => p.type == HealthDataType.WATER)
        .fold<double>(0.0, (sum, p) {
      final value = p.value;
      if (value is NumericHealthValue) {
        return sum + value.numericValue.toDouble();
      }
      return sum;
    });
  }

  /// Calculate sleep hours and quality from sleep data points.
  Map<String, dynamic> _calculateSleep(List<HealthDataPoint> points) {
    final sleepPoints = points.where(
      (p) => p.type == HealthDataType.SLEEP_ASLEEP || p.type == HealthDataType.SLEEP_IN_BED,
    ).toList();

    if (sleepPoints.isEmpty) return {'hours': null, 'quality': null};

    // Total time asleep
    double asleepMinutes = 0;
    double inBedMinutes = 0;

    for (final p in sleepPoints) {
      final duration = p.dateTo.difference(p.dateFrom).inMinutes.toDouble();
      if (p.type == HealthDataType.SLEEP_ASLEEP) {
        asleepMinutes += duration;
      } else {
        inBedMinutes += duration;
      }
    }

    final totalBed = inBedMinutes > 0 ? inBedMinutes : asleepMinutes;
    final sleepHours = (asleepMinutes > 0 ? asleepMinutes : totalBed) / 60.0;

    // Sleep quality: ratio of asleep time to in-bed time, scaled 0-100
    int? quality;
    if (asleepMinutes > 0 && totalBed > 0) {
      final efficiency = (asleepMinutes / totalBed * 100).round();
      quality = efficiency.clamp(0, 100);
    } else if (sleepHours > 0) {
      // Estimate quality from duration alone
      if (sleepHours >= 7) {
        quality = 80;
      } else if (sleepHours >= 6) {
        quality = 60;
      } else {
        quality = 40;
      }
    }

    return {'hours': sleepHours, 'quality': quality};
  }

  /// Get recent glucose readings as a list of {value, timestamp} maps.
  List<Map<String, dynamic>> _getGlucoseHistory(List<HealthDataPoint> points) {
    final glucosePoints = points
        .where((p) => p.type == HealthDataType.BLOOD_GLUCOSE)
        .toList()
      ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    return glucosePoints.take(20).map((p) {
      final value = p.value;
      return {
        'value': value is NumericHealthValue ? value.numericValue.toDouble() : 0.0,
        'timestamp': p.dateFrom.toIso8601String(),
      };
    }).toList();
  }

  /// Get heart rate history for trend analysis.
  List<Map<String, dynamic>> _getHeartRateHistory(List<HealthDataPoint> points) {
    final hrPoints = points
        .where((p) => p.type == HealthDataType.HEART_RATE)
        .toList()
      ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    return hrPoints.take(30).map((p) {
      final value = p.value;
      return {
        'value': value is NumericHealthValue ? value.numericValue.toDouble() : 0.0,
        'timestamp': p.dateFrom.toIso8601String(),
      };
    }).toList();
  }

  /// Get total workout minutes today from WORKOUT data points.
  int _getWorkoutMinutes(List<HealthDataPoint> points) {
    return points
        .where((p) => p.type == HealthDataType.WORKOUT)
        .fold<int>(0, (sum, p) {
      return sum + p.dateTo.difference(p.dateFrom).inMinutes;
    });
  }

  // ──────────────────────────────────────────────────────────────────
  // DEVICE IDENTIFICATION & CAPABILITY QUERIES
  // ──────────────────────────────────────────────────────────────────

  /// Identify which supported device the data is coming from based on
  /// the source name reported by Health Connect / HealthKit.
  SupportedDevice? identifyDevice(String? sourceName) {
    if (sourceName == null || sourceName.isEmpty) return null;
    final lower = sourceName.toLowerCase();

    for (final device in supportedDevices) {
      for (final pattern in device.sourcePatterns) {
        if (lower.contains(pattern)) return device;
      }
    }
    return null;
  }

  /// Get all supported devices for the current platform.
  static List<SupportedDevice> devicesForCurrentPlatform() {
    final isIOS = Platform.isIOS;
    return supportedDevices.where((d) {
      return d.platform == DevicePlatform.both ||
             (isIOS ? d.platform == DevicePlatform.ios : d.platform == DevicePlatform.android);
    }).toList();
  }

  /// Get the recommended device combo for full coverage on the current platform.
  /// Returns a list of devices that together cover all 15 data types.
  static List<SupportedDevice> recommendedSetup() {
    if (Platform.isIOS) {
      return supportedDevices.where((d) =>
        d.sourcePatterns.contains('com.apple.health') ||
        d.sourcePatterns.contains('libre')
      ).toList();
    } else {
      return supportedDevices.where((d) =>
        d.sourcePatterns.contains('samsung') ||
        d.sourcePatterns.contains('libre')
      ).toList();
    }
  }

  /// Check which data types are missing from the currently connected device
  /// and suggest companion devices that can fill the gaps.
  List<SupportedDevice> suggestCompanionDevices() {
    final missing = <String>{};
    final allMetrics = [
      'heartRate', 'restingHeartRate', 'hrv', 'bloodOxygen', 'steps',
      'sleep', 'calories', 'workout', 'weight', 'bloodPressure',
      'bodyTemperature', 'bloodGlucose', 'hydration',
    ];

    // Figure out which metrics we don't have data for
    for (final metric in allMetrics) {
      if (!_availableMetrics.contains(metric)) {
        missing.add(metric);
      }
    }

    if (missing.isEmpty) return [];

    // Find devices that provide the missing metrics
    final companions = <SupportedDevice>[];
    final currentPlatform = Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android;

    for (final device in supportedDevices) {
      if (device.platform != DevicePlatform.both && device.platform != currentPlatform) continue;
      // Skip if same as current device
      if (_detectedDevice != null && device.sourcePatterns.any(
        (p) => _detectedDevice!.toLowerCase().contains(p)
      )) continue;

      final fills = missing.where((m) => device.capabilities[m] == true).toList();
      if (fills.isNotEmpty) {
        companions.add(device);
      }
    }

    return companions;
  }

  /// Get a human-readable summary of data coverage from the current device.
  Map<String, dynamic> getDataCoverageReport() {
    final matched = identifyDevice(_detectedDevice);
    final total = 15; // Total data types we read
    final available = _availableMetrics.length;
    final missing = <String>[];

    final expectedMetrics = [
      'heartRate', 'restingHeartRate', 'heartRateVariability', 'glucose',
      'bloodOxygen', 'bodyTemperature', 'weight', 'bloodPressureSystolic',
      'bloodPressureDiastolic', 'stepsToday', 'caloriesBurned',
      'hydrationLiters', 'sleepHours', 'sleepQuality', 'workoutMinutesToday',
    ];

    for (final m in expectedMetrics) {
      if (!_availableMetrics.contains(m)) missing.add(m);
    }

    return {
      'detectedDevice': _detectedDevice,
      'matchedDevice': matched?.name ?? 'Unknown device',
      'category': matched?.category.label ?? 'Unknown',
      'platform': Platform.isIOS ? 'iOS (HealthKit)' : 'Android (Health Connect)',
      'coveragePercent': total > 0 ? ((available / total) * 100).round() : 0,
      'availableMetrics': _availableMetrics.toList(),
      'missingMetrics': missing,
      'deviceNotes': matched?.notes,
      'companionSuggestions': suggestCompanionDevices().map((d) => d.name).toList(),
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUPPORTING MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum DevicePlatform { android, ios, both }

enum DeviceCategory {
  smartwatch('Smartwatch'),
  fitnessTracker('Fitness Tracker'),
  smartRing('Smart Ring'),
  cgm('Continuous Glucose Monitor'),
  bpMonitor('Blood Pressure Monitor'),
  scale('Smart Scale');

  final String label;
  const DeviceCategory(this.label);
}

class SupportedDevice {
  final String name;
  final DevicePlatform platform;
  final DeviceCategory category;
  final List<String> sourcePatterns;
  final Map<String, bool> capabilities;
  final String notes;

  const SupportedDevice({
    required this.name,
    required this.platform,
    required this.category,
    required this.sourcePatterns,
    required this.capabilities,
    required this.notes,
  });

  /// Returns the list of metrics this device CAN provide.
  List<String> get supportedMetrics =>
      capabilities.entries.where((e) => e.value).map((e) => e.key).toList();

  /// Returns the list of metrics this device CANNOT provide.
  List<String> get unsupportedMetrics =>
      capabilities.entries.where((e) => !e.value).map((e) => e.key).toList();
}
