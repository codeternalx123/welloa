import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/food_analysis.dart';

class FoodScanState {
  final bool isLoading;
  final FoodAnalysisResult? result;
  final String? error;
  final String? capturedImagePath;

  const FoodScanState({
    this.isLoading = false,
    this.result,
    this.error,
    this.capturedImagePath,
  });

  FoodScanState copyWith({
    bool? isLoading,
    FoodAnalysisResult? result,
    String? error,
    String? capturedImagePath,
  }) {
    return FoodScanState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
      capturedImagePath: capturedImagePath ?? this.capturedImagePath,
    );
  }
}

class FoodScanNotifier extends StateNotifier<FoodScanState> {
  FoodScanNotifier() : super(const FoodScanState());

  Future<void> analyzeMockFood() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(seconds: 2));

    final result = FoodAnalysisResult(
      id: const Uuid().v4(),
      analyzedAt: DateTime.now(),
      items: [
        FoodItem(name: 'Wild Salmon', estimatedGrams: 180, ageScore: 12.0, phytochemicals: ['Astaxanthin', 'Omega-3 DHA'], preparationMethod: 'Grilled'),
        FoodItem(name: 'Broccoli', estimatedGrams: 150, ageScore: 5.0, phytochemicals: ['Sulforaphane', 'Glucosinolates', 'Quercetin'], preparationMethod: 'Steamed'),
        FoodItem(name: 'Blueberries', estimatedGrams: 120, ageScore: 3.0, phytochemicals: ['Anthocyanins', 'Resveratrol', 'Pterostilbene'], preparationMethod: 'Raw'),
      ],
      totalAgeScore: 14.2,
      polyphenolScore: 87.4,
      hallmarkImpacts: [
        HallmarkImpact(hallmarkName: 'Genomic Instability', impactScore: 0.7, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Telomere Attrition', impactScore: 0.6, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Epigenetic Alterations', impactScore: 0.8, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Loss of Proteostasis', impactScore: 0.5, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Disabled Macroautophagy', impactScore: 0.4, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Deregulated Nutrient Sensing', impactScore: 0.6, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Mitochondrial Dysfunction', impactScore: 0.75, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Cellular Senescence', impactScore: 0.5, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Stem Cell Exhaustion', impactScore: 0.3, impactType: 'neutral'),
        HallmarkImpact(hallmarkName: 'Altered Intercellular Communication', impactScore: 0.4, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Chronic Inflammation', impactScore: 0.85, impactType: 'protective'),
        HallmarkImpact(hallmarkName: 'Dysbiosis', impactScore: 0.6, impactType: 'protective'),
      ],
      guidanceList: [
        'Optimal: Add 1 cup raw arugula to further boost glucosinolate intake by 40%',
        'Consider 250mg quercetin supplement to amplify blueberry anthocyanin bioavailability',
        'Add 1 tbsp olive oil to increase carotenoid absorption by 300%',
      ],
      portionLimits: [
        'Salmon portion is within optimal range (150-200g)',
        'Blueberry portion is ideal — exceeding 200g increases fructose load',
      ],
      biologicalAgeCostMinutes: -18.4,
    );
    state = state.copyWith(isLoading: false, result: result);
  }
}

final foodScanProvider = StateNotifierProvider<FoodScanNotifier, FoodScanState>((ref) {
  return FoodScanNotifier();
});
