import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/causal_insight_entity.dart';
import '../repositories/causal_repository.dart';
import '../../../../core/providers/health_provider.dart';

class RunAdjustmentalQueryUseCase {
  final CausalRepository repository;

  RunAdjustmentalQueryUseCase(this.repository);

  Future<Either<Failure, CausalInsightEntity>> execute(int presetIndex, HealthData? healthData) async {
    if (presetIndex < 0 || presetIndex > 2) {
      return const Left(CacheFailure('Invalid preset index for do-calculus adjustment.'));
    }
    return await repository.runDoCalculusQuery(presetIndex, healthData);
  }
}
