import 'package:uuid/uuid.dart';
import '../models/causal_insight_model.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/models/causal_insight.dart';

import '../../../../core/providers/health_provider.dart';

abstract class CausalRemoteDataSource {
  Future<CausalInsightModel> runQueryViaAI(int presetIndex, HealthData? healthData);
}

class CausalRemoteDataSourceImpl implements CausalRemoteDataSource {
  final ClaudeService aiService;

  CausalRemoteDataSourceImpl({required this.aiService});

  @override
  Future<CausalInsightModel> runQueryViaAI(int presetIndex, HealthData? healthData) async {
    String presetFocus = 'carbs and sleep';
    if (presetIndex == 1) presetFocus = 'HIIT and hydration';
    if (presetIndex == 2) presetFocus = 'stress and fasting';

    final variables = <Map<String, dynamic>>[
      {
        'preset_focus': presetFocus,
      },
    ];

    if (healthData != null && (healthData.isAuthorized || healthData.steps > 0 || healthData.sleepMinutes > 0)) {
      final source = healthData.isAuthorized ? "Health Connect" : "Manual Log";
      variables.addAll([
        {'name': 'Data Source', 'value': source},
        {'name': 'Steps', 'value': healthData.steps},
        {'name': 'Sleep Minutes', 'value': healthData.sleepMinutes},
        {'name': 'Active Energy kcal', 'value': healthData.activeEnergy},
      ]);
    } else {
      variables.addAll([
        {'name': 'Note', 'value': 'No health data available. Make general assumptions and encourage them to log data.'}
      ]);
    }

    final entity = await aiService.runCausalInference(
      variables: variables,
      outcomeMetric: 'Lifespan/Longevity optimization',
    );

    return CausalInsightModel(
      id: const Uuid().v4(),
      analyzedAt: DateTime.now(),
      inputVariables: [],
      outcome: entity.outcome,
      causalConfidence: entity.causalConfidence,
      doOperatorQuery: entity.doOperatorQuery,
      counterfactuals: entity.counterfactuals,
      narrative: entity.narrative,
    );
  }
}
