// lib/services/metabolic_twin_orchestrator.dart
// MEDICAL-GRADE: Metabolic Twin Orchestrator (Supervisor Agent)
// Coordinates all sub-agents to form the Predictive Metabolic Twin system
// Implements the agentic loop for autonomous digital therapeutics

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/glucose_context.dart';
import '../models/safety_state.dart';
import 'cgm_monitoring_agent.dart';
import 'deterministic_safety_engine.dart';
import 'intervention_escalation_service.dart';
import 'adaptive_engagement_agent.dart';
import 'subscription_entitlement_resolver.dart';

/// ═══════════════════════════════════════════════════════════════════
/// METABOLIC TWIN ORCHESTRATOR (Supervisor Agent)
/// ═══════════════════════════════════════════════════════════════════
/// 
/// **Role**: Supervise and coordinate all sub-agents
/// 
/// **Sub-Agents Coordinated:**
/// 1. CGM Monitoring Agent - Continuous glucose monitoring & dG/dt
/// 2. Deterministic Safety Engine - Mathematical guardrails
/// 3. Intervention Escalation Service - GlucoCoach + Voice calls
/// 4. Adaptive Engagement Agent - Anti-fatigue management
/// 5. Local Cuisine Learning Agent - Food glycemic prediction
/// 6. Edge Computing Agent - Offline capability
/// 
/// **Agentic Loop (Every 5 minutes):**
/// 1. INGEST → CGM reading
/// 2. CALCULATE → dG/dt, d²G/dt²
/// 3. PREDICT → 20min, 45min, 90min glucose
/// 4. EVALUATE → Deterministic safety state
/// 5. DECIDE → Should intervene? (Adaptive engagement check)
/// 6. GENERATE → AI message (Claude)
/// 7. SEND → GlucoCoach/Voice/In-App
/// 8. LOG → Audit trail
/// 
/// **Safety Guarantee**: Clinical decisions made by MATH, not AI
/// ═══════════════════════════════════════════════════════════════════

class MetabolicTwinOrchestrator {
  static final MetabolicTwinOrchestrator _instance = MetabolicTwinOrchestrator._internal();
  factory MetabolicTwinOrchestrator() => _instance;
  MetabolicTwinOrchestrator._internal();
  
  // Sub-agents
  final CGMMonitoringAgent _cgmAgent = CGMMonitoringAgent();
  final InterventionEscalationService _interventionService = InterventionEscalationService();
  final AdaptiveEngagementAgent _engagementAgent = AdaptiveEngagementAgent();
  
  // State
  bool _isActive = false;
  String? _activeUserId;
  GlucoseContext? _lastContext;
  SafetyEvaluation? _lastEvaluation;
  
  // Statistics
  int _totalMonitoringCycles = 0;
  int _totalInterventions = 0;
  int _preventedCrashes = 0;
  
  // ═══════════════════════════════════════════════════════════════════
  // ORCHESTRATOR LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════
  
  /// Activate metabolic twin for a user
  Future<void> activate({required String userId}) async {
    if (_isActive) {
      debugPrint('🤖 Metabolic Twin: Already active for user $_activeUserId');
      if (_activeUserId != userId) {
        await deactivate();
      } else {
        return;
      }
    }

    if (!await SubscriptionEntitlementResolver.instance.isActiveUltra(userId)) {
      debugPrint(
        '🤖 Metabolic Twin: Not starting — agentic closed-loop requires active Ultra ([hasAgenticMode])',
      );
      return;
    }
    
    _isActive = true;
    _activeUserId = userId;
    
    debugPrint('🤖 ═══════════════════════════════════════════════════════');
    debugPrint('🤖 METABOLIC TWIN ACTIVATED');
    debugPrint('🤖 User: $userId');
    debugPrint('🤖 Mode: Continuous Monitoring (5-minute intervals)');
    debugPrint('🤖 Safety: Deterministic guardrails ACTIVE');
    debugPrint('🤖 ═══════════════════════════════════════════════════════');
    
    // Register callback for safety evaluations
    _cgmAgent.onSafetyEvaluation((evaluation) {
      _handleSafetyEvaluation(userId, evaluation);
    });
    
    // Register callback for context updates
    _cgmAgent.onContextUpdate((context) {
      _handleContextUpdate(context);
    });
    
    // Start CGM monitoring agent
    await _cgmAgent.startMonitoring(userId: userId);
    
    debugPrint('🤖 Metabolic Twin: Monitoring started');
  }
  
  /// Deactivate metabolic twin
  Future<void> deactivate() async {
    if (!_isActive) {
      debugPrint('🤖 Metabolic Twin: Not active');
      return;
    }
    
    debugPrint('🤖 Metabolic Twin: Deactivating...');
    
    // Stop CGM monitoring
    _cgmAgent.stopMonitoring();
    
    // Print statistics
    debugPrint('🤖 ═══════════════════════════════════════════════════════');
    debugPrint('🤖 METABOLIC TWIN DEACTIVATED');
    debugPrint('🤖 Total Monitoring Cycles: $_totalMonitoringCycles');
    debugPrint('🤖 Total Interventions: $_totalInterventions');
    debugPrint('🤖 Prevented Crashes: $_preventedCrashes');
    debugPrint('🤖 ═══════════════════════════════════════════════════════');
    
    _isActive = false;
    _activeUserId = null;
    _lastContext = null;
    _lastEvaluation = null;
  }
  
  /// Is metabolic twin currently active?
  bool get isActive => _isActive;
  
