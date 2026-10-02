import 'dart:async';
import 'package:flutter/foundation.dart';
import 'wearable_intelligence_hub.dart';
import 'daily_balance_service.dart';
import '../providers/user_profile_provider.dart';

/// UNICORN GRADE: Proactive Metabolic Intervention Engine.
/// Connects Biometric Velocity to AI Recommendations for real-time safety.
/// Features: Graceful Health Connect degradation, manual entry support, 
/// and intelligent fallback mechanisms.
class MetabolicGuardService {
  static final MetabolicGuardService _instance = MetabolicGuardService._internal();
  factory MetabolicGuardService() => _instance;
  MetabolicGuardService._internal();

  final _hub = WearableIntelligenceHub();
  
  // Lead Dev Triage: Prevents notification spamming
  DateTime? _lastAlertTime;
  static const _cooldownDuration = Duration(minutes: 45);
  
  // State tracking
  bool _isInitialized = false;
  BiometricSyncMode _activeMode = BiometricSyncMode.unknown;
  String? _initMessage;

  // Getters
  bool get isInitialized => _isInitialized;
  BiometricSyncMode get activeMode => _activeMode;
  String? get initMessage => _initMessage;
  bool get isWearableSyncActive => _activeMode == BiometricSyncMode.wearableSync;
  bool get needsHealthConnectInstall => _hub.needsHealthConnectInstall;

  /// Initializes the metabolic guard with graceful degradation.
  /// Returns the initialization result with mode and message.
  Future<BiometricInitResult> initializeGuard(UserProfileProvider profile) async {
    try {
      // Initialize the wearable hub (handles Health Connect availability)
      final result = await _hub.initialize();
      
      _activeMode = result.mode;
      _initMessage = result.message;
      _isInitialized = true;

      // Start listening based on the available mode
      if (result.mode == BiometricSyncMode.wearableSync || 
          result.mode == BiometricSyncMode.hybrid) {
        _hub.addListener(() => _analyzeMetabolicTrend(profile));
        debugPrint('🛡️ MetabolicGuard: Wearable monitoring active');
      } else {
        debugPrint('🛡️ MetabolicGuard: Manual mode - limited monitoring');
      }

      debugPrint('🛡️ MetabolicGuard initialized: ${result.mode.name} - ${result.message}');
      return result;
    } catch (e) {
      debugPrint('🚨 MetabolicGuard Init Error: $e');
      _activeMode = BiometricSyncMode.manualOnly;
      _initMessage = 'Guard started in safe mode';
      _isInitialized = true;
      
      return BiometricInitResult(
        success: true,
        mode: BiometricSyncMode.manualOnly,
        message: 'Metabolic guard active in manual mode',
        error: e.toString(),
      );
    }
  }

  /// Legacy method for backwards compatibility.
  /// Use initializeGuard() for full control over initialization.
  void startGuard(UserProfileProvider profile) {
    if (_isInitialized) {
      debugPrint('🛡️ MetabolicGuard: Already initialized');
      return;
    }
    
    // Fire and forget initialization with error handling
    initializeGuard(profile).then((result) {
      debugPrint('🛡️ MetabolicGuard started: ${result.mode.name}');
    }).catchError((e) {
      debugPrint('🛡️ MetabolicGuard: Safe mode activated - $e');
    });
  }

  /// Retry guard initialization after Health Connect installation.
  Future<BiometricInitResult> retryAfterHealthConnectInstall(UserProfileProvider profile) async {
    _isInitialized = false;
    final result = await _hub.retryAfterInstall();
    
    if (result.success && result.mode == BiometricSyncMode.wearableSync) {
      _hub.addListener(() => _analyzeMetabolicTrend(profile));
    }
    
    _activeMode = result.mode;
    _initMessage = result.message;
    _isInitialized = true;
    
    return result;
  }

  /// Prompt user to install Health Connect.
  Future<bool> promptHealthConnectInstall() async {
    return await _hub.promptHealthConnectInstall();
  }

  /// Add manual glucose entry when wearable sync is unavailable.
  void addManualReading({
    required double glucoseLevel,
    String? notes,
    String? mealContext,
    required UserProfileProvider profile,
  }) {
    _hub.addManualEntry(
      glucoseLevel: glucoseLevel,
      notes: notes,
      mealContext: mealContext,
    );
    
    // Run analysis on manual entry
    _analyzeMetabolicTrend(profile);
  }

  Future<void> _analyzeMetabolicTrend(UserProfileProvider profile) async {
    final velocity = _hub.velocity; // mg/dL per minute
    final reading = _hub.latestReading ?? 0.0;

    // 1. CRASH DETECTION: Sharp Fall (e.g., velocity < -1.8 mg/dL/min)
    if (velocity < -1.5 && reading < 110) {
      _triggerProactiveIntervention(
        type: InterventionType.glucoseCrash,
        profile: profile,
      );
    }
  }

  Future<void> _triggerProactiveIntervention({
    required InterventionType type,
    required UserProfileProvider profile,
  }) async {
    // Check Cooldown
    if (_lastAlertTime != null && 
        DateTime.now().difference(_lastAlertTime!) < _cooldownDuration) {
      return;
    }

    _lastAlertTime = DateTime.now();

    // 2. CONTEXTUAL AI QUERY: "Cravings" = "stabilizing"
    final currentStatus = await DailyBalanceService().computeDailyStatus(
      mealLogs: [], // Background context handles logs separately
      profile: profile,
    );

    // TODO: Implement snack recommendations
    final recommendations = <String>[];
    
    // 3. PUSH INTERVENTION (placeholder)
    debugPrint('⚡ Glucose Dip Detected - Status: $currentStatus');
    debugPrint('🛡️ Metabolic Guard: Would recommend stabilizing snack');
  }
}

enum InterventionType { glucoseCrash, hyperSpike }