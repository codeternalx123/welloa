/// Health Data Service: Central repository for disease and health goal data.
/// Used by health_search_dialog.dart for biometric triage options.
class HealthDataService {
  // Common diseases database
  static const List<String> commonDiseases = [
    'Type 2 Diabetes',
    'Hypertension',
    'Heart Disease',
    'Obesity',
    'Metabolic Syndrome',
    'Polycystic Ovary Syndrome',
    'Thyroid Disorder',
    'Celiac Disease',
    'Gluten Sensitivity',
    'Lactose Intolerance',
    'Kidney Disease',
    'Liver Disease',
    'Cancer',
    'Arthritis',
    'Asthma',
    'Chronic Inflammatory Condition',
  ];

  // Health goals database
  static const List<String> healthGoals = [
    'Weight Management',
    'Muscle Building',
    'Athletic Performance',
    'Energy Optimization',
    'Mental Clarity',
    'Cardiovascular Health',
    'Gut Health',
    'Skin Health',
    'Longevity',
    'Sleep Quality',
    'Immune Support',
    'Inflammation Reduction',
    'Blood Sugar Stability',
    'Cholesterol Management',
    'Hormonal Balance',
    'Detoxification',
  ];

  /// Search diseases by query string
  static List<String> searchDiseases(String query) {
    if (query.isEmpty) return commonDiseases;
    final lowerQuery = query.toLowerCase();
    return commonDiseases
        .where((disease) => disease.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Search health goals by query string
  static List<String> searchHealthGoals(String query) {
    if (query.isEmpty) return healthGoals;
    final lowerQuery = query.toLowerCase();
    return healthGoals
        .where((goal) => goal.toLowerCase().contains(lowerQuery))
        .toList();
  }
}
