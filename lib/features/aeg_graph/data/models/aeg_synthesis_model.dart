import '../../domain/entities/aeg_synthesis_entity.dart';
import '../../../../core/models/aeg_node.dart' show AEGGraph;

class AEGSynthesisModel extends AEGSynthesisEntity {
  const AEGSynthesisModel({
    required String id,
    required DateTime generatedAt,
    required AEGGraph graph,
    required String topPriorityAction,
    required double biologicalNetworkHealth,
  }) : super(
          id: id,
          generatedAt: generatedAt,
          graph: graph,
          topPriorityAction: topPriorityAction,
          biologicalNetworkHealth: biologicalNetworkHealth,
        );
}
