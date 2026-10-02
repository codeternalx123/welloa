import '../../features/epigenetics/domain/models/epigenetic_clock.dart';

class DnaInteractionResult {
  final bool hasConflict;
  final String description;

  DnaInteractionResult({required this.hasConflict, required this.description});
}

class DnaIntegrationService {
  // Hardcoded for demo: Imagine this is fetched from a secure 23andMe / SelfDecode API vault
  final List<DnaVariant> userVariants = [
    const DnaVariant(
      gene: 'MTHFR',
      rsid: 'rs1801133',
      allele: 'TT',
      implication: 'Severely reduced methylation capacity. Requires Methyl-Folate instead of Folic Acid.',
    ),
    const DnaVariant(
      gene: 'APOE',
      rsid: 'rs429358',
      allele: 'e4/e4',
      implication: "High risk for Alzheimer's. Very poor response to saturated fat. Keep LDL extremely low.",
    ),
  ];

  /// Scans a logged meal's macronutrient profile against the user's DNA variants
  DnaInteractionResult evaluateMealAgainstGenotype(String mealDescription, Map<String, double> macros) {
    if (userVariants.any((v) => v.gene == 'APOE' && v.allele.contains('e4'))) {
      if ((macros['saturated_fat'] ?? 0.0) > 10.0) {
        return DnaInteractionResult(
          hasConflict: true,
          description: 'CRITICAL: This meal contains high saturated fat. Your APOE4 genotype makes you highly susceptible to arterial plaque from this.',
        );
      }
    }

    if (userVariants.any((v) => v.gene == 'MTHFR' && v.allele == 'TT')) {
      if (mealDescription.toLowerCase().contains('fortified') || mealDescription.toLowerCase().contains('folic acid')) {
        return DnaInteractionResult(
          hasConflict: true,
          description: 'WARNING: Meal contains synthetic folic acid. Your MTHFR TT variant cannot process this, leading to toxic build-up.',
        );
      }
    }

    return DnaInteractionResult(
      hasConflict: false,
      description: 'This meal is perfectly aligned with your genotype.',
    );
  }
}