  /// Get current user ID
  String? get activeUserId => _activeUserId;
  
  // ═══════════════════════════════════════════════════════════════════
  // EVENT HANDLERS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Handle safety evaluation from CGM agent
  void _handleSafetyEvaluation(String userId, SafetyEvaluation evaluation) async {
    _totalMonitoringCycles++;
    _lastEvaluation = evaluation;
    
    final context = _lastContext;
    if (context == null) {
      debugPrint('⚠️ Metabolic Twin: No context available for intervention');
      return;
    }
    
    debugPrint('🤖 ─────────────────────────────────────────────────────');
    debugPrint('🤖 AGENTIC LOOP CYCLE #$_totalMonitoringCycles');
    debugPrint('🤖 Safety State: ${evaluation.state.label}');
    debugPrint('🤖 Glucose: ${context.currentValue.toStringAsFixed(0)} mg/dL ${context.arrow}');
    debugPrint('🤖 Velocity: ${context.velocity.toStringAsFixed(1)} mg/dL/min');
    debugPrint('🤖 Confidence: ${(evaluation.confidence * 100).toStringAsFixed(0)}%');
    
    // Skip if safe
    if (evaluation.state == SafetyState.safe) {
      debugPrint('🤖 Decision: No intervention needed (safe)');
      return;
    }
    
    // DECISION POINT: Should we intervene?
    // Uses Adaptive Engagement Agent to avoid notification fatigue
    final decision = await _engagementAgent.shouldIntervene(
      currentState: evaluation.state,
      userId: userId,
    );
    
    if (!decision.shouldSend) {
      debugPrint('🤖 Decision: Defer intervention (${decision.reason})');
      return;
    }
    
    debugPrint('🤖 Decision: INTERVENE via ${decision.channel?.label}');
    
    // Track if this is a crash prevention
    if (evaluation.state == SafetyState.imminentCrash) {
      _preventedCrashes++;
    }
    
    // EXECUTE INTERVENTION
    final result = await _interventionService.executeIntervention(
      userId: userId,
      evaluation: evaluation,
      context: context,
      tone: decision.tone ?? InterventionTone.clinical,
    );
    
    if (result.success) {
      _totalInterventions++;
      debugPrint('🤖 Result: ✅ Intervention sent successfully');
    } else {
      debugPrint('🤖 Result: ❌ Intervention failed: ${result.reason}');
    }
    
    debugPrint('🤖 ─────────────────────────────────────────────────────');
  }
  
  /// Handle context update from CGM agent
  void _handleContextUpdate(GlucoseContext context) {
    _lastContext = context;
    
    // Notify any UI listeners
    _notifyListeners(context);
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get current glucose context
  GlucoseContext? get currentContext => _lastContext;
  
  /// Get current safety evaluation
  SafetyEvaluation? get currentEvaluation => _lastEvaluation;
  
  /// Get current safety state
  SafetyState? get currentSafetyState => _lastEvaluation?.state;
  
  /// Force immediate check (manual trigger)
  Future<void> forceCheck() async {
    if (!_isActive || _activeUserId == null) {
      debugPrint('⚠️ Metabolic Twin: Cannot force check - not active');
      return;
    }
    
    debugPrint('🤖 Metabolic Twin: Forcing immediate check...');
    await _cgmAgent.addManualReading(
      userId: _activeUserId!,
      glucose: _lastContext?.currentValue ?? 100.0,
    );
  }
  
  /// Get statistics
  Map<String, dynamic> getStatistics() => {
    'totalMonitoringCycles': _totalMonitoringCycles,
    'totalInterventions': _totalInterventions,
    'preventedCrashes': _preventedCrashes,
    'isActive': _isActive,
    'activeUserId': _activeUserId,
    'currentGlucose': _lastContext?.currentValue,
    'currentState': _lastEvaluation?.state.name,
  };
  
  // ═══════════════════════════════════════════════════════════════════
  // UI LISTENERS
  // ═══════════════════════════════════════════════════════════════════
  
  final List<void Function(GlucoseContext)> _listeners = [];
  
  /// Register listener for context updates
  void addListener(void Function(GlucoseContext) listener) {
    _listeners.add(listener);
  }
  
  /// Remove listener
  void removeListener(void Function(GlucoseContext) listener) {
    _listeners.remove(listener);
  }
  
  /// Notify all listeners
  void _notifyListeners(GlucoseContext context) {
    for (final listener in _listeners) {
      try {
        listener(context);
      } catch (e) {
        debugPrint('❌ Metabolic Twin: Error in listener: $e');
      }
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// CONVENIENCE EXTENSIONS
/// ═══════════════════════════════════════════════════════════════════

extension MetabolicTwinQuickAccess on MetabolicTwinOrchestrator {
  /// Quick status summary
  String get statusSummary {
    if (!isActive) return 'Inactive';
    
    final glucose = currentContext?.currentValue.toStringAsFixed(0) ?? '--';
    final arrow = currentContext?.arrow ?? '→';
    final state = currentSafetyState?.label ?? 'UNKNOWN';
    
    return '$glucose mg/dL $arrow | $state';
  }
  
  /// Is user currently safe?
  bool get isUserSafe => currentSafetyState == SafetyState.safe;
  
  /// Is there an active concern?
  bool get hasActiveConcern =>
      currentSafetyState != null &&
      currentSafetyState != SafetyState.safe;
  
  /// Is this a critical situation?
  bool get isCriticalSituation => currentSafetyState?.isCritical ?? false;
}
