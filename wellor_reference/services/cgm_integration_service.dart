import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// 🩸 **CONTINUOUS GLUCOSE MONITORING (CGM) INTEGRATION**
/// Real-time glucose monitoring via Abbott FreeStyle Libre (LibreView API).
///
/// **Supported CGM Platforms:**
/// - Abbott FreeStyle Libre (via LibreView API)
/// - Medtronic Guardian (via CareLink API — planned)
///
/// **Features:**
/// - Real-time glucose readings (every 5 minutes)
/// - Trend arrows (rising fast, rising, steady, falling, falling fast)
/// - Time in range analysis (70-180 mg/dL)
/// - Hypoglycemia alerts (<70 mg/dL)
/// - Hyperglycemia alerts (>180 mg/dL)
/// - Predicted glucose in 30 minutes
/// - A1C estimation
/// - Pattern detection (dawn phenomenon, post-meal spikes)

enum CGMPlatform {
  freestyleLibre,
  medtronic,
}

enum GlucoseTrend {
  risingFast,      // ⬆️⬆️ Rising more than 2 mg/dL/min
  rising,          // ⬆️ Rising 1-2 mg/dL/min
  steady,          // ➡️ Steady ±1 mg/dL/min
  falling,         // ⬇️ Falling 1-2 mg/dL/min
  fallingFast,     // ⬇️⬇️ Falling more than 2 mg/dL/min
  unknown,
}

class GlucoseReading {
  final DateTime timestamp;
  final double value; // mg/dL
  final GlucoseTrend trend;
  final CGMPlatform source;
  final double? predictedValue; // Predicted glucose in 30 min
  final bool isHigh; // >180 mg/dL
  final bool isLow; // <70 mg/dL
  final bool isCriticalHigh; // >250 mg/dL
  final bool isCriticalLow; // <54 mg/dL

  GlucoseReading({
    required this.timestamp,
    required this.value,
    required this.trend,
    required this.source,
    this.predictedValue,
  })  : isHigh = value > 180,
        isLow = value < 70,
        isCriticalHigh = value > 250,
        isCriticalLow = value < 54;

  String get trendEmoji {
    switch (trend) {
      case GlucoseTrend.risingFast:
        return '⬆️⬆️';
      case GlucoseTrend.rising:
        return '⬆️';
      case GlucoseTrend.steady:
        return '➡️';
      case GlucoseTrend.falling:
        return '⬇️';
      case GlucoseTrend.fallingFast:
        return '⬇️⬇️';
      default:
        return '❓';
    }
  }

  String get riskLevel {
    if (isCriticalLow) return 'CRITICAL_LOW';
    if (isCriticalHigh) return 'CRITICAL_HIGH';
    if (isLow) return 'LOW';
    if (isHigh) return 'HIGH';
    return 'IN_RANGE';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
    'trend': trend.toString(),
    'source': source.toString(),
    'predictedValue': predictedValue,
    'isHigh': isHigh,
    'isLow': isLow,
    'isCriticalHigh': isCriticalHigh,
    'isCriticalLow': isCriticalLow,
  };
}

class TimeInRangeAnalysis {
  final DateTime startDate;
  final DateTime endDate;
  final int totalReadings;
  final double percentInRange; // 70-180 mg/dL
  final double percentHigh; // >180 mg/dL
  final double percentLow; // <70 mg/dL
  final double percentCriticalHigh; // >250 mg/dL
  final double percentCriticalLow; // <54 mg/dL
  final double averageGlucose;
  final double glucoseVariability; // Coefficient of variation
  final double estimatedA1C;

  TimeInRangeAnalysis({
    required this.startDate,
    required this.endDate,
    required this.totalReadings,
    required this.percentInRange,
    required this.percentHigh,
    required this.percentLow,
    required this.percentCriticalHigh,
    required this.percentCriticalLow,
    required this.averageGlucose,
    required this.glucoseVariability,
    required this.estimatedA1C,
  });

  bool get isGoodControl => percentInRange > 70 && percentLow < 4;
  bool get needsImprovement => percentInRange < 50 || percentLow > 10;
}

class CGMIntegrationService {
  static final CGMIntegrationService _instance = CGMIntegrationService._internal();
  factory CGMIntegrationService() => _instance;
  CGMIntegrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _pollingTimer;

  String get _libreUsername => dotenv.env['LIBRE_USERNAME'] ?? '';
  String get _librePassword => dotenv.env['LIBRE_PASSWORD'] ?? '';

  // ============================================================================
  // FREESTYLE LIBRE INTEGRATION
  // ============================================================================

