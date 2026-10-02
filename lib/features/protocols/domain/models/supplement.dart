class Supplement {
  final String id;
  final String name;
  final double dosage;
  final String unit;
  final SupplementTiming timing;
  final List<String> activeCompounds;
  final bool requiresFat;
  final bool requiresFasting;

  const Supplement({
    required this.id,
    required this.name,
    required this.dosage,
    required this.unit,
    required this.timing,
    required this.activeCompounds,
    this.requiresFat = false,
    this.requiresFasting = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'unit': unit,
        'timing': timing.name,
        'activeCompounds': activeCompounds,
        'requiresFat': requiresFat ? 1 : 0,
        'requiresFasting': requiresFasting ? 1 : 0,
      };

  factory Supplement.fromJson(Map<String, dynamic> json) {
    return Supplement(
      id: json['id'],
      name: json['name'],
      dosage: (json['dosage'] as num).toDouble(),
      unit: json['unit'],
      timing: SupplementTiming.values.firstWhere((e) => e.name == json['timing'], orElse: () => SupplementTiming.anytime),
      activeCompounds: List<String>.from(json['activeCompounds'] ?? []),
      requiresFat: (json['requiresFat'] == 1 || json['requiresFat'] == true),
      requiresFasting: (json['requiresFasting'] == 1 || json['requiresFasting'] == true),
    );
  }
}

enum SupplementTiming {
  uponWaking,
  withBreakfast,
  withLunch,
  withDinner,
  beforeBed,
  anytime,
}

class SupplementInteraction {
  final String compoundA;
  final String compoundB;
  final InteractionType type;
  final String warningMessage;
  final InteractionSeverity severity;

  const SupplementInteraction({
    required this.compoundA,
    required this.compoundB,
    required this.type,
    required this.warningMessage,
    required this.severity,
  });
}

enum InteractionType {
  absorptionInhibitor, // e.g., Calcium blocks Iron absorption
  synergistic,         // e.g., Vitamin C enhances Iron absorption
  toxicOverlap,        // e.g., multiple sources of Vitamin A causing toxicity
  receptorCompetition, // e.g., Zinc and Copper competing
}

enum InteractionSeverity {
  low,
  medium,
  high,
  critical,
}
