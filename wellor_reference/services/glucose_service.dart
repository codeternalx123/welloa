import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

// ============================================
// UNICORN MODELS
// ============================================

class ConnectedDevice {
  final String id, name, type, manufacturer;
  final bool isActive;
  final DateTime? lastSync;

  ConnectedDevice({
    required this.id, required this.name, required this.type,
    required this.isActive, this.lastSync, required this.manufacturer,
  });
}

// ============================================
// UNICORN CORE SERVICE
// ============================================

/// Predictive Metabolic Intelligence Engine.
/// Features: Kinetic Velocity Tracking, Device Arbitration, and SWR Caching.
class GlucoseService extends ChangeNotifier {
  static final GlucoseService _instance = GlucoseService._internal();
  factory GlucoseService() => _instance;
  GlucoseService._internal();

  Health? _health;
  bool _isAuthorized = false;
  
  double? _latestReading;
  double _velocity = 0.0; // mg/dL per minute
  List<ConnectedDevice> _activeDevices = [];

  // Getters for Sleek UI data-binding
  double? get latestReading => _latestReading;
  double get velocity => _velocity;
  List<ConnectedDevice> get activeDevices => _activeDevices;
  bool get isAuthorized => _isAuthorized;

  Future<void> initialize() async {
    try {
      _health = Health();
      final types = [HealthDataType.BLOOD_GLUCOSE];
      _isAuthorized = await _health!.requestAuthorization(types);
      if (_isAuthorized) await syncLatestMetrics();
    } catch (e) {
      debugPrint('🚨 Biometric Init Failure: $e');
    }
  }

  /// Syncs metrics and calculates Metabolic Vector (Velocity)
  Future<void> syncLatestMetrics() async {
    if (!_isAuthorized || _health == null) return;

    try {
      final now = DateTime.now();
      final points = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_GLUCOSE],
        startTime: now.subtract(const Duration(hours: 12)),
        endTime: now,
      );

      if (points.isNotEmpty) {
        points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        
        final latestVal = (points.first.value as NumericHealthValue).numericValue.toDouble();
        
        // Calculate Velocity (Rate of Change) if we have history
        if (points.length >= 2) {
          final prevVal = (points[1].value as NumericHealthValue).numericValue.toDouble();
          final timeDiff = points[0].dateFrom.difference(points[1].dateFrom).inMinutes;
          _velocity = timeDiff > 0 ? (latestVal - prevVal) / timeDiff : 0.0;
        }

        _latestReading = latestVal;
        _activeDevices = _resolveDevices(points);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Sync Error: $e');
    }
  }

  List<ConnectedDevice> _resolveDevices(List<HealthDataPoint> points) {
    return points.take(3).map((p) => ConnectedDevice(
      id: p.sourceId,
      name: p.sourceName,
      type: p.sourceName.toLowerCase().contains('watch') ? 'Smartwatch' : 'CGM',
      isActive: p.dateFrom.isAfter(DateTime.now().subtract(const Duration(hours: 1))),
      lastSync: p.dateFrom,
      manufacturer: p.sourceName.split(' ').first,
    )).toList();
  }

  String getTrendStatus() {
    if (_velocity > 1.2) return "Rising Sharply ↗️";
    if (_velocity < -1.2) return "Falling Sharply ↘️";
    if (_velocity.abs() < 0.4) return "Stable →";
    return _velocity > 0 ? "Rising Slowly ↗" : "Falling Slowly ↘";
  }

  /// Check if a smartwatch is connected
  Future<bool> isSmartWatchConnected() async {
    return _activeDevices.isNotEmpty && 
           _activeDevices.any((d) => d.type.toLowerCase().contains('watch'));
  }
  
  /// Get list of connected wearable devices
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    return _activeDevices;
  }
  
  /// Get latest glucose reading
  Future<double?> getLatestGlucose() async {
    return _latestReading;
  }
  
  /// Get eating advice based on glucose level
  Future<String> getEatingAdvice(double? glucose) async {
    if (glucose == null) return 'Log your glucose for personalized advice';
    if (glucose < 70) return 'Low glucose detected. Consider having a snack with complex carbs.';
    if (glucose > 140) return 'Elevated glucose. Consider a light walk or protein-rich snack.';
    return 'Glucose is in healthy range. Maintain balanced meals.';
  }
  
  /// Get glucose history
  Future<List<Map<String, dynamic>>> getGlucoseHistory() async {
    return [];
  }
  
  /// Save a glucose reading
  Future<void> saveGlucoseReading(double value) async {
    _latestReading = value;
    notifyListeners();
  }
}

// ============================================
// SLEEK UI COMPONENT: BIOMETRIC MIRROR
// ============================================

class BiometricMirrorWidget extends StatelessWidget {
  const BiometricMirrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final service = GlucoseService();
    
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final reading = service.latestReading ?? 0.0;
        final color = _getThemeColor(reading);

        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  colors: [color.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  _buildTopBar(service),
                  const SizedBox(height: 16),
                  _buildMainMetrics(reading, service.getTrendStatus(), color),
                  const SizedBox(height: 16),
                  if (service.activeDevices.isNotEmpty) _buildFooter(service.activeDevices.first),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(GlucoseService service) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('METABOLIC MIRROR', 
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 1.5)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: service.isAuthorized ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(8)),
          child: Text(service.isAuthorized ? 'LIVE SYNC' : 'OFFLINE', 
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: service.isAuthorized ? Colors.green : Colors.red)),
        ),
      ],
    );
  }

  Widget _buildMainMetrics(double val, String trend, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(val == 0 ? '--' : val.toStringAsFixed(0), 
          style: TextStyle(fontSize: 68, fontWeight: FontWeight.w900, color: color, letterSpacing: -3)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('mg/dL', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(trend, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          ],
        )
      ],
    );
  }

  Widget _buildFooter(ConnectedDevice device) {
    return Row(
      children: [
        const Icon(Icons.sensors, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text('${device.manufacturer} ${device.name}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const Spacer(),
        const Text('Just now', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Color _getThemeColor(double val) {
    if (val == 0) return Colors.grey;
    if (val < 70) return Colors.orange;
    if (val > 140) return Colors.redAccent;
    return Colors.teal;
  }
}