import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/kinematic_dose_model.dart';
import '../../../../core/services/claude_service.dart';
import '../../../../core/services/health_service.dart';

abstract class KinematicRemoteDataSource {
  Future<KinematicDoseModel> calculateIntakeViaAI();
}

class KinematicRemoteDataSourceImpl implements KinematicRemoteDataSource {
  final ClaudeService aiService;
  final HealthService healthService;

  KinematicRemoteDataSourceImpl({required this.aiService, required this.healthService});

  @override
  Future<KinematicDoseModel> calculateIntakeViaAI() async {
    // 1. Fetch live health data from OS (HealthKit/Connect)
    final hrv = await healthService.getOvernightHRV();
    final sleep = await healthService.getSleepScore();

    // 2. Call AI service for complex physiological calculation
    final systemPrompt = '''
You are a gamified longevity AI specializing in kinematics and exercise physiology.
The user has an overnight HRV of $hrv and a Sleep Score of $sleep.
Calculate their CNS readiness (0-100) and generate a gamified daily strain radar analysis.
Return a JSON object strictly matching this schema:
{
  "cnsReadiness": (double),
  "recommendedZone": (int, 1-5),
  "requiresAdjustment": (bool),
  "longevityImpactYears": (double, positive or negative),
  "metric1Label": (string, e.g. "Target Zone"),
  "metric1Value": (string, e.g. "Zone 2"),
  "metric2Label": (string, e.g. "Adjustment"),
  "metric2Value": (string, e.g. "Required"),
  "aiQuestion": (string, a personalized statement and question that explicitly mentions the user's HRV and Sleep Score, their calculated longevity impact, and asks how they will optimize their Exercise Sweet Spot further today. e.g. "Your HRV of 55 and Sleep Score of 80 generated +0.2 years of longevity impact! How will you optimize further today?"),
  "dailyGoal": (string, a gamified daily goal for the user based on their data),
  "nextActionTip": (string, an actionable personalized tip for today's workout)
}
Do not return any text other than the JSON object.
''';

    try {
      final rawResponse = await ClaudeService.generateResponse(prompt: systemPrompt);
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawResponse);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final jsonMap = jsonDecode(jsonString);
        jsonMap['id'] = const Uuid().v4();
        jsonMap['timestamp'] = DateTime.now().toIso8601String();
        jsonMap['hrv'] = hrv;
        jsonMap['sleepScore'] = sleep;
        return KinematicDoseModel.fromJson(jsonMap);
      }
    } catch (e) {
      print('Error calling or parsing Kinematic AI response: $e');
    }

    return KinematicDoseModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      hrv: hrv,
      sleepScore: sleep,
      cnsReadiness: (hrv + sleep) / 2,
      recommendedZone: hrv > 60 ? 4 : 2,
      requiresAdjustment: hrv < 50,
      longevityImpactYears: hrv > 60 ? 1.8 : -0.5,
      metric1Label: 'Target Zone',
      metric1Value: 'Zone 2',
      metric2Label: 'Adjustment',
      metric2Value: hrv < 50 ? 'Required' : 'None',
      nextActionTip: 'Keep your strain moderate today.',
      aiQuestion: 'Your HRV of $hrv and Sleep Score of $sleep gave a ${(hrv > 60 ? 1.8 : -0.5).toStringAsFixed(1)} year longevity impact! How will we optimize your Exercise Sweet Spot today?',
      dailyGoal: 'Stay in Zone 2 for 45 minutes.',
    );
  }
}
