import '../models/aeg_synthesis_model.dart';
import '../../../../core/services/claude_service.dart';

abstract class AEGRemoteDataSource {
  Future<AEGSynthesisModel> generateSystemicGraphViaAI();
}

class AEGRemoteDataSourceImpl implements AEGRemoteDataSource {
  final ClaudeService aiService;

  AEGRemoteDataSourceImpl({required this.aiService});

  @override
  Future<AEGSynthesisModel> generateSystemicGraphViaAI() async {
    final result = await aiService.synthesizeAEGGraph(nodeData: {});
    
    return AEGSynthesisModel(
      id: result.id,
      generatedAt: result.generatedAt,
      graph: result.graph,
      topPriorityAction: result.topPriorityAction,
      biologicalNetworkHealth: result.biologicalNetworkHealth,
    );
  }
}