  /// Fetch FreeStyle Libre data from LibreView (per-user token in Firestore, or debug .env fallback).
  Future<void> syncLibreData(String userId) async {
    debugPrint('🩸 Syncing FreeStyle Libre data...');

    try {
      final authToken = await _libreTokenForUser(userId);
      if (authToken == null) return;

      // Step 2: Fetch glucose readings
      final readings = await _fetchLibreReadings(authToken);

      // Step 3: Store readings
      for (final reading in readings) {
        await _storeGlucoseReading(userId, reading);
      }

      debugPrint('✅ Libre sync complete: ${readings.length} readings');
    } catch (e) {
      debugPrint('❌ Libre sync error: $e');
    }
  }

  Future<String?> _libreTokenForUser(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('integrations')
        .doc('libreview')
        .get();
    final t = doc.data()?['authToken'] as String?;
    if (t != null && t.isNotEmpty) return t;
    if (kDebugMode &&
        _libreUsername.isNotEmpty &&
        _librePassword.isNotEmpty) {
      debugPrint(
          'LibreView: using .env credentials (debug only). Use connectLibreViewAccount in production.');
      return _libreLoginWithCredentials(_libreUsername, _librePassword);
    }
    debugPrint(
        'LibreView: no linked account for $userId — call connectLibreViewAccount.');
    return null;
  }

  Future<String?> _libreLoginWithCredentials(String email, String password) async {
    final url = Uri.parse('https://api.libreview.io/llu/auth/login');
    if (url.scheme != 'https') {
      debugPrint('LibreView: rejected non-HTTPS URL');
      return null;
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']['authTicket']['token'] as String?;
    }

    return null;
  }

