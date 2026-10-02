import '../models/bio_twin_model.dart';
import '../../../../core/services/claude_service.dart';

abstract class BioTwinRemoteDataSource {
  Future<BioTwinModel> compileTwinViaAI(double chronoAge, Map<String, dynamic> biometrics);
}

class BioTwinRemoteDataSourceImpl implements BioTwinRemoteDataSource {
  final ClaudeService aiService;

  BioTwinRemoteDataSourceImpl({required this.aiService});

  @override
  Future<BioTwinModel> compileTwinViaAI(double chronoAge, Map<String, dynamic> biometrics) async {
    // Uses the existing Claude Service from core
    final result = await aiService.compileBioTwin(chronologicalAge: chronoAge, biometrics: biometrics);
    
    return BioTwinModel(
      id: result.id,
      compiledAt: result.compiledAt,
      chronologicalAge: result.chronologicalAge,
      biologicalAge: result.biologicalAge,
      ageGap: result.ageGap,
      reversalRateMonthsPerYear: result.reversalRateMonthsPerYear,
      trajectory: result.trajectory,
      hallmarkScores: result.hallmarkScores,
      keyBioMarkers: result.keyBioMarkers,
      sixMonthProjection: result.sixMonthProjection,
    );
  }
}
