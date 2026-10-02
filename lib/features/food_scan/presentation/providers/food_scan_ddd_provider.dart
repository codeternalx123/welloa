import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/phytochemical_analysis.dart';
import '../../domain/usecases/analyze_meal_image.dart';
import '../../data/repositories/food_scan_repository_impl.dart';
import '../../data/datasources/food_scan_local_data_source.dart';
import '../../data/datasources/food_scan_remote_data_source.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/services/nutrition_ai_service.dart';
import '../../../../core/di/injection_container.dart';

// Dependency Injection Setup
final fsClaudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());
final nutritionAIServiceProvider = Provider((ref) => NutritionAIService());

final fsLocalDataSourceProvider = Provider<FoodScanLocalDataSource>(
  (ref) => FoodScanLocalDataSourceImpl(dao: ref.read(foodScanDaoProvider)),
);

final fsRemoteDataSourceProvider = Provider<FoodScanRemoteDataSource>(
  (ref) => FoodScanRemoteDataSourceImpl(aiService: ref.read(fsClaudeServiceProvider)),
);

final foodScanRepositoryProvider = Provider<FoodScanRepositoryImpl>(
  (ref) => FoodScanRepositoryImpl(
    remoteDataSource: ref.read(fsRemoteDataSourceProvider),
    localDataSource: ref.read(fsLocalDataSourceProvider),
  ),
);

final analyzeMealUseCaseProvider = Provider<AnalyzeMealImageUseCase>(
  (ref) => AnalyzeMealImageUseCase(ref.read(foodScanRepositoryProvider)),
);

class FoodScanDDDNotifier extends StateNotifier<AsyncValue<PhytochemicalAnalysis?>> {
  final AnalyzeMealImageUseCase analyzeUseCase;
  final NutritionAIService nutritionAI;

  FoodScanDDDNotifier(this.analyzeUseCase, this.nutritionAI) : super(const AsyncData(null));

  Future<void> analyzeDemoImage(int age) async {
    state = const AsyncValue.loading();
    // Providing a mock base64 string to bypass physical camera
    final result = await analyzeUseCase.execute('mock_base64_string_of_salmon_and_broccoli');
    
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (analysis) {
        // Adjust for demo based on age
        final ageFactor = age > 40 ? 1.5 : 1.0;
        final adjusted = PhytochemicalAnalysis(
          id: analysis.id,
          analyzedAt: analysis.analyzedAt,
          totalAgeScore: analysis.totalAgeScore,
          polyphenolScore: analysis.polyphenolScore,
          biologicalAgeCostMinutes: analysis.biologicalAgeCostMinutes * ageFactor,
          guidanceList: analysis.guidanceList,
          metric1Label: analysis.metric1Label,
          metric1Value: analysis.metric1Value,
          metric2Label: analysis.metric2Label,
          metric2Value: analysis.metric2Value,
          aiQuestion: analysis.aiQuestion,
          dailyGoal: analysis.dailyGoal,
        );
        state = AsyncValue.data(adjusted);
      },
    );
  }

  Future<void> analyzeRealImage(List<int> imageBytes, int age) async {
    state = const AsyncValue.loading();
    try {
      final analysis = await nutritionAI.analyzeFoodWithPipeline(imageBytes);
      
      final ageFactor = age > 40 ? 1.5 : 1.0;
      final adjusted = PhytochemicalAnalysis(
        id: analysis.id,
        analyzedAt: analysis.analyzedAt,
        totalAgeScore: analysis.totalAgeScore,
        polyphenolScore: analysis.polyphenolScore,
        biologicalAgeCostMinutes: analysis.biologicalAgeCostMinutes * ageFactor,
        guidanceList: analysis.guidanceList,
        metric1Label: analysis.metric1Label,
        metric1Value: analysis.metric1Value,
        metric2Label: analysis.metric2Label,
        metric2Value: analysis.metric2Value,
        aiQuestion: analysis.aiQuestion,
        dailyGoal: analysis.dailyGoal,
      );
      state = AsyncValue.data(adjusted);
    } catch (e) {
      state = AsyncValue.error('Failed to analyze image: $e', StackTrace.current);
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final foodScanDDDNotifierProvider = StateNotifierProvider<FoodScanDDDNotifier, AsyncValue<PhytochemicalAnalysis?>>(
  (ref) => FoodScanDDDNotifier(ref.read(analyzeMealUseCaseProvider), ref.read(nutritionAIServiceProvider)),
);
