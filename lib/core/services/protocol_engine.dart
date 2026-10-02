import '../../features/protocols/domain/models/supplement.dart';
import '../../features/protocols/domain/models/protocol.dart';

class ProtocolEvaluationResult {
  final bool isSafe;
  final List<SupplementInteraction> warnings;
  final List<String> adherenceTips;

  ProtocolEvaluationResult({
    required this.isSafe,
    required this.warnings,
    required this.adherenceTips,
  });
}

class ProtocolEngine {
  // A master database of known biochemical interactions
  static const List<SupplementInteraction> _knownInteractions = [
    SupplementInteraction(
      compoundA: 'Iron',
      compoundB: 'Calcium',
      type: InteractionType.absorptionInhibitor,
      warningMessage: 'Calcium blocks the absorption of Iron. Separate by at least 2 hours.',
      severity: InteractionSeverity.medium,
    ),
    SupplementInteraction(
      compoundA: 'Zinc',
      compoundB: 'Copper',
      type: InteractionType.receptorCompetition,
      warningMessage: 'High-dose Zinc depletes Copper. Ensure balanced intake or separate timing.',
      severity: InteractionSeverity.high,
    ),
    SupplementInteraction(
      compoundA: 'Vitamin D',
      compoundB: 'Vitamin K2',
      type: InteractionType.synergistic,
      warningMessage: 'Vitamin D and K2 work synergistically to move calcium into bones instead of arteries.',
      severity: InteractionSeverity.low,
    ),
    SupplementInteraction(
      compoundA: 'Ashwagandha',
      compoundB: 'L-Theanine',
      type: InteractionType.synergistic,
      warningMessage: 'Both lower cortisol. Taken together they may cause excessive drowsiness in the morning.',
      severity: InteractionSeverity.medium,
    )
  ];

  ProtocolEvaluationResult evaluateProtocol(LongevityProtocol protocol) {
    List<SupplementInteraction> warnings = [];
    List<String> tips = [];

    // Check for fat-soluble vitamins without fat context
    for (var supp in protocol.supplements) {
      if (supp.requiresFat && supp.timing == SupplementTiming.uponWaking) {
        tips.add('\${supp.name} requires dietary fat for absorption, but is scheduled upon waking. Consider moving to breakfast.');
      }
      if (supp.requiresFasting && supp.timing == SupplementTiming.withDinner) {
        tips.add('\${supp.name} requires fasting for optimal absorption, but is scheduled with dinner. Move to upon waking or before bed.');
      }
    }

    // Check cross-interactions within the same timing window
    final supplementsByTiming = <SupplementTiming, List<Supplement>>{};
    for (var supp in protocol.supplements) {
      supplementsByTiming.putIfAbsent(supp.timing, () => []).add(supp);
    }

    for (var entry in supplementsByTiming.entries) {
      final suppsInWindow = entry.value;
      if (suppsInWindow.length > 1) {
        for (int i = 0; i < suppsInWindow.length; i++) {
          for (int j = i + 1; j < suppsInWindow.length; j++) {
            final interactions = _checkCompounds(suppsInWindow[i], suppsInWindow[j]);
            warnings.addAll(interactions);
          }
        }
      }
    }

    final hasCritical = warnings.any((w) => w.severity == InteractionSeverity.critical);

    return ProtocolEvaluationResult(
      isSafe: !hasCritical,
      warnings: warnings,
      adherenceTips: tips,
    );
  }

  List<SupplementInteraction> _checkCompounds(Supplement a, Supplement b) {
    List<SupplementInteraction> found = [];
    
    for (var compA in a.activeCompounds) {
      for (var compB in b.activeCompounds) {
        final match = _knownInteractions.where((inter) => 
          (inter.compoundA.toLowerCase() == compA.toLowerCase() && inter.compoundB.toLowerCase() == compB.toLowerCase()) ||
          (inter.compoundA.toLowerCase() == compB.toLowerCase() && inter.compoundB.toLowerCase() == compA.toLowerCase())
        ).toList();
        
        found.addAll(match);
      }
    }
    
    return found;
  }
}
