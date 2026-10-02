import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../../features/aeg_graph/data/models/aeg_synthesis_model.dart';
import '../../../core/models/aeg_node.dart';

class AEGGraphDao {
  final DatabaseHelper dbHelper;

  AEGGraphDao({required this.dbHelper});

  Future<void> insertSynthesis(AEGSynthesisModel synthesis) async {
    final db = await dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Insert Core Entity
      await txn.insert(
        DatabaseHelper.tableAegSynthesis,
        {
          'id': synthesis.id,
          'generatedAt': synthesis.generatedAt.toIso8601String(),
          'topPriorityAction': synthesis.topPriorityAction,
          'biologicalNetworkHealth': synthesis.biologicalNetworkHealth,
          'overallOptimizationScore': synthesis.graph.overallOptimizationScore,
          'synthesisNarrative': synthesis.graph.synthesisNarrative,
          'criticalBottleneck': synthesis.graph.criticalBottleneck,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert Nodes
      await txn.delete(DatabaseHelper.tableAegNodes, where: 'synthesisId = ?', whereArgs: [synthesis.id]);
      for (var node in synthesis.graph.nodes) {
        await txn.insert(DatabaseHelper.tableAegNodes, {
          'id': node.id,
          'synthesisId': synthesis.id,
          'label': node.label,
          'nodeType': node.nodeType,
          'currentValue': node.currentValue,
          'optimalValue': node.optimalValue,
          'unit': node.unit,
          'status': node.status,
          'impactScore': node.impactScore,
        });
      }

      // 3. Insert Edges
      await txn.delete(DatabaseHelper.tableAegEdges, where: 'synthesisId = ?', whereArgs: [synthesis.id]);
      for (var edge in synthesis.graph.edges) {
        await txn.insert(DatabaseHelper.tableAegEdges, {
          'synthesisId': synthesis.id,
          'fromNodeId': edge.fromNodeId,
          'toNodeId': edge.toNodeId,
          'edgeType': edge.edgeType,
          'strength': edge.strength,
          'latencyHours': edge.latencyHours,
        });
      }
    });
  }

  Future<AEGSynthesisModel?> getLatestSynthesis() async {
    final db = await dbHelper.database;
    
    // Get latest entry
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableAegSynthesis,
      orderBy: 'generatedAt DESC',
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    final synthesisMap = maps.first;
    final synthesisId = synthesisMap['id'] as String;

    // Fetch relational data
    final nodeMaps = await db.query(DatabaseHelper.tableAegNodes, where: 'synthesisId = ?', whereArgs: [synthesisId]);
    final edgeMaps = await db.query(DatabaseHelper.tableAegEdges, where: 'synthesisId = ?', whereArgs: [synthesisId]);

    final nodes = nodeMaps.map((m) => AEGNode(
      id: m['id'] as String,
      label: m['label'] as String,
      nodeType: m['nodeType'] as String,
      currentValue: m['currentValue'] as double,
      optimalValue: m['optimalValue'] as double,
      unit: m['unit'] as String,
      status: m['status'] as String,
      impactScore: m['impactScore'] as double,
    )).toList();

    final edges = edgeMaps.map((m) => AEGEdge(
      fromNodeId: m['fromNodeId'] as String,
      toNodeId: m['toNodeId'] as String,
      edgeType: m['edgeType'] as String,
      strength: m['strength'] as double,
      latencyHours: m['latencyHours'] as double,
    )).toList();

    final graph = AEGGraph(
      nodes: nodes,
      edges: edges,
      overallOptimizationScore: synthesisMap['overallOptimizationScore'] as double,
      synthesisNarrative: synthesisMap['synthesisNarrative'] as String,
      criticalBottleneck: synthesisMap['criticalBottleneck'] as String,
    );

    return AEGSynthesisModel(
      id: synthesisId,
      generatedAt: DateTime.parse(synthesisMap['generatedAt'] as String),
      graph: graph,
      topPriorityAction: synthesisMap['topPriorityAction'] as String,
      biologicalNetworkHealth: synthesisMap['biologicalNetworkHealth'] as double,
    );
  }
}
