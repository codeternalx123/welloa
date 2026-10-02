import 'package:equatable/equatable.dart';
import '../../../../core/models/causal_insight.dart' show CausalVariable, CausalOutcome, CounterfactualScenario;

class CausalInsightEntity extends Equatable {
  final String id;
  final DateTime analyzedAt;
  final List<CausalVariable> inputVariables;
  final CausalOutcome outcome;
  final double causalConfidence;
  final String doOperatorQuery;
  final List<CounterfactualScenario> counterfactuals;
  final String narrative;

  const CausalInsightEntity({
    required this.id,
    required this.analyzedAt,
    required this.inputVariables,
    required this.outcome,
    required this.causalConfidence,
    required this.doOperatorQuery,
    required this.counterfactuals,
    required this.narrative,
  });

  @override
  List<Object?> get props => [id, analyzedAt, causalConfidence, doOperatorQuery];
}
