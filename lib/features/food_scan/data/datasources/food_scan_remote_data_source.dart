import 'package:uuid/uuid.dart';
import '../models/phytochemical_analysis_model.dart';
import '../../../../core/services/claude_service.dart';

abstract class FoodScanRemoteDataSource {
  Future<PhytochemicalAnalysisModel> analyzeImage(String base64Image);
}

class FoodScanRemoteDataSourceImpl implements FoodScanRemoteDataSource {
  final ClaudeService aiService;

  FoodScanRemoteDataSourceImpl({required this.aiService});

  @override
  Future<PhytochemicalAnalysisModel> analyzeImage(String base64Image) async {
    // Integrate with the actual Claude API
    final rawResult = await aiService.analyzeFoodImage(base64Image);
    
    // Transform core model into DDD model for robust local handling
    return PhytochemicalAnalysisModel(
      id: rawResult.id,
      analyzedAt: rawResult.analyzedAt,
      totalAgeScore: rawResult.totalAgeScore,
      polyphenolScore: rawResult.polyphenolScore,
      biologicalAgeCostMinutes: rawResult.biologicalAgeCostMinutes,
      guidanceList: rawResult.guidanceList,
      metric1Label: rawResult.metric1Label,
      metric1Value: rawResult.metric1Value,
      metric2Label: rawResult.metric2Label,
      metric2Value: rawResult.metric2Value,
      aiQuestion: rawResult.aiQuestion,
      dailyGoal: rawResult.dailyGoal,
    );
  }
}
