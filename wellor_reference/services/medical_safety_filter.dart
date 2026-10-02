// lib/services/medical_safety_filter.dart
// MEDICAL SAFETY FILTER
// Pre-screens all AI-generated health advice before it reaches the user.
// Catches dangerous recommendations and either sanitizes or blocks them.

import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════
// FILTER RESULT
// ═══════════════════════════════════════════════════════════════════

class SafetyFilterResult {
  final String message;
  final bool wasModified;
  final bool blocked;
  final List<String> flags;

  const SafetyFilterResult({
    required this.message,
    this.wasModified = false,
    this.blocked = false,
    this.flags = const [],
  });
}

// ═══════════════════════════════════════════════════════════════════
// MEDICAL SAFETY FILTER
// ═══════════════════════════════════════════════════════════════════

class MedicalSafetyFilter {
  static final MedicalSafetyFilter _instance = MedicalSafetyFilter._internal();
  factory MedicalSafetyFilter() => _instance;
  MedicalSafetyFilter._internal();

  // ─────────────────────────────────────────────────────────────────
  // DANGEROUS PATTERNS — Block or flag these
  // ─────────────────────────────────────────────────────────────────

  /// Patterns that should BLOCK the message entirely.
  static final List<_SafetyRule> _blockRules = [
    _SafetyRule(
      pattern: RegExp(r'stop\s+(taking|your)\s+(medication|insulin|medicine|metformin|pills)', caseSensitive: false),
      flag: 'STOP_MEDICATION',
      description: 'Advises stopping medication',
    ),
    _SafetyRule(
      pattern: RegExp(r'(don.t|do\s+not|never)\s+(take|use)\s+(your\s+)?(medication|insulin|medicine)', caseSensitive: false),
      flag: 'AVOID_MEDICATION',
      description: 'Advises against taking medication',
    ),
    _SafetyRule(
      pattern: RegExp(r'(skip|miss|avoid)\s+(your\s+)?(insulin|medication)\s+(dose|injection|shot)', caseSensitive: false),
      flag: 'SKIP_MEDICATION_DOSE',
      description: 'Advises skipping medication dose',
    ),
    _SafetyRule(
      pattern: RegExp(r'inject\s+(more|extra|additional|double)\s+(insulin|units)', caseSensitive: false),
      flag: 'MODIFY_INSULIN_DOSE',
      description: 'Advises changing insulin dosage',
    ),
    _SafetyRule(
      pattern: RegExp(r'(diagnos|you\s+have|you\s+are\s+(diabetic|pre-diabetic|hypoglycemic))', caseSensitive: false),
      flag: 'DIAGNOSIS',
      description: 'Makes a medical diagnosis',
    ),
  ];

  /// Patterns that should FLAG but allow with a disclaimer appended.
  static final List<_SafetyRule> _flagRules = [
    _SafetyRule(
      pattern: RegExp(r'(fast|don.t eat|skip meals?|stop eating)\s+(for|until|today)', caseSensitive: false),
      flag: 'FASTING_ADVICE',
      description: 'Suggests extended fasting',
    ),
    _SafetyRule(
      pattern: RegExp(r'(intense|vigorous|heavy|strenuous)\s+(exercise|workout|training|running)', caseSensitive: false),
      flag: 'INTENSE_EXERCISE',
      description: 'Recommends intense exercise',
    ),
    _SafetyRule(
      pattern: RegExp(r'(emergency|call\s+911|go\s+to\s+(the\s+)?(ER|emergency|hospital)|ambulance)', caseSensitive: false),
      flag: 'EMERGENCY_ESCALATION',
      description: 'Escalates to emergency services',
    ),
    _SafetyRule(
      pattern: RegExp(r'(supplement|vitamin|herb|extract)\s+(will|can)\s+(cure|fix|treat|heal)', caseSensitive: false),
      flag: 'SUPPLEMENT_CLAIM',
      description: 'Claims supplements can cure conditions',
    ),
  ];

  /// Context-specific rules — only apply under certain conditions.
  static final List<_ContextRule> _contextRules = [
    _ContextRule(
      conditions: ['diabetes', 'type 1', 'type 2', 't1d', 't2d'],
      pattern: RegExp(r'(eat|consume|have)\s+(lots?\s+of\s+)?(sugar|candy|sweets|soda|juice)', caseSensitive: false),
      flag: 'SUGAR_FOR_DIABETIC',
      description: 'Recommends sugar to diabetic patient (may be valid for hypo)',
      allowForAnomalies: ['HYPOGLYCEMIA', 'RAPID_DROP'], // Valid for treating hypo
    ),
    _ContextRule(
      conditions: ['diabetes', 'type 1', 'type 2', 't1d', 't2d'],
      pattern: RegExp(r'skip\s+(breakfast|lunch|dinner|meals?)', caseSensitive: false),
      flag: 'SKIP_MEAL_DIABETIC',
      description: 'Advises diabetic patient to skip meals',
      allowForAnomalies: [],
    ),
    _ContextRule(
      conditions: ['heart', 'cardiac', 'cardiovascular', 'hypertension'],
      pattern: RegExp(r'(sprint|HIIT|high.intensity|burpees|heavy\s+lifting)', caseSensitive: false),
      flag: 'INTENSE_EXERCISE_CARDIAC',
      description: 'Recommends intense exercise to cardiac patient',
      allowForAnomalies: [],
    ),
  ];

