import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'epigenomic_models.dart';

class EpigenomicState {
  final bool isLoading;
  final EpigenomicDiffResult? diffResult;
  final String? error;

  const EpigenomicState({this.isLoading = false, this.diffResult, this.error});

  EpigenomicState copyWith({bool? isLoading, EpigenomicDiffResult? diffResult, String? error}) {
    return EpigenomicState(
      isLoading: isLoading ?? this.isLoading,
      diffResult: diffResult ?? this.diffResult,
      error: error,
    );
  }
}

class EpigenomicNotifier extends StateNotifier<EpigenomicState> {
  EpigenomicNotifier() : super(const EpigenomicState());

  Future<void> runDiffAnalysis() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(seconds: 2));

    final baseline = EpigenomicProfile(id: 'base1', dateAssayed: DateTime.now().subtract(const Duration(days: 180)), dunedinPACERate: 1.05, totalMethylationSitesAnalyzed: 850000, telomereLengthTiers: 4.2);
    final current = EpigenomicProfile(id: 'curr1', dateAssayed: DateTime.now(), dunedinPACERate: 0.82, totalMethylationSitesAnalyzed: 850000, telomereLengthTiers: 4.5);

    final result = EpigenomicDiffResult(
      baseline: baseline,
      current: current,
      paceDelta: -0.23,
      biologicalInterpretation: 'Massive deceleration in biological aging detected. DNA methylation patterns show a 23% reduction in the pace of aging (DunedinPACE). Epigenetic silencing of inflammatory loci (IL-6, TNF-alpha) confirmed at 4,200 CpG sites.',
    );

    state = state.copyWith(isLoading: false, diffResult: result);
  }
}

final epigenomicProvider = StateNotifierProvider<EpigenomicNotifier, EpigenomicState>((ref) => EpigenomicNotifier());
