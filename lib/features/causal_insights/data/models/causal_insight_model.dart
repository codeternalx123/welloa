import '../../domain/entities/causal_insight_entity.dart';
import '../../../../core/models/causal_insight.dart' show CausalVariable, CausalOutcome, CounterfactualScenario;

class CausalInsightModel extends CausalInsightEntity {
  const CausalInsightModel({
    required String id,
    required DateTime analyzedAt,
    required List<CausalVariable> inputVariables,
    required CausalOutcome outcome,
    required double causalConfidence,
    required String doOperatorQuery,
    required List<CounterfactualScenario> counterfactuals,
    required String narrative,
  }) : super(
          id: id,
          analyzedAt: analyzedAt,
          inputVariables: inputVariables,
          outcome: outcome,
          causalConfidence: causalConfidence,
          doOperatorQuery: doOperatorQuery,
          counterfactuals: counterfactuals,
          narrative: narrative,
        );
}
