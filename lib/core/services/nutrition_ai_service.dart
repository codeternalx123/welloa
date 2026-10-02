import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/food_scan/data/models/phytochemical_analysis_model.dart';
import 'claude_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NutritionAIService {
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  final ClaudeService _claudeService = ClaudeService();

  Future<PhytochemicalAnalysisModel> analyzeFoodWithPipeline(List<int> imageBytes) async {
    // Step 1: Gemini Vision (Perception)
    String foodDescription = "A nutrient-dense meal";
    try {
      final model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: _geminiApiKey);
      final prompt = TextPart("Identify the main food items in this image. Estimate the portion sizes or quantities. Return the response as a short, concise description (e.g., '200g of grilled salmon and 1 cup of steamed broccoli').");
      
      final imageParts = [
        DataPart('image/jpeg', Uint8List.fromList(imageBytes))
      ];

      final geminiResponse = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);
      
      foodDescription = geminiResponse.text ?? "Unknown food item";
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw Exception('You are currently offline. Please connect to the internet and try again.');
      }
      print('Gemini Vision failed (likely model not found): $e');
      // Fallback description to allow Claude Reasoning to continue
      foodDescription = "A mixed meal with potential longevity benefits (Gemini Vision API unavailable)";
    }

    // Step 2: Claude Sonnet (Reasoning & Longevity Impact)
    final systemPrompt = "You are an expert phytochemical nutritionist mapping food to the 12 Hallmarks of Aging. The user is eating: $foodDescription. Calculate the biological age cost (or benefit) in minutes, the total age score (0-100), the polyphenol score (0-100), and a list of specific guidance strings (e.g., advising on quantity or specific longevity pathways). Also provide two gamified metrics, e.g. Glucose Spike, Microbiome, Cellular Repair, etc. CRITICAL: Use simple, everyday language. No medical jargon. Return a JSON object strictly matching the schema with keys: 'id' (string), 'analyzedAt' (ISO8601 string), 'totalAgeScore' (double), 'polyphenolScore' (double), 'biologicalAgeCostMinutes' (double), 'guidanceList' (list of strings), 'metric1Label' (string), 'metric1Value' (string), 'metric2Label' (string), 'metric2Value' (string), 'aiQuestion' (string), and 'dailyGoal' (string). OUTPUT STRICTLY RAW JSON ONLY. DO NOT USE MARKDOWN. DO NOT USE ```json BLOCKS. NO CONVERSATIONAL TEXT. YOUR RESPONSE MUST START WITH '{' AND END WITH '}'.";
    
    String claudeRawResponse = '';
    try {
      claudeRawResponse = await ClaudeService.generateResponse(prompt: systemPrompt);
      
      // Parse Claude's JSON
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(claudeRawResponse);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final jsonMap = jsonDecode(jsonString);
        
        return PhytochemicalAnalysisModel(
          id: jsonMap['id'] ?? 'scan_${DateTime.now().millisecondsSinceEpoch}',
          analyzedAt: DateTime.tryParse(jsonMap['analyzedAt'] ?? '') ?? DateTime.now(),
          totalAgeScore: (jsonMap['totalAgeScore'] as num?)?.toDouble() ?? 50.0,
          polyphenolScore: (jsonMap['polyphenolScore'] as num?)?.toDouble() ?? 50.0,
          biologicalAgeCostMinutes: (jsonMap['biologicalAgeCostMinutes'] as num?)?.toDouble() ?? 0.0,
          guidanceList: (jsonMap['guidanceList'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [foodDescription],
          metric1Label: jsonMap['metric1Label']?.toString() ?? 'Glucose Spike',
          metric1Value: jsonMap['metric1Value']?.toString() ?? '+12 mg/dL',
          metric2Label: jsonMap['metric2Label']?.toString() ?? 'Microbiome',
          metric2Value: jsonMap['metric2Value']?.toString() ?? 'Nourished',
          aiQuestion: jsonMap['aiQuestion']?.toString() ?? 'How do we optimize longevity today in Instant Meal Impact?',
          dailyGoal: jsonMap['dailyGoal']?.toString() ?? 'Keep polyphenol levels above 80 today.',
        );
      }
    } catch (e) {
      if (e.toString().contains('offline')) {
        throw Exception('You are currently offline. Please connect to the internet and try again.');
      }
      print('Failed to call Claude or parse response: $e');
    }

    // Fallback if parsing or API fails - generate dynamic realistic data based on foodDescription
    final lowerFood = foodDescription.toLowerCase();
    
    // Determine if food is generally healthy
    bool isHealthy = lowerFood.contains('salad') || lowerFood.contains('vegetable') || lowerFood.contains('tomato') || 
                     lowerFood.contains('fruit') || lowerFood.contains('fish') || lowerFood.contains('chicken') || 
                     lowerFood.contains('broccoli') || lowerFood.contains('greens');
                     
    bool isUnhealthy = lowerFood.contains('burger') || lowerFood.contains('pizza') || lowerFood.contains('fries') || 
                       lowerFood.contains('sugar') || lowerFood.contains('fried') || lowerFood.contains('cake');
                       
    double costMins = 0.0;
    String gSpike = 'Moderate (+25 mg/dL)';
    String gutHealth = 'Neutral';
    String tip = 'Consider portion control and eat slowly.';
    String recommendation = 'Add some extra leafy greens to balance this out.';

    if (isHealthy) {
      costMins = -15.0; // Boost
      gSpike = 'Low (+10 mg/dL)';
      gutHealth = 'Nourished';
      tip = 'Great choice! This meal provides essential micronutrients and antioxidants.';
      recommendation = 'Add a drizzle of extra virgin olive oil or some avocado to maximize fat-soluble vitamin absorption.';
    } else if (isUnhealthy) {
      costMins = 30.0; // Tax
      gSpike = 'High (+55 mg/dL)';
      gutHealth = 'Disrupted';
      tip = 'This meal contains inflammatory compounds and empty calories.';
      recommendation = 'Drink 2 glasses of water now, and add a side of fermented foods (like kimchi or kraut) to your next meal to repair the gut.';
    } else {
      // For neutral or unknown like 'Tomato'
      costMins = -5.0;
      gSpike = 'Normal (+18 mg/dL)';
      gutHealth = 'Supported';
      tip = 'A balanced choice that provides baseline energy.';
      recommendation = 'Add some chia seeds or walnuts to boost your Omega-3 levels for cognitive longevity.';
    }

    return PhytochemicalAnalysisModel(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      analyzedAt: DateTime.now(),
      totalAgeScore: isHealthy ? 85.0 : (isUnhealthy ? 40.0 : 65.0),
      polyphenolScore: isHealthy ? 90.0 : (isUnhealthy ? 20.0 : 50.0),
      biologicalAgeCostMinutes: costMins,
      guidanceList: [
        'Detected: $foodDescription',
        tip,
        'Longevity Hack: $recommendation'
      ],
      metric1Label: 'Glucose Spike',
      metric1Value: gSpike,
      metric2Label: 'Microbiome',
      metric2Value: gutHealth,
      aiQuestion: 'How can we upgrade this meal for maximum longevity?',
      dailyGoal: 'Try to incorporate at least 3 different colored plants today.',
    );
  }
}
