import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/bio_twin.dart';
import '../../core/di/injection_container.dart';
import 'domain/repositories/bio_twin_repository.dart';

class BioTwinState {
  final bool isLoading;
  final BioTwinResult? result;
  final String? error;
  
  const BioTwinState({this.isLoading = false, this.result, this.error});
  
  BioTwinState copyWith({bool? isLoading, BioTwinResult? result, String? error}) {
    return BioTwinState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
    );
  }
}

class BioTwinNotifier extends StateNotifier<BioTwinState> {
  final BioTwinRepository repository;

  BioTwinNotifier({required this.repository}) : super(const BioTwinState());

  Future<void> compileTwin({required double chronoAge, required Map<String, dynamic> biometrics}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final resultOrFailure = await repository.compileAndCacheBioTwin(chronoAge, biometrics);
    
    resultOrFailure.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (entity) {
        // Map Entity to Result representation (since UI likely expects BioTwinResult for now)
        final result = BioTwinResult(
          id: entity.id,
          compiledAt: entity.compiledAt,
          chronologicalAge: entity.chronologicalAge,
          biologicalAge: entity.biologicalAge,
          ageGap: entity.ageGap,
          reversalRateMonthsPerYear: entity.reversalRateMonthsPerYear,
          trajectory: entity.trajectory,
          hallmarkScores: entity.hallmarkScores,
          keyBioMarkers: entity.keyBioMarkers,
          sixMonthProjection: entity.sixMonthProjection,
        );
        state = state.copyWith(isLoading: false, result: result);
      },
    );
  }
}

final bioTwinProvider = StateNotifierProvider<BioTwinNotifier, BioTwinState>((ref) {
  return BioTwinNotifier(repository: ref.watch(bioTwinRepositoryProvider));
});

