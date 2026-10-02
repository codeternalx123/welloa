import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// UNICORN GRADE: Semantic Knowledge Graph Engine.
/// Dynamically maps sensory "Cravings" to clinical "Search Terms" via a Graph DB.
class KnowledgeGraphService {
  static final KnowledgeGraphService _instance = KnowledgeGraphService._internal();
  factory KnowledgeGraphService() => _instance;
  KnowledgeGraphService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache to prevent redundant reads (Lead Dev Best Practice)
  Map<String, List<String>> _graphCache = {};

  /// BOOTSTRAP: Syncs the latest semantic relationships from the cloud.
  Future<void> syncGraph() async {
    try {
      final snapshot = await _db.collection('knowledge_graph').get();
      final Map<String, List<String>> tempMap = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        tempMap[doc.id.toLowerCase()] = List<String>.from(data['terms'] ?? []);
      }

      _graphCache = tempMap;
      debugPrint('🧠 Knowledge Graph Sync: ${_graphCache.length} semantic nodes loaded.');
    } catch (e) {
      debugPrint('❌ Graph Sync Failure: $e');
    }
  }

  // ============================================
  // THE SEMANTIC MAPPING ENGINE
  // ============================================

  /// Resolves a vague craving into a list of clinical search terms.
  /// If the craving isn't in the graph, it defaults to the raw term.
  List<String> mapCravingToTerms(String craving) {
    final normalizedInput = craving.toLowerCase().trim();
    
    // 1. Direct Node Match
    if (_graphCache.containsKey(normalizedInput)) {
      return _graphCache[normalizedInput]!;
    }

    // 2. Fallback: Heuristic lookup (Partial matches)
    final partialMatch = _graphCache.keys.firstWhere(
      (key) => normalizedInput.contains(key), 
      orElse: () => "",
    );

    if (partialMatch.isNotEmpty) {
      return _graphCache[partialMatch]!;
    }

    // 3. Default: Pass-through
    return [craving];
  }
}