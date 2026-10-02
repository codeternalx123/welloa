import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/providers/health_provider.dart';
import '../../../../core/providers/dna_provider.dart';
import '../../../../core/providers/sleep_provider.dart';

final dynamicUnicornClaudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());

class DynamicUnicornNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final String domain;
  final ClaudeService claudeService;
  final AsyncValue<HealthData> healthState;
  final DnaData dnaData;
  final SleepData sleepData;

  DynamicUnicornNotifier(this.domain, this.claudeService, this.healthState, this.dnaData, this.sleepData) : super(const AsyncValue.loading()) {
    _generateInsights();
  }

  Future<void> _generateInsights() async {
    // 1. Load offline cache immediately to prevent loading UI
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'unicorn_insights_v5_$domain';
    final cachedData = prefs.getString(cacheKey);
    
    if (cachedData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final cachedInsights = List<Map<String, dynamic>>.from(decoded.map((x) => Map<String, dynamic>.from(x)));
        state = AsyncValue.data(cachedInsights);
      } catch (_) {}
    } else {
      state = const AsyncValue.loading();
    }
    
    final data = healthState.valueOrNull ?? HealthData();
    
    try {
      final insights = await claudeService.generateUnicornInsights(
        domain: domain,
        healthData: {
          'steps': data.steps,
          'activeEnergy': data.activeEnergy,
          'sleepMinutes': data.sleepMinutes,
          'isAuthorized': data.isAuthorized,
        },
        dnaData: {
          'mthfr': dnaData.mthfr,
          'actn3': dnaData.actn3,
          'apoe4': dnaData.apoe4,
          'fto': dnaData.fto,
        },
        sleepData: {
          'totalSleep': sleepData.totalSleep,
          'remDensity': sleepData.remDensity,
          'deepSleepLatency': sleepData.deepSleepLatency,
        },
      );
      
      // Save offline
      await prefs.setString(cacheKey, jsonEncode(insights));
      
      state = AsyncValue.data(insights);
    } catch (e, stack) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}

final dynamicUnicornProvider = StateNotifierProvider.family<DynamicUnicornNotifier, AsyncValue<List<Map<String, dynamic>>>, String>((ref, domain) {
  final claudeService = ref.watch(dynamicUnicornClaudeServiceProvider);
  final healthState = ref.watch(healthDataProvider);
  final dnaData = ref.watch(dnaDataProvider);
  final sleepData = ref.watch(sleepDataProvider);
  
  return DynamicUnicornNotifier(domain, claudeService, healthState, dnaData, sleepData);
});
