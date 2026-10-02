import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/repositories/bio_arbitrage_repository.dart';
import '../../core/di/injection_container.dart';

class BioArbitrageState {
  final bool isLoading;
  final double? reversalRateScore;
  final double? proofOfReversalScore;
  final double? creditsEarned;
  final double? enterpriseValue;
  final List<AuditEntryEntity>? auditTrail;
  final String? error;

  const BioArbitrageState({this.isLoading = false, this.reversalRateScore, this.proofOfReversalScore, this.creditsEarned, this.enterpriseValue, this.auditTrail, this.error});

  BioArbitrageState copyWith({bool? isLoading, double? reversalRateScore, double? proofOfReversalScore, double? creditsEarned, double? enterpriseValue, List<AuditEntryEntity>? auditTrail, String? error}) {
    return BioArbitrageState(
      isLoading: isLoading ?? this.isLoading,
      reversalRateScore: reversalRateScore ?? this.reversalRateScore,
      proofOfReversalScore: proofOfReversalScore ?? this.proofOfReversalScore,
      creditsEarned: creditsEarned ?? this.creditsEarned,
      enterpriseValue: enterpriseValue ?? this.enterpriseValue,
      auditTrail: auditTrail ?? this.auditTrail,
      error: error,
    );
  }
}

class BioArbitrageNotifier extends StateNotifier<BioArbitrageState> {
  final BioArbitrageRepository repository;

  BioArbitrageNotifier({required this.repository}) : super(const BioArbitrageState());

  Future<void> loadArbitrage() async {
    state = state.copyWith(isLoading: true, error: null);
    
    final resultOrFailure = await repository.getArbitrageData();
    
    resultOrFailure.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (entity) {
        state = state.copyWith(
          isLoading: false,
          reversalRateScore: entity.reversalRateScore,
          proofOfReversalScore: entity.proofOfReversalScore,
          creditsEarned: entity.creditsEarned,
          enterpriseValue: entity.enterpriseValue,
          auditTrail: entity.auditTrail,
        );
      },
    );
  }
}

final bioArbitrageProvider = StateNotifierProvider<BioArbitrageNotifier, BioArbitrageState>((ref) {
  return BioArbitrageNotifier(repository: ref.watch(bioArbitrageRepositoryProvider));
});

