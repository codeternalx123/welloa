import 'package:equatable/equatable.dart';
import '../../../../core/models/aeg_node.dart' show AEGGraph;

class AEGSynthesisEntity extends Equatable {
  final String id;
  final DateTime generatedAt;
  final AEGGraph graph;
  final String topPriorityAction;
  final double biologicalNetworkHealth;

  const AEGSynthesisEntity({
    required this.id,
    required this.generatedAt,
    required this.graph,
    required this.topPriorityAction,
    required this.biologicalNetworkHealth,
  });

  @override
  List<Object?> get props => [id, generatedAt, biologicalNetworkHealth, topPriorityAction];
}
