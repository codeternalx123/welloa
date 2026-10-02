import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/aeg_node.dart';

class AEGState {
  final bool isLoading;
  final AEGSynthesisResult? result;
  final String? error;

  const AEGState({this.isLoading = false, this.result, this.error});

  AEGState copyWith({bool? isLoading, AEGSynthesisResult? result, String? error}) {
    return AEGState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
    );
  }
}

class AEGNotifier extends StateNotifier<AEGState> {
  AEGNotifier() : super(const AEGState());

  Future<void> synthesizeMockGraph() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(seconds: 2));

    final nodes = [
      AEGNode(id: 'n1', label: 'Metabolic Rate', nodeType: 'metabolic', currentValue: 1850, optimalValue: 2000, unit: 'kcal/d', status: 'suboptimal', impactScore: 0.6),
      AEGNode(id: 'n2', label: 'Glucose Reg', nodeType: 'metabolic', currentValue: 88, optimalValue: 85, unit: 'mg/dL', status: 'optimal', impactScore: 0.8),
      AEGNode(id: 'n3', label: 'Mitochondrial', nodeType: 'cellular', currentValue: 72, optimalValue: 90, unit: 'score', status: 'suboptimal', impactScore: 0.7),
      AEGNode(id: 'n4', label: 'Inflammation', nodeType: 'immune', currentValue: 2.1, optimalValue: 1.0, unit: 'hs-CRP', status: 'critical', impactScore: 0.9),
      AEGNode(id: 'n5', label: 'Hormone Bal', nodeType: 'hormonal', currentValue: 65, optimalValue: 80, unit: 'score', status: 'suboptimal', impactScore: 0.5),
      AEGNode(id: 'n6', label: 'Neural Plasticity', nodeType: 'neural', currentValue: 85, optimalValue: 90, unit: 'score', status: 'optimal', impactScore: 0.4),
      AEGNode(id: 'n7', label: 'Cellular Repair', nodeType: 'cellular', currentValue: 45, optimalValue: 80, unit: 'score', status: 'critical', impactScore: 0.85),
      AEGNode(id: 'n8', label: 'Microbiome', nodeType: 'digestive', currentValue: 78, optimalValue: 85, unit: 'score', status: 'optimal', impactScore: 0.6),
    ];

    final edges = [
      AEGEdge(fromNodeId: 'n4', toNodeId: 'n7', edgeType: 'inhibitory', strength: 0.85, latencyHours: 12),
      AEGEdge(fromNodeId: 'n2', toNodeId: 'n4', edgeType: 'amplifying', strength: 0.4, latencyHours: 4),
      AEGEdge(fromNodeId: 'n3', toNodeId: 'n1', edgeType: 'amplifying', strength: 0.7, latencyHours: 24),
      AEGEdge(fromNodeId: 'n8', toNodeId: 'n4', edgeType: 'inhibitory', strength: 0.6, latencyHours: 48),
      AEGEdge(fromNodeId: 'n4', toNodeId: 'n5', edgeType: 'inhibitory', strength: 0.5, latencyHours: 36),
      AEGEdge(fromNodeId: 'n5', toNodeId: 'n6', edgeType: 'amplifying', strength: 0.45, latencyHours: 72),
      AEGEdge(fromNodeId: 'n7', toNodeId: 'n3', edgeType: 'amplifying', strength: 0.65, latencyHours: 24),
    ];

    final result = AEGSynthesisResult(
      id: const Uuid().v4(),
      generatedAt: DateTime.now(),
      graph: AEGGraph(
        nodes: nodes,
        edges: edges,
        overallOptimizationScore: 72.4,
        synthesisNarrative: 'The systemic bottleneck lies in the inverse causal relationship between Inflammation (hs-CRP 2.1) and Cellular Repair mechanisms. The high inflammatory tone is actively suppressing macroautophagy, creating a downstream cascade that limits mitochondrial function and hormonal balance despite optimal glucose regulation.',
        criticalBottleneck: 'Inflammation',
      ),
      topPriorityAction: 'Immediate prescription: Implement 36-hour water fast combined with 1200mg Curcumin to force-clear inflammatory cytokines and reboot macroautophagy pathways.',
      biologicalNetworkHealth: 72.4,
    );

    state = state.copyWith(isLoading: false, result: result);
  }
}

final aegProvider = StateNotifierProvider<AEGNotifier, AEGState>((ref) {
  return AEGNotifier();
});
