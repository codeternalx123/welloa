import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/causal_insight_entity.dart';
import '../../domain/usecases/run_interventional_query.dart';
import '../../data/repositories/causal_repository_impl.dart';
import '../../data/datasources/causal_local_data_source.dart';
import '../../data/datasources/causal_remote_data_source.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/providers/health_provider.dart';
import '../../../../core/models/causal_insight.dart';

// Dependency Injection Setup
final causalClaudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());

final causalLocalDataSourceProvider = Provider<CausalLocalDataSource>(
  (ref) => CausalLocalDataSourceImpl(),
);

final causalRemoteDataSourceProvider = Provider<CausalRemoteDataSource>(
  (ref) => CausalRemoteDataSourceImpl(aiService: ref.read(causalClaudeServiceProvider)),
);

final causalRepositoryProvider = Provider<CausalRepositoryImpl>(
  (ref) => CausalRepositoryImpl(
    remoteDataSource: ref.read(causalRemoteDataSourceProvider),
    localDataSource: ref.read(causalLocalDataSourceProvider),
  ),
);

final runAdjustmentalQueryUseCaseProvider = Provider<RunAdjustmentalQueryUseCase>(
  (ref) => RunAdjustmentalQueryUseCase(ref.read(causalRepositoryProvider)),
);

class CausalDDDState {
  final AsyncValue<CausalInsightEntity> insight;
  final int selectedPreset;

  CausalDDDState({required this.insight, required this.selectedPreset});

  CausalDDDState copyWith({AsyncValue<CausalInsightEntity>? insight, int? selectedPreset}) {
    return CausalDDDState(
      insight: insight ?? this.insight,
      selectedPreset: selectedPreset ?? this.selectedPreset,
    );
  }
}

class CausalDDDNotifier extends StateNotifier<CausalDDDState> {
  final RunAdjustmentalQueryUseCase queryUseCase;

  CausalDDDNotifier(this.queryUseCase) : super(CausalDDDState(insight: const AsyncValue.loading(), selectedPreset: 0));

  void selectPreset(int index, HealthData? healthData) {
    state = state.copyWith(selectedPreset: index);
    runQuery(index, healthData);
  }

  Future<void> runQuery(int index, HealthData? healthData) async {
    // 1. Try to load offline cache to prevent loading UI
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'causal_preset_$index';
    final cachedData = prefs.getString(cacheKey);
    
    if (cachedData != null) {
      try {
        final decoded = jsonDecode(cachedData);
        final result = CausalInsightResult.fromJson(decoded);
        final entity = CausalInsightEntity(
          id: result.id,
          analyzedAt: result.analyzedAt,
          inputVariables: result.inputVariables,
          outcome: result.outcome,
          causalConfidence: result.causalConfidence,
          doOperatorQuery: result.doOperatorQuery,
          counterfactuals: result.counterfactuals,
          narrative: result.narrative,
        );
        state = state.copyWith(insight: AsyncValue.data(entity));
      } catch (_) {}
    } else {
      state = state.copyWith(insight: const AsyncValue.loading());
    }

    final result = await queryUseCase.execute(index, healthData);
    
    result.fold(
      (failure) {
        if (!state.insight.hasValue) {
          state = state.copyWith(insight: AsyncValue.error(failure.message, StackTrace.current));
        }
      },
      (entity) async {
        // Save to offline cache
        final resultToCache = CausalInsightResult(
          id: entity.id,
          analyzedAt: entity.analyzedAt,
          inputVariables: entity.inputVariables,
          outcome: entity.outcome,
          causalConfidence: entity.causalConfidence,
          doOperatorQuery: entity.doOperatorQuery,
          counterfactuals: entity.counterfactuals,
          narrative: entity.narrative,
        );
        await prefs.setString(cacheKey, resultToCache.toJsonString());
        state = state.copyWith(insight: AsyncValue.data(entity));
      },
    );
  }
}

final causalDDDNotifierProvider = StateNotifierProvider<CausalDDDNotifier, CausalDDDState>(
  (ref) => CausalDDDNotifier(ref.read(runAdjustmentalQueryUseCaseProvider)),
);
