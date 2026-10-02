import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/causal_insight_entity.dart';

import '../../../../core/providers/health_provider.dart';

abstract class CausalRepository {
  Future<Either<Failure, CausalInsightEntity>> runDoCalculusQuery(int presetIndex, HealthData? healthData);
  Future<Either<Failure, List<CausalInsightEntity>>> getHistoricalQueries();
}
