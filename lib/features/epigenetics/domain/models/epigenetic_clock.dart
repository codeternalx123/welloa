class DnaVariant {
  final String gene;
  final String rsid;
  final String allele;
  final String implication;

  const DnaVariant({
    required this.gene,
    required this.rsid,
    required this.allele,
    required this.implication,
  });
}

class EpigeneticClock {
  final String id;
  final DateTime testDate;
  final double dunedinPace; // Pace of aging (e.g. 0.73 biological years per chronological year)
  final double grimage; // Mortality risk clock
  final double telomereLengthTShour;

  const EpigeneticClock({
    required this.id,
    required this.testDate,
    required this.dunedinPace,
    required this.grimage,
    required this.telomereLengthTShour,
  });

  bool get isAgingBackward => dunedinPace < 1.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'testDate': testDate.toIso8601String(),
        'dunedinPace': dunedinPace,
        'grimage': grimage,
        'telomereLengthTShour': telomereLengthTShour,
      };

  factory EpigeneticClock.fromJson(Map<String, dynamic> json) {
    return EpigeneticClock(
      id: json['id'],
      testDate: DateTime.parse(json['testDate']),
      dunedinPace: (json['dunedinPace'] as num).toDouble(),
      grimage: (json['grimage'] as num).toDouble(),
      telomereLengthTShour: (json['telomereLengthTShour'] as num).toDouble(),
    );
  }
}
