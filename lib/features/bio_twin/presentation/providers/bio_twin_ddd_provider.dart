import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/bio_twin_repository.dart';
import '../../domain/entities/bio_twin_entity.dart';
import '../../domain/usecases/compile_bio_twin.dart';
import '../../data/repositories/bio_twin_repository_impl.dart';
import '../../data/datasources/bio_twin_local_data_source.dart';
import '../../data/datasources/bio_twin_remote_data_source.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/services/health_service.dart';
import '../../../../core/di/injection_container.dart';

// Dependency Injection Nodes
final btClaudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());
final btHealthServiceProvider = Provider((ref) => HealthService());

final btLocalDataSourceProvider = Provider<BioTwinLocalDataSource>(
  (ref) => BioTwinLocalDataSourceImpl(dao: ref.read(bioTwinDaoProvider)),
);

final btRemoteDataSourceProvider = Provider<BioTwinRemoteDataSource>(
  (ref) => BioTwinRemoteDataSourceImpl(aiService: ref.read(btClaudeServiceProvider)),
);

final bioTwinRepositoryProvider = Provider<BioTwinRepositoryImpl>(
  (ref) => BioTwinRepositoryImpl(
    remoteDataSource: ref.read(btRemoteDataSourceProvider),
    localDataSource: ref.read(btLocalDataSourceProvider),
  ),
);

final compileTwinUseCaseProvider = Provider<CompileBioTwinUseCase>(
  (ref) => CompileBioTwinUseCase(ref.read(bioTwinRepositoryProvider)),
);

class BioTwinDDDNotifier extends StateNotifier<AsyncValue<BioTwinEntity>> {
  final CompileBioTwinUseCase compileUseCase;
  final BioTwinRepository repository;
  final HealthService healthService;

  BioTwinDDDNotifier({
    required this.compileUseCase, 
    required this.repository,
    required this.healthService,
  }) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final cached = await repository.getLatestCompiledTwin();
    cached.fold(
      (failure) => executeCompilationPipeline(), // no cache, run AI
      (twin) => state = AsyncValue.data(twin),   // load instantly
    );
  }

  Future<void> executeCompilationPipeline({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    
    // Simulate fetching complex biometrics from OS
    final biometrics = await healthService.getFullBiometrics();
    
    final result = await compileUseCase.execute(chronoAge: 38.5, biometrics: biometrics);
    
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (twinEntity) => state = AsyncValue.data(twinEntity),
    );
  }
}

final bioTwinDDDNotifierProvider = StateNotifierProvider<BioTwinDDDNotifier, AsyncValue<BioTwinEntity>>(
  (ref) => BioTwinDDDNotifier(
    compileUseCase: ref.read(compileTwinUseCaseProvider),
    repository: ref.read(bioTwinRepositoryProvider),
    healthService: ref.read(btHealthServiceProvider),
  ),
);
