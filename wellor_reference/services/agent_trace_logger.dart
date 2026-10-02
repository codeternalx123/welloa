// lib/services/agent_trace_logger.dart
// LANGSMITH-STYLE TRACING for the agent pipeline.
// Logs every node's input/output/latency/model for debugging
// medical advice quality and pipeline performance.

import 'dart:math';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════
// TRACE NODE — A single step in the pipeline
// ═══════════════════════════════════════════════════════════════════

class TraceNode {
  final String node;
  final String model;
  final Map<String, dynamic> input;
  final Map<String, dynamic> output;
  final int latencyMs;
  final DateTime timestamp;

  TraceNode({
    required this.node,
    required this.model,
    required this.input,
    required this.output,
    required this.latencyMs,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'node': node,
    'model': model,
    'input': input,
    'output': output,
    'latencyMs': latencyMs,
    'timestamp': timestamp.toIso8601String(),
  };
}

// ═══════════════════════════════════════════════════════════════════
// TRACE — Full pipeline execution trace
// ═══════════════════════════════════════════════════════════════════

class PipelineTrace {
  final String traceId;
  final String userId;
  final String trigger;
  final DateTime startTime;
  DateTime? endTime;
  String status; // running, completed, error, blocked_by_safety
  String? error;
  final List<TraceNode> nodes;

  PipelineTrace({
    required this.traceId,
    required this.userId,
    required this.trigger,
    DateTime? startTime,
    this.status = 'running',
    this.error,
  })  : startTime = startTime ?? DateTime.now(),
        nodes = [];

  int get totalLatencyMs => endTime != null
      ? endTime!.difference(startTime).inMilliseconds
      : DateTime.now().difference(startTime).inMilliseconds;

  int get nodeCount => nodes.length;

  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'userId': userId,
    'trigger': trigger,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'totalLatencyMs': totalLatencyMs,
    'status': status,
    'error': error,
    'nodeCount': nodeCount,
    'nodes': nodes.map((n) => n.toJson()).toList(),
  };
}

// ═══════════════════════════════════════════════════════════════════
// AGENT TRACE LOGGER — The LangSmith-style tracer
// ═══════════════════════════════════════════════════════════════════

class AgentTraceLogger {
  static final AgentTraceLogger _instance = AgentTraceLogger._internal();
  factory AgentTraceLogger() => _instance;
  AgentTraceLogger._internal();

  // In-memory trace store (also persisted to Firestore by the caller)
  final Map<String, PipelineTrace> _traces = {};

  // Keep last N traces in memory for diagnostics
  static const int _maxInMemoryTraces = 50;

  // ─────────────────────────────────────────────────────────────────
  // TRACE LIFECYCLE
  // ─────────────────────────────────────────────────────────────────

  /// Start a new trace. Returns the trace ID.
  String startTrace({
    required String userId,
    required String trigger,
  }) {
    final traceId = _generateTraceId();

    final trace = PipelineTrace(
      traceId: traceId,
      userId: userId,
      trigger: trigger,
    );

    _traces[traceId] = trace;

    // Evict old traces if over limit
    if (_traces.length > _maxInMemoryTraces) {
      final oldest = _traces.keys.first;
      _traces.remove(oldest);
    }

    debugPrint('📊 Trace [$traceId]: Started for $userId ($trigger)');
    return traceId;
  }

  /// Log a node execution within a trace.
  void logNode({
    required String traceId,
    required String node,
    required String model,
    required Map<String, dynamic> input,
    required Map<String, dynamic> output,
    required int latencyMs,
  }) {
    final trace = _traces[traceId];
    if (trace == null) {
      debugPrint('📊 Trace [$traceId]: Not found, skipping node log');
      return;
    }

    trace.nodes.add(TraceNode(
      node: node,
      model: model,
      input: input,
      output: output,
      latencyMs: latencyMs,
    ));

    debugPrint('📊 Trace [$traceId]: Node "$node" (${model}, ${latencyMs}ms)');
  }

  /// End a trace with final status.
  void endTrace({
    required String traceId,
    required String status,
    String? error,
  }) {
    final trace = _traces[traceId];
    if (trace == null) return;

    trace.endTime = DateTime.now();
    trace.status = status;
    trace.error = error;

    debugPrint('📊 Trace [$traceId]: Ended → $status '
        '(${trace.totalLatencyMs}ms, ${trace.nodeCount} nodes)');
  }

  /// Get a trace as a JSON-serializable map (for Firestore persistence).
  Map<String, dynamic> getTrace(String traceId) {
    return _traces[traceId]?.toJson() ?? {'traceId': traceId, 'status': 'not_found'};
  }

  // ─────────────────────────────────────────────────────────────────
  // DIAGNOSTICS — For the health agent dashboard
  // ─────────────────────────────────────────────────────────────────

  /// Get recent traces for a user (for chat UI display).
  List<Map<String, dynamic>> getRecentTraces({
    String? userId,
    int limit = 10,
  }) {
    var traces = _traces.values.toList();

    if (userId != null) {
      traces = traces.where((t) => t.userId == userId).toList();
    }

    traces.sort((a, b) => b.startTime.compareTo(a.startTime));

    return traces.take(limit).map((t) => t.toJson()).toList();
  }

  /// Get aggregate stats for debugging.
  Map<String, dynamic> getStats() {
    if (_traces.isEmpty) {
      return {'totalTraces': 0};
    }

    final completed = _traces.values.where((t) => t.status == 'completed').toList();
    final errors = _traces.values.where((t) => t.status == 'error').length;
    final blocked = _traces.values.where((t) => t.status == 'blocked_by_safety').length;

    final avgLatency = completed.isNotEmpty
        ? completed.map((t) => t.totalLatencyMs).reduce((a, b) => a + b) ~/ completed.length
        : 0;

    // Count by trigger type
    final triggerCounts = <String, int>{};
    for (final trace in _traces.values) {
      triggerCounts[trace.trigger] = (triggerCounts[trace.trigger] ?? 0) + 1;
    }

    return {
      'totalTraces': _traces.length,
      'completed': completed.length,
      'errors': errors,
      'blockedBySafety': blocked,
      'avgLatencyMs': avgLatency,
      'triggerCounts': triggerCounts,
    };
  }

  /// Clear all in-memory traces.
  void clear() {
    _traces.clear();
  }

  // ─────────────────────────────────────────────────────────────────
  // INTERNAL
  // ─────────────────────────────────────────────────────────────────

  String _generateTraceId() {
    final now = DateTime.now();
    final random = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return 'trace_${now.millisecondsSinceEpoch}_$random';
  }
}
