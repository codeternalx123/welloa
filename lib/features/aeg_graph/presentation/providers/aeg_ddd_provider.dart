import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/aeg_synthesis_entity.dart';
import '../../domain/usecases/synthesize_network.dart';
import '../../data/repositories/aeg_repository_impl.dart';
import '../../data/datasources/aeg_local_data_source.dart';
import '../../data/datasources/aeg_remote_data_source.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/di/injection_container.dart';

// Dependency Injection Setup
final aegClaudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());

final aegLocalDataSourceProvider = Provider<AEGLocalDataSource>(
  (ref) => AEGLocalDataSourceImpl(dao: ref.read(aegGraphDaoProvider)),
);

final aegRemoteDataSourceProvider = Provider<AEGRemoteDataSource>(
  (ref) => AEGRemoteDataSourceImpl(aiService: ref.read(aegClaudeServiceProvider)),
);

final aegRepositoryProvider = Provider<AEGRepositoryImpl>(
  (ref) => AEGRepositoryImpl(
    remoteDataSource: ref.read(aegRemoteDataSourceProvider),
    localDataSource: ref.read(aegLocalDataSourceProvider),
  ),
);

final synthesizeNetworkUseCaseProvider = Provider<SynthesizeNetworkUseCase>(
  (ref) => SynthesizeNetworkUseCase(ref.read(aegRepositoryProvider)),
);

class AEGDDDNotifier extends StateNotifier<AsyncValue<AEGSynthesisEntity>> {
  final SynthesizeNetworkUseCase synthesizeUseCase;

  AEGDDDNotifier(this.synthesizeUseCase) : super(const AsyncValue.loading()) {
    triggerSynthesis();
  }

  Future<void> triggerSynthesis() async {
    state = const AsyncValue.loading();
    final result = await synthesizeUseCase.execute();
    
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (entity) => state = AsyncValue.data(entity),
    );
  }
}

final aegDDDNotifierProvider = StateNotifierProvider<AEGDDDNotifier, AsyncValue<AEGSynthesisEntity>>(
  (ref) => AEGDDDNotifier(ref.read(synthesizeNetworkUseCaseProvider)),
);
