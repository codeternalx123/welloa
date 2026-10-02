import 'dart:convert';
import '../../../../core/services/claude_service.dart';
import '../models/sleep_data_model.dart';

class SleepAIService {
  Future<SleepDataModel> getSleepAnalysis(int age, double weight, double sleepMinutes) async {
    final systemPrompt = '''
You are a gamified longevity AI specializing in sleep and neurological clearance.
The user is $age years old and logged ${sleepMinutes.toStringAsFixed(1)} minutes of sleep.
Generate a gamified analysis of their recent sleep cycle.
Return a JSON object strictly matching this schema:
{
  "longevityImpactYears": (double, positive or negative),
  "clearancePercentage": (int, 0-100),
  "metric1Label": (string, e.g. "Amyloid Beta"),
  "metric1Value": (string, e.g. "-2.4 mg"),
  "metric2Label": (string, e.g. "Cellular Repair"),
  "metric2Value": (string, e.g. "Optimal"),
  "aiQuestion": (string, a personalized statement and question that explicitly mentions the user's logged sleep time, their calculated longevity impact, and asks how they will optimize their deep brain cleaning tonight. e.g. "You logged 420 minutes of sleep which generated +0.1 years of longevity! How will you optimize Deep Brain Cleaning tonight?"),
  "dailyGoal": (string, a gamified daily goal for the user based on their data),
  "nextActionTip": (string, an actionable personalized tip to improve sleep longevity)
}
Do not return any text other than the JSON object.
''';

    try {
      final rawResponse = await ClaudeService.generateResponse(prompt: systemPrompt);
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawResponse);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final jsonMap = jsonDecode(jsonString);
        return SleepDataModel.fromJson(jsonMap);
      }
    } catch (e) {
      print('Error calling or parsing Sleep AI response: $e');
    }

    // Fallback
    return SleepDataModel(
      longevityImpactYears: 2.1,
      clearancePercentage: 92,
      metric1Label: 'Amyloid Beta',
      metric1Value: '-2.4 mg',
      metric2Label: 'Cellular Repair',
      metric2Value: sleepMinutes > 400 ? 'Optimal' : 'Suboptimal',
      nextActionTip: 'Keep temperature cool to optimize repair.',
      aiQuestion: 'You logged ${sleepMinutes.toStringAsFixed(0)} minutes of sleep which gave a ${(sleepMinutes > 400 ? 2.1 : -0.8).toStringAsFixed(1)} year longevity impact! How will you optimize Deep Brain Cleaning tonight?',
      dailyGoal: 'Aim for 90% Amyloid Beta clearance tonight.',
    );
  }
}
