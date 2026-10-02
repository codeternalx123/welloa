class EpigenomicProfile {
  final String id;
  final DateTime dateAssayed;
  final double dunedinPACERate; // Pace of aging (e.g., 0.85 means aging 15% slower)
  final int totalMethylationSitesAnalyzed;
  final double telomereLengthTiers;

  EpigenomicProfile({
    required this.id,
    required this.dateAssayed,
    required this.dunedinPACERate,
    required this.totalMethylationSitesAnalyzed,
    required this.telomereLengthTiers,
  });
}

class EpigenomicDiffResult {
  final EpigenomicProfile baseline;
  final EpigenomicProfile current;
  final double paceDelta;
  final String biologicalInterpretation;

  EpigenomicDiffResult({
    required this.baseline,
    required this.current,
    required this.paceDelta,
    required this.biologicalInterpretation,
  });
}
