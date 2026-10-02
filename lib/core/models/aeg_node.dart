class AEGNode {
  final String id;
  final String label;
  final String nodeType;
  final double currentValue;
  final double optimalValue;
  final String unit;
  final String status;
  final double impactScore;

  AEGNode({
    required this.id,
    required this.label,
    required this.nodeType,
    required this.currentValue,
    required this.optimalValue,
    required this.unit,
    required this.status,
    required this.impactScore,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'nodeType': nodeType,
        'currentValue': currentValue,
        'optimalValue': optimalValue,
        'unit': unit,
        'status': status,
        'impactScore': impactScore,
      };

  factory AEGNode.fromJson(Map<String, dynamic> json) => AEGNode(
        id: json['id'],
        label: json['label'],
        nodeType: json['nodeType'],
        currentValue: (json['currentValue'] as num).toDouble(),
        optimalValue: (json['optimalValue'] as num).toDouble(),
        unit: json['unit'],
        status: json['status'],
        impactScore: (json['impactScore'] as num).toDouble(),
      );
}

class AEGEdge {
  final String fromNodeId;
  final String toNodeId;
  final String edgeType;
  final double strength;
  final double latencyHours;

  AEGEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.edgeType,
    required this.strength,
    required this.latencyHours,
  });

  Map<String, dynamic> toJson() => {
        'fromNodeId': fromNodeId,
        'toNodeId': toNodeId,
        'edgeType': edgeType,
        'strength': strength,
        'latencyHours': latencyHours,
      };

  factory AEGEdge.fromJson(Map<String, dynamic> json) => AEGEdge(
        fromNodeId: json['fromNodeId'],
        toNodeId: json['toNodeId'],
        edgeType: json['edgeType'],
        strength: (json['strength'] as num).toDouble(),
        latencyHours: (json['latencyHours'] as num).toDouble(),
      );
}

class AEGGraph {
  final List<AEGNode> nodes;
  final List<AEGEdge> edges;
  final double overallOptimizationScore;
  final String synthesisNarrative;
  final String criticalBottleneck;

  AEGGraph({
    required this.nodes,
    required this.edges,
    required this.overallOptimizationScore,
    required this.synthesisNarrative,
    required this.criticalBottleneck,
  });

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((e) => e.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'overallOptimizationScore': overallOptimizationScore,
        'synthesisNarrative': synthesisNarrative,
        'criticalBottleneck': criticalBottleneck,
      };

  factory AEGGraph.fromJson(Map<String, dynamic> json) => AEGGraph(
        nodes: (json['nodes'] as List).map((e) => AEGNode.fromJson(e)).toList(),
        edges: (json['edges'] as List).map((e) => AEGEdge.fromJson(e)).toList(),
        overallOptimizationScore: (json['overallOptimizationScore'] as num).toDouble(),
        synthesisNarrative: json['synthesisNarrative'],
        criticalBottleneck: json['criticalBottleneck'],
      );
}

class AEGSynthesisResult {
  final String id;
  final DateTime generatedAt;
  final AEGGraph graph;
  final String topPriorityAction;
  final double biologicalNetworkHealth;

  AEGSynthesisResult({
    required this.id,
    required this.generatedAt,
    required this.graph,
    required this.topPriorityAction,
    required this.biologicalNetworkHealth,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'generatedAt': generatedAt.toIso8601String(),
        'graph': graph.toJson(),
        'topPriorityAction': topPriorityAction,
        'biologicalNetworkHealth': biologicalNetworkHealth,
      };

  factory AEGSynthesisResult.fromJson(Map<String, dynamic> json) => AEGSynthesisResult(
        id: json['id'],
        generatedAt: DateTime.parse(json['generatedAt']),
        graph: AEGGraph.fromJson(json['graph']),
        topPriorityAction: json['topPriorityAction'],
        biologicalNetworkHealth: (json['biologicalNetworkHealth'] as num).toDouble(),
      );
}
