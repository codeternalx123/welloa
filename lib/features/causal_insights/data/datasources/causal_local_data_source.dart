import '../models/causal_insight_model.dart';
import '../../../../core/error/failures.dart';

abstract class CausalLocalDataSource {
  Future<void> cacheInsight(CausalInsightModel insight);
  Future<List<CausalInsightModel>> getCachedInsights();
}

class CausalLocalDataSourceImpl implements CausalLocalDataSource {
  final List<CausalInsightModel> _cache = [];

  @override
  Future<void> cacheInsight(CausalInsightModel insight) async {
    _cache.add(insight);
  }

  @override
  Future<List<CausalInsightModel>> getCachedInsights() async {
    return _cache;
  }
}