  static const String _disclaimer = '\n\n_This is AI-generated guidance, not medical advice. '
      'Always consult your healthcare provider for medical decisions._';

  // ─────────────────────────────────────────────────────────────────
  // FILTER — Main entry point
  // ─────────────────────────────────────────────────────────────────

  /// Filter a message before it reaches the user.
  Future<SafetyFilterResult> filter({
    required String message,
    required String anomalyType,
    required double glucoseLevel,
    List<String> patientConditions = const [],
  }) async {
    final flags = <String>[];
    var filteredMessage = message;
    var wasModified = false;

    // ── Check block rules ──
    for (final rule in _blockRules) {
      if (rule.pattern.hasMatch(message)) {
        flags.add(rule.flag);
        debugPrint('🚫 Safety: BLOCKED — ${rule.description}');

        return SafetyFilterResult(
          message: message,
          wasModified: false,
          blocked: true,
          flags: flags,
        );
      }
    }

    // ── Check flag rules ──
    for (final rule in _flagRules) {
      if (rule.pattern.hasMatch(message)) {
        flags.add(rule.flag);
        wasModified = true;
        debugPrint('⚠️ Safety: FLAGGED — ${rule.description}');
      }
    }

    // ── Check context-specific rules ──
    final lowerConditions = patientConditions.map((c) => c.toLowerCase()).toList();

    for (final rule in _contextRules) {
      // Check if this rule applies to the patient's conditions
      final conditionMatch = rule.conditions.any(
        (cond) => lowerConditions.any((pc) => pc.contains(cond)),
      );

      if (!conditionMatch) continue;

      if (rule.pattern.hasMatch(message)) {
        // Check if this is allowed for the current anomaly type
        if (rule.allowForAnomalies.contains(anomalyType)) {
          debugPrint('✅ Safety: Context rule "${rule.flag}" allowed for $anomalyType');
          continue;
        }

        flags.add(rule.flag);
        wasModified = true;
        debugPrint('⚠️ Safety: CONTEXT FLAG — ${rule.description}');
      }
    }

    // ── Glucose range sanity check ──
    // If glucose is LOW and AI recommends exercise, flag it
    if (glucoseLevel < 80 && _containsExerciseAdvice(message)) {
      flags.add('EXERCISE_DURING_HYPO');
      wasModified = true;
      filteredMessage = _replaceExerciseWithRest(filteredMessage);
      debugPrint('⚠️ Safety: Replaced exercise advice during low glucose');
    }

    // If glucose is critically HIGH (>300) and no escalation, add it
    if (glucoseLevel > 300 && !_containsEscalation(message)) {
      filteredMessage += '\n\n⚠️ *Important:* Your glucose is very high. '
          'If this persists, contact your healthcare provider.';
      flags.add('ADDED_ESCALATION');
      wasModified = true;
    }

    // ── Append disclaimer if any flags were raised ──
    if (flags.isNotEmpty && !filteredMessage.contains('not medical advice')) {
      filteredMessage += _disclaimer;
    }

    return SafetyFilterResult(
      message: filteredMessage,
      wasModified: wasModified,
      blocked: false,
      flags: flags,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  bool _containsExerciseAdvice(String message) {
    return RegExp(r'(walk|jog|run|exercise|squats|move|active|workout)', caseSensitive: false)
        .hasMatch(message);
  }

  bool _containsEscalation(String message) {
    return RegExp(r'(doctor|healthcare|provider|medical|hospital|emergency|911)', caseSensitive: false)
        .hasMatch(message);
  }

  String _replaceExerciseWithRest(String message) {
    // Replace exercise suggestions with rest/snack for hypoglycemia
    return message.replaceAllMapped(
      RegExp(r'(take\s+a\s+)(\d+-minute\s+)?(walk|jog|run)', caseSensitive: false),
      (m) => 'sit down and rest',
    ).replaceAllMapped(
      RegExp(r'(do\s+)(\d+\s+)?(squats|pushups|burpees|jumping\s+jacks)', caseSensitive: false),
      (m) => 'sit down and have a fast-acting carb snack',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// INTERNAL RULE TYPES
// ═══════════════════════════════════════════════════════════════════

class _SafetyRule {
  final RegExp pattern;
  final String flag;
  final String description;

  const _SafetyRule({
    required this.pattern,
    required this.flag,
    required this.description,
  });
}

class _ContextRule {
  final List<String> conditions; // Patient conditions this rule applies to
  final RegExp pattern;
  final String flag;
  final String description;
  final List<String> allowForAnomalies; // Anomaly types where this is OK

  const _ContextRule({
    required this.conditions,
    required this.pattern,
    required this.flag,
    required this.description,
    required this.allowForAnomalies,
  });
}
