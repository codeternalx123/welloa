class EnzymeProfile {
  final String geneName;
  final String genotype;
  final String metabolizerStatus; // 'Rapid', 'Normal', 'Intermediate', 'Poor'
  final String impactDescription;

  EnzymeProfile({
    required this.geneName,
    required this.genotype,
    required this.metabolizerStatus,
    required this.impactDescription,
  });
}

class PhytochemicalInsights {
  final String compoundName;
  final double standardIntakeMg;
  final double personalizedIntakeMg;
  final String responsibleEnzyme;
  final String adjustmentRationale;
  final String riskLevel; // 'Safe', 'Monitor', 'Caution Advised'

  PhytochemicalInsights({
    required this.compoundName,
    required this.standardIntakeMg,
    required this.personalizedIntakeMg,
    required this.responsibleEnzyme,
    required this.adjustmentRationale,
    required this.riskLevel,
  });
}

class PharmacogenomicResult {
  final String id;
  final DateTime analyzedAt;
  final List<EnzymeProfile> geneticProfile;
  final List<PhytochemicalInsights> tailoredGuidances;

  PharmacogenomicResult({
    required this.id,
    required this.analyzedAt,
    required this.geneticProfile,
    required this.tailoredGuidances,
  });
}