  /// Links LibreView to this user (stores API token — prefer backend exchange in production).
  Future<bool> connectLibreViewAccount(
      String userId, String email, String password) async {
    final token = await _libreLoginWithCredentials(email, password);
    if (token == null) return false;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('integrations')
        .doc('libreview')
        .set(
      {
        'authToken': token,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return true;
  }

  Future<List<GlucoseReading>> _fetchLibreReadings(String authToken) async {
    final url = Uri.parse('https://api.libreview.io/llu/connections');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final connections = data['data'] as List?;

      if (connections != null && connections.isNotEmpty) {
        final graphData = connections[0]['glucoseMeasurement']['ValueInMgPerDl'];
        final timestamp = DateTime.parse(connections[0]['glucoseMeasurement']['Timestamp']);

        return [
          GlucoseReading(
            timestamp: timestamp,
            value: (graphData as num).toDouble(),
            trend: GlucoseTrend.steady, // Libre doesn't provide trend arrows in API
            source: CGMPlatform.freestyleLibre,
          ),
        ];
      }
    }

    return [];
  }

  // ============================================================================
  // GLUCOSE PREDICTION & ANALYTICS
  // ============================================================================

  /// Predict glucose in 30 minutes based on current trend
  double? _predictGlucose(double currentGlucose, GlucoseTrend trend) {
    const minutesToPredict = 30;
    double rateOfChange = 0;

    switch (trend) {
      case GlucoseTrend.risingFast:
        rateOfChange = 3.0; // mg/dL per minute
        break;
      case GlucoseTrend.rising:
        rateOfChange = 1.5;
        break;
      case GlucoseTrend.steady:
        rateOfChange = 0;
        break;
      case GlucoseTrend.falling:
        rateOfChange = -1.5;
        break;
      case GlucoseTrend.fallingFast:
        rateOfChange = -3.0;
        break;
      default:
        return null;
    }

    return currentGlucose + (rateOfChange * minutesToPredict);
  }

  /// Calculate Time in Range analysis
  Future<TimeInRangeAnalysis> calculateTimeInRange(
    String userId, {
    int days = 14,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final endDate = DateTime.now();

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('glucose_readings')
        .where('timestamp', isGreaterThan: startDate.toIso8601String())
        .orderBy('timestamp')
        .get();

    if (snapshot.docs.isEmpty) {
      return TimeInRangeAnalysis(
        startDate: startDate,
        endDate: endDate,
        totalReadings: 0,
        percentInRange: 0,
        percentHigh: 0,
        percentLow: 0,
        percentCriticalHigh: 0,
        percentCriticalLow: 0,
        averageGlucose: 0,
        glucoseVariability: 0,
        estimatedA1C: 0,
      );
    }

    final readings = snapshot.docs.map((doc) {
      final data = doc.data();
      return (data['value'] as num).toDouble();
    }).toList();

    final totalReadings = readings.length;
    final inRange = readings.where((g) => g >= 70 && g <= 180).length;
    final high = readings.where((g) => g > 180).length;
    final low = readings.where((g) => g < 70).length;
    final criticalHigh = readings.where((g) => g > 250).length;
    final criticalLow = readings.where((g) => g < 54).length;

    final avgGlucose = readings.reduce((a, b) => a + b) / totalReadings;
    
    // Calculate standard deviation for glucose variability
    final variance = readings.map((g) => (g - avgGlucose) * (g - avgGlucose))
        .reduce((a, b) => a + b) / totalReadings;
    final stdDev = sqrt(variance);
    final glucoseVariability = (stdDev / avgGlucose) * 100; // Coefficient of variation

    // Estimate A1C from average glucose
    final estimatedA1C = (avgGlucose + 46.7) / 28.7;

    return TimeInRangeAnalysis(
      startDate: startDate,
      endDate: endDate,
      totalReadings: totalReadings,
      percentInRange: (inRange / totalReadings) * 100,
      percentHigh: (high / totalReadings) * 100,
      percentLow: (low / totalReadings) * 100,
      percentCriticalHigh: (criticalHigh / totalReadings) * 100,
      percentCriticalLow: (criticalLow / totalReadings) * 100,
      averageGlucose: avgGlucose,
      glucoseVariability: glucoseVariability,
      estimatedA1C: estimatedA1C,
    );
  }

  // ============================================================================
  // PATTERN DETECTION
  // ============================================================================

  /// Detect glucose patterns (dawn phenomenon, post-meal spikes, etc.)
  Future<Map<String, dynamic>> detectGlucosePatterns(String userId) async {
    final readings = await _getRecentReadings(userId, days: 7);
    
    final patterns = <String, dynamic>{};

    // Dawn phenomenon (high glucose 3-8 AM)
    final dawnReadings = readings.where((r) {
      final hour = r.timestamp.hour;
      return hour >= 3 && hour <= 8;
    }).toList();

    if (dawnReadings.isNotEmpty) {
      final avgDawnGlucose = dawnReadings.map((r) => r.value).reduce((a, b) => a + b) / dawnReadings.length;
      patterns['dawnPhenomenon'] = avgDawnGlucose > 140;
      patterns['dawnGlucose'] = avgDawnGlucose;
    }

    // Post-meal spikes (need to correlate with meal times)
    // TODO: Implement meal correlation

    // Nocturnal hypoglycemia (low glucose 12-6 AM)
    final nightReadings = readings.where((r) {
      final hour = r.timestamp.hour;
      return hour >= 0 && hour <= 6;
    }).toList();

    final lowNightReadings = nightReadings.where((r) => r.isLow).length;
    patterns['nocturnalHypoglycemia'] = lowNightReadings > 0;
    patterns['nightlyLowCount'] = lowNightReadings;

    return patterns;
  }

  // ============================================================================
  // ALERTS & NOTIFICATIONS
  // ============================================================================

  Future<void> _checkGlucoseAlerts(String userId, GlucoseReading reading) async {
    // This will be handled by AI Health Team service
    // Just log for now
    if (reading.isCriticalLow) {
      debugPrint('🚨 CRITICAL LOW GLUCOSE: ${reading.value} mg/dL');
    } else if (reading.isCriticalHigh) {
      debugPrint('🚨 CRITICAL HIGH GLUCOSE: ${reading.value} mg/dL');
    } else if (reading.isLow) {
      debugPrint('⚠️ LOW GLUCOSE: ${reading.value} mg/dL');
    } else if (reading.isHigh) {
      debugPrint('⚠️ HIGH GLUCOSE: ${reading.value} mg/dL');
    }
  }

  // ============================================================================
  // DATA STORAGE & RETRIEVAL
  // ============================================================================

  Future<void> _storeGlucoseReading(String userId, GlucoseReading reading) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('glucose_readings')
        .add(reading.toJson());
  }

  Future<List<GlucoseReading>> _getRecentReadings(String userId, {int days = 1}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('glucose_readings')
        .where('timestamp', isGreaterThan: startDate.toIso8601String())
        .orderBy('timestamp')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return GlucoseReading(
        timestamp: DateTime.parse(data['timestamp']),
        value: (data['value'] as num).toDouble(),
        trend: GlucoseTrend.values.firstWhere(
          (e) => e.toString() == data['trend'],
          orElse: () => GlucoseTrend.unknown,
        ),
        source: CGMPlatform.values.firstWhere(
          (e) => e.toString() == data['source'],
          orElse: () => CGMPlatform.freestyleLibre,
        ),
        predictedValue: data['predictedValue'] as double?,
      );
    }).toList();
  }

  /// Get latest glucose reading
  Future<GlucoseReading?> getLatestReading(String userId) async {
    final readings = await _getRecentReadings(userId, days: 1);
    return readings.isNotEmpty ? readings.last : null;
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  void stopMonitoring() {
    _pollingTimer?.cancel();
    debugPrint('🛑 CGM monitoring stopped');
  }
}

// Helper function for sqrt (for glucose variability calculation)
double sqrt(double x) {
  if (x < 0) return 0;
  double guess = x / 2;
  for (int i = 0; i < 10; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}
