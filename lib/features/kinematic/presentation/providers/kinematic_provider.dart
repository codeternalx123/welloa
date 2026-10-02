import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/kinematic_dose.dart';
import '../../domain/usecases/calculate_optimal_dose.dart';
import '../../data/repositories/kinematic_repository_impl.dart';
import '../../data/datasources/kinematic_local_data_source.dart';
import '../../data/datasources/kinematic_remote_data_source.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/services/health_service.dart';

// Dependency Injection Setup (Provider Graph)
final claudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());
final healthServiceProvider = Provider((ref) => HealthService());

final localDataSourceProvider = Provider<KinematicLocalDataSource>(
  (ref) => KinematicLocalDataSourceImpl(),
);

final remoteDataSourceProvider = Provider<KinematicRemoteDataSource>(
  (ref) => KinematicRemoteDataSourceImpl(
    aiService: ref.read(claudeServiceProvider),
    healthService: ref.read(healthServiceProvider),
  ),
);

final kinematicRepositoryProvider = Provider<KinematicRepositoryImpl>(
  (ref) => KinematicRepositoryImpl(
    remoteDataSource: ref.read(remoteDataSourceProvider),
    localDataSource: ref.read(localDataSourceProvider),
  ),
);

final calculateIntakeUseCaseProvider = Provider<CalculateOptimalIntakeUseCase>(
  (ref) => CalculateOptimalIntakeUseCase(ref.read(kinematicRepositoryProvider)),
);

// State Notifier
class KinematicNotifier extends StateNotifier<AsyncValue<KinematicDose>> {
  final CalculateOptimalIntakeUseCase calculateOptimalIntake;

  KinematicNotifier(this.calculateOptimalIntake) : super(const AsyncValue.loading()) {
    evaluateIntake(); // Auto-fetch on init
  }

  Future<void> evaluateIntake() async {
    state = const AsyncValue.loading();
    final result = await calculateOptimalIntake.execute();
    
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (intake) => state = AsyncValue.data(intake),
    );
  }
}

final kinematicNotifierProvider = StateNotifierProvider<KinematicNotifier, AsyncValue<KinematicDose>>(
  (ref) => KinematicNotifier(ref.read(calculateIntakeUseCaseProvider)),
);
