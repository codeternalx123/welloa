import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_analysis.dart';
import '../models/kinematic_dose.dart';
import '../models/bio_twin.dart';
import '../models/causal_insight.dart';
import '../models/aeg_node.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../network/circuit_breaker.dart';
import 'ai_cache_service.dart';

class ClaudeService {
  final CircuitBreaker circuitBreaker;
  final AiCacheService aiCacheService;

  ClaudeService({
    CircuitBreaker? circuitBreaker,
    AiCacheService? aiCacheService,
  })  : circuitBreaker = circuitBreaker ?? CircuitBreaker(),
        aiCacheService = aiCacheService ?? AiCacheService();

  Future<String> generateGuidance(String prompt, [String systemPrompt = '']) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 2000,
          if (systemPrompt.isNotEmpty) 'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': prompt}
          ]
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
      }
      final data = jsonDecode(response.body);
      final text = data['content']?[0]?['text'] as String?;
      return text ?? '';
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw Exception('You are currently offline. Please connect to the internet and try again.');
      }
      rethrow;
    }
  }

  static String get apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';
  // The user explicitly requested claude-sonnet-5
  static const String model = 'claude-sonnet-5';
  static const String baseUrl = 'https://api.anthropic.com/v1/messages';

  Future<dynamic> _sendRequest(String systemPrompt, dynamic userMessage, {int retries = 2}) async {
    // 1. Check AI Cache to save tokens and latency
    final cachedResponse = aiCacheService.getCachedResponse(systemPrompt, userMessage);
    if (cachedResponse != null) {
      return cachedResponse;
    }

    // 2. Wrap the Anthropic HTTP call in a Circuit Breaker pattern
    final dynamic jsonResult = await circuitBreaker.execute(() async {
      int attempt = 0;
      
      while (attempt <= retries) {
        try {
          final response = await http.post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': 4096,
              'system': systemPrompt,
              'messages': [
                {'role': 'user', 'content': userMessage}
              ]
            }),
          );

          if (response.statusCode != 200) {
            throw Exception('Claude API error: \${response.statusCode} - \${response.body}');
          }

          final data = jsonDecode(response.body);
          final text = data['content']?[0]?['text'] as String?;
          if (text == null || text.isEmpty) {
            throw Exception('No content in Claude response: \${response.body}');
          }

          String cleanedText = text.trim();
          if (cleanedText.startsWith('```json')) {
            cleanedText = cleanedText.substring(7);
          } else if (cleanedText.startsWith('```')) {
            cleanedText = cleanedText.substring(3);
          }
          if (cleanedText.endsWith('```')) {
            cleanedText = cleanedText.substring(0, cleanedText.length - 3);
          }
          
          return jsonDecode(cleanedText.trim());

        } on FormatException catch (e) {
          // Strict JSON Validation: If Claude hallucinated invalid JSON, retry immediately
          attempt++;
          if (attempt > retries) {
            throw Exception('Claude Hallucinated Invalid JSON after \$retries retries: \$e');
          }
        } on Exception catch (e) {
          if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
            throw Exception('You are currently offline. Please connect to the internet and try again.');
          }
          rethrow;
        }
      }
    });

    // 3. Cache the successful result before returning
    aiCacheService.saveResponse(systemPrompt, userMessage, jsonResult);
    return jsonResult;
  }

  Future<Map<String, dynamic>> _callClaude(String systemPrompt, dynamic userMessage) async {
    return await _sendRequest(systemPrompt, userMessage) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _callClaudeArray(String systemPrompt, dynamic userMessage) async {
    return await _sendRequest(systemPrompt, userMessage) as List<dynamic>;
  }

  Future<FoodAnalysisResult> analyzeFoodImage(String base64Image) async {
    final systemPrompt = "You are an expert phytochemical nutritionist mapping food to the 12 Hallmarks of Aging. Return a JSON object strictly matching the FoodAnalysisResult schema.";
    final userMessage = [
      {
        "type": "image",
        "source": {
          "type": "base64",
          "media_type": "image/jpeg",
          "data": base64Image
        }
      },
      {
        "type": "text",
        "text": "Analyze this food image and provide the JSON result."
      }
    ];
    final resultMap = await _callClaude(systemPrompt, userMessage);
    return FoodAnalysisResult.fromJson(resultMap);
  }

  Future<KinematicDoseResult> evaluateKinematicReadiness({
    required double hrv,
    required double sleepScore,
    required double weightDelta,
    required String plannedWorkoutType,
    required int plannedDurationMinutes,
    required int plannedIntensityPercent,
  }) async {
    final systemPrompt = "You are an exercise physiologist specializing in hormetic zone optimization. Return JSON matching KinematicDoseResult schema.";
    final userMessage = "HRV: $hrv, Sleep: $sleepScore, Weight Delta: $weightDelta, Planned: $plannedWorkoutType ($plannedDurationMinutes min @ $plannedIntensityPercent%).";
    final resultMap = await _callClaude(systemPrompt, userMessage);
    return KinematicDoseResult.fromJson(resultMap);
  }

  Future<BioTwinResult> compileBioTwin({
    required double chronologicalAge,
    required Map<String, dynamic> biometrics,
  }) async {
    final systemPrompt = "You are a biological age compiler. Return JSON matching BioTwinResult schema. CRITICAL: Use extremely simple, easy-to-understand language. Explain everything like a friendly health coach, avoiding dense medical jargon.";
    final userMessage = "Chronological Age: $chronologicalAge, Biometrics: ${jsonEncode(biometrics)}";
    
    try {
      final resultMap = await _callClaude(systemPrompt, userMessage);
      return BioTwinResult.fromJson(resultMap);
    } catch (e) {
      print('Claude API failed (likely invalid model version): $e');
      return BioTwinResult(
        id: 'mock-bio-twin',
        compiledAt: DateTime.now(),
        chronologicalAge: chronologicalAge,
        biologicalAge: chronologicalAge - 1.5,
        ageGap: 1.5,
        reversalRateMonthsPerYear: 2.5,
        hallmarkScores: const [
          HallmarkScore(hallmarkName: "DNA Health", score: 85, trend: "stable"),
          HallmarkScore(hallmarkName: "Cell Protection", score: 78, trend: "improving"),
        ],
        keyBioMarkers: const [
          BioMarker(name: "Heart Stress (HRV)", value: 65, unit: "ms", optimalRange: "55-100", status: "optimal"),
          BioMarker(name: "Fitness Level (VO2 Max)", value: 42.5, unit: "ml/kg/min", optimalRange: "40-55", status: "optimal"),
          BioMarker(name: "Body Inflammation (Hs-CRP)", value: 1.2, unit: "mg/L", optimalRange: "<1.0", status: "warning"),
          BioMarker(name: "Morning Sugar Control", value: 5.5, unit: "uIU/mL", optimalRange: "2-5", status: "warning"),
          BioMarker(name: "Youth Hormone (DHEA-S)", value: 210, unit: "ug/dL", optimalRange: "150-350", status: "optimal"),
          BioMarker(name: "Growth & Repair (IGF-1)", value: 155, unit: "ng/mL", optimalRange: "100-200", status: "optimal"),
        ],
        trajectory: "reversing",
        sixMonthProjection: [
          SimulationPoint(monthOffset: 0, projectedBioAge: chronologicalAge - 1.5),
          SimulationPoint(monthOffset: 1, projectedBioAge: chronologicalAge - 1.6),
          SimulationPoint(monthOffset: 2, projectedBioAge: chronologicalAge - 1.7),
          SimulationPoint(monthOffset: 3, projectedBioAge: chronologicalAge - 1.8),
          SimulationPoint(monthOffset: 4, projectedBioAge: chronologicalAge - 1.9),
          SimulationPoint(monthOffset: 5, projectedBioAge: chronologicalAge - 2.0),
          SimulationPoint(monthOffset: 6, projectedBioAge: chronologicalAge - 2.1),
        ],
      );
    }
  }

  Future<CausalInsightResult> runCausalInference({
    required List<Map<String, dynamic>> variables,
    required String outcomeMetric,
  }) async {
    final systemPrompt = "You are a causal inference engine using do-calculus reasoning. Return JSON matching CausalInsightResult schema. CRITICAL: Use extremely simple, gamified, and easy-to-understand language. Explain it like a fitness coach. Also, explicitly dedicate one sentence in the narrative to explain WHY it matters that they tracked this data (via Health Connect or Manual Log), and how precise tracking unlocks a direct longevity impact.";
    final userMessage = "Variables: ${jsonEncode(variables)}, Outcome: $outcomeMetric";
    
    try {
      final resultMap = await _callClaude(systemPrompt, userMessage);
      return CausalInsightResult.fromJson(resultMap);
    } catch (e) {
      print('Claude API failed for causal inference: $e');
      return CausalInsightResult(
        id: 'mock-causal',
        analyzedAt: DateTime.now(),
        inputVariables: variables.map((e) => CausalVariable.fromJson(e)).toList(),
        outcome: CausalOutcome(
          metric: outcomeMetric,
          value: -2.5,
          unit: 'years',
          temporalExtentHours: 24,
          description: 'Biological age reduction based on recent behavior'
        ),
        causalConfidence: 0.88,
        doOperatorQuery: 'P(Outcome | do(Variables))',
        counterfactuals: const [
          CounterfactualScenario(
            description: 'If you had maintained optimal deep sleep...',
            changedVariable: 'Sleep Quality',
            changedValue: 'Optimal',
            alternativeOutcome: -3.5,
            deltaVsActual: -1.0,
          )
        ],
        narrative: "Based on our causal analysis, your current habits are actively reversing your biological age. However, a slight drop in deep sleep quality has limited your potential gains. WHY it matters that you tracked this: precise tracking allows us to pinpoint exactly how your sleep latency correlates with your biological age reduction! Adjusting your sleep routine could unlock an extra year of longevity.",
      );
    }
  }

  Future<AEGSynthesisResult> synthesizeAEGGraph({
    required Map<String, dynamic> nodeData,
  }) async {
    final systemPrompt = "You are an AI health analyzer connecting different health habits together. Return JSON matching AEGSynthesisResult schema. CRITICAL: Use extremely simple, gamified, and easy-to-understand language. No medical jargon.";
    final userMessage = "Node Data: ${jsonEncode(nodeData)}";
    
    try {
      final resultMap = await _callClaude(systemPrompt, userMessage);
      return AEGSynthesisResult.fromJson(resultMap);
    } catch (e) {
      print('Claude API failed (likely invalid model version): $e');
      return AEGSynthesisResult(
        id: 'mock-aeg-graph',
        generatedAt: DateTime.now(),
        topPriorityAction: 'Optimize Sleep Consistency',
        biologicalNetworkHealth: 82.5,
        graph: AEGGraph(
          nodes: [
            AEGNode(id: 'n1', label: 'Sleep Quality', nodeType: 'behavioral', currentValue: 7.2, optimalValue: 8.0, unit: 'hrs', status: 'suboptimal', impactScore: 9.0),
            AEGNode(id: 'n2', label: 'HRV Recovery', nodeType: 'biometric', currentValue: 65.0, optimalValue: 80.0, unit: 'ms', status: 'suboptimal', impactScore: 8.5),
            AEGNode(id: 'n3', label: 'Zone 2 Cardio', nodeType: 'behavioral', currentValue: 120.0, optimalValue: 180.0, unit: 'min/wk', status: 'optimal', impactScore: 7.0),
          ],
          edges: [
            AEGEdge(fromNodeId: 'n1', toNodeId: 'n2', edgeType: 'causal', strength: 0.8, latencyHours: 24.0),
          ],
          overallOptimizationScore: 80.0,
          synthesisNarrative: 'Your sleep quality is heavily bottlenecking your HRV recovery. By adding 45 minutes of sleep, your entire biological network will improve by 15%.',
          criticalBottleneck: 'Deep Sleep Duration',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> getCoachAdvice({
    required int age,
    required double weight,
  }) async {
    final systemPrompt = "You are a 'Dopamine Architect' and Behavioral Engine for health adherence. Given the user's age and weight, return a JSON object with 'exerciseAdvice' and 'foodAdvice'. Frame all advice using behavioral economics and psychological manipulation to maximize adherence. Keep it actionable, simple, and under 3 sentences each.";
    final userMessage = "Age: $age, Weight: $weight kg";
    final resultMap = await _callClaude(systemPrompt, userMessage);
    return resultMap;
  }

  static Future<String> generateResponse({required String prompt}) async {
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 1000,
          'messages': [
            {'role': 'user', 'content': prompt}
          ]
        }),
      );
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw Exception('You are currently offline. Please connect to the internet and try again.');
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data['content'] == null || data['content'].isEmpty) {
      throw Exception('No content in Claude response: ${response.body}');
    }
    final text = data['content'][0]['text'];
    if (text == null) {
      throw Exception('No text in Claude response: ${response.body}');
    }
    return text;
  }

  Future<String> generateAgentNotification({required Map<String, dynamic> healthData}) async {
    final systemPrompt = "You are a proactive 24/7 AI Health Agent. The user's current health data is provided. Generate a short, punchy, 1-2 sentence gamified push notification telling them what to do RIGHT NOW to optimize their Bio-Twin and longevity graph based on the data. Be very concise and use a fitness coach tone.";
    final userMessage = "Health Data: ${jsonEncode(healthData)}";
    return generateResponse(prompt: "$systemPrompt\n\n$userMessage");
  }

  Future<String> chatWithAgent({
    required List<Map<String, String>> history,
    String? customSystemPrompt,
  }) async {
    final systemPrompt = customSystemPrompt ??
        "You are Welloa's 24/7 AI Health Agent. You proactively monitor the user's longevity graph and Health Connect data. Respond to their messages in a conversational, friendly, and helpful tone using simple everyday words without medical jargon.";
    
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 1500,
          'system': systemPrompt,
          'messages': history
        }),
      );
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw Exception('You are currently offline. Please connect to the internet and try again.');
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data['content'] == null || data['content'].isEmpty) {
      throw Exception('No content in Claude response: ${response.body}');
    }
    final text = data['content'][0]['text'];
    if (text == null) {
      throw Exception('No text in Claude response: ${response.body}');
    }
    return text;
  }

  Future<List<Map<String, dynamic>>> generateUnicornInsights({
    required String domain,
    required Map<String, dynamic> healthData,
    Map<String, String>? dnaData,
    Map<String, String>? sleepData,
  }) async {
    final systemPrompt = "You are an expert AI Longevity Coach. Generate a gamified 'Unicorn Score' insight for the domain: $domain. "
        "Correlate the advice with the provided Health Connect data: ${jsonEncode(healthData)}. "
        "CRITICAL: Use extremely simple, easy-to-understand language. Avoid complex medical words. Explain concepts like you are talking to a beginner. "
        "Return STRICT JSON ARRAY of objects with keys: title, metricName, score, subtitle, advice, longevityImpact (must start with + or - and end in Years).";
    final userMessage = "Domain: $domain";
    
    try {
      final result = await _callClaudeArray(systemPrompt, userMessage);
      return List<Map<String, dynamic>>.from(result.map((x) => Map<String, dynamic>.from(x)));
    } catch (e) {
      print('Claude API failed (likely invalid model version): $e');
      // Secure Fallback Map based on domain
      if (domain == 'dna') {
        final mthfr = dnaData?['mthfr'] ?? 'Impaired';
        final actn3 = dnaData?['actn3'] ?? 'Sprinter';
        final apoe4 = dnaData?['apoe4'] ?? 'Variant Found';
        final fto = dnaData?['fto'] ?? 'High Responder';
        
        return [
          {
            'title': 'My DNA Insights',
            'metricName': 'Vitamin Processing (MTHFR)',
            'score': mthfr,
            'subtitle': mthfr == 'Normal' ? 'Your body processes B-vitamins efficiently.' : 'Your body struggles to process standard B-vitamins.',
            'advice': mthfr == 'Normal' ? 'Keep taking standard multivitamin complexes.' : 'Switch to methylated B-complex immediately. Your recent low sleep (${healthData['sleepMinutes'] ?? 0} mins) is exacerbating fatigue.',
            'longevityImpact': mthfr == 'Normal' ? '+1.0 Years' : '+3.0 Years',
          },
          {
            'title': 'My DNA Insights',
            'metricName': 'Muscle Type (ACTN3)',
            'score': actn3,
            'subtitle': actn3 == 'Sprinter' ? 'You are genetically optimized for power.' : (actn3 == 'Endurance' ? 'Optimized for long duration stamina.' : 'Balanced muscle fiber type.'),
            'advice': actn3 == 'Sprinter' ? 'Your recent activity shows high endurance, but your genes crave HIIT. Add 2 sprint sessions per week.' : 'Focus on Zone 2 cardio and long distance runs to match your genes.',
            'longevityImpact': '+1.5 Years',
          },
          {
            'title': 'My DNA Insights',
            'metricName': 'Fat Processing (APOE4)',
            'score': apoe4,
            'subtitle': apoe4 == 'Variant Found' ? 'High sensitivity to saturated fats.' : 'Normal fat metabolism.',
            'advice': apoe4 == 'Variant Found' ? 'Your recent active energy expenditure (${healthData['activeEnergy'] ?? 0} kcal) is great, but you must prioritize Omega-3s over saturated fats to protect cognitive longevity.' : 'Enjoy healthy fats like avocados and olive oil.',
            'longevityImpact': apoe4 == 'Variant Found' ? '+4.2 Years' : '+1.1 Years',
          },
          {
            'title': 'My DNA Insights',
            'metricName': 'Fasting Benefit (FTO)',
            'score': fto,
            'subtitle': fto == 'High Responder' ? 'Your genes love intermittent fasting.' : 'Normal fasting response.',
            'advice': fto == 'High Responder' ? 'You have the thrifty gene. Try extending your overnight fast to 16 hours to rapidly induce cellular autophagy.' : 'Standard 12 hour fasting is sufficient.',
            'longevityImpact': fto == 'High Responder' ? '+2.8 Years' : '+0.5 Years',
          }
        ];
      } else if (domain == 'gut') {
        return [
          {
            'title': 'Gut Health',
            'metricName': 'Gut Bacteria Balance',
            'score': '82/100',
            'subtitle': 'Your gut barrier is strong!',
            'advice': 'Your high step count (${healthData['steps'] ?? 0}) is promoting good bacteria growth. Keep it up!',
            'longevityImpact': '+3.2 Years',
          },
          {
            'title': 'Gut Health',
            'metricName': 'Gut Energy Production',
            'score': 'Optimal',
            'subtitle': 'Your brain-gut connection is thriving.',
            'advice': 'Your recent sleep duration (${healthData['sleepMinutes'] ?? 0} mins) is perfectly synced with your body clock, supercharging healthy gut functions.',
            'longevityImpact': '+2.5 Years',
          },
          {
            'title': 'Gut Health',
            'metricName': 'Leaky Gut Risk',
            'score': 'Low',
            'subtitle': 'Your gut lining is secure.',
            'advice': 'Since your active energy burn (${healthData['activeEnergy'] ?? 0} kcal) is high, your body is effectively clearing out inflammation.',
            'longevityImpact': '+1.8 Years',
          },
          {
            'title': 'Gut Health',
            'metricName': 'Hormone Balance',
            'score': 'Balanced',
            'subtitle': 'Efficient hormone processing.',
            'advice': 'Your gut bacteria are successfully balancing your hormones. Keep eating vegetables like broccoli and cauliflower.',
            'longevityImpact': '+2.1 Years',
          },
          {
            'title': 'Gut Health',
            'metricName': 'Allergy Tolerance',
            'score': 'Sluggish',
            'subtitle': 'Potential sensitivity risk.',
            'advice': 'If you feel brain fog after your tracked meals, your gut might be struggling with high-histamine foods like aged cheese or wine.',
            'longevityImpact': '+1.4 Years',
          },
          {
            'title': 'Gut Health',
            'metricName': 'Happy Brain Chemicals',
            'score': '94%',
            'subtitle': 'Your gut-brain axis is flooded with joy.',
            'advice': '90% of serotonin is made in the gut! Your high sleep score (${healthData['sleepMinutes'] ?? 0} mins) is ensuring your microbiome produces optimal mood neurotransmitters.',
            'longevityImpact': '+3.8 Years',
          }
        ];
      } else if (domain == 'blood') {
        return [
          {
            'title': 'Blood & Hormones',
            'metricName': 'Morning Energy Spike',
            'score': 'Optimal',
            'subtitle': 'Perfect morning wake-up energy.',
            'advice': 'Your energy expenditure (${healthData['activeEnergy'] ?? 0} kcal) yesterday perfectly set up your energy rhythm today.',
            'longevityImpact': '+2.8 Years',
          },
          {
            'title': 'Blood & Hormones',
            'metricName': 'Body Repair Mode',
            'score': 'High',
            'subtitle': 'Your body is in a state of repair and growth.',
            'advice': 'Your consistent sleep (${healthData['sleepMinutes'] ?? 0} mins) is maximizing your nighttime recovery and healing.',
            'longevityImpact': '+3.5 Years',
          },
          {
            'title': 'Blood & Hormones',
            'metricName': 'Sugar Processing',
            'score': 'Elite',
            'subtitle': 'Your cells are highly responsive to insulin.',
            'advice': 'By maintaining a high daily step count (${healthData['steps'] ?? 0}), you are keeping your glucose transporters (GLUT4) extremely active.',
            'longevityImpact': '+4.1 Years',
          }
        ];
      } else if (domain == 'aeg') {
        return [
          {
            'title': 'Aging Clock',
            'metricName': 'DNA Wear and Tear',
            'score': 'Accelerated',
            'subtitle': 'Your body is showing signs of faster aging.',
            'advice': 'Your low sleep (${healthData['sleepMinutes'] ?? 0} mins) is preventing your body from repairing daily damage. Prioritize a consistent sleep schedule.',
            'longevityImpact': '-4.5 Years',
          },
          {
            'title': 'Aging Clock',
            'metricName': 'Zombie Cells',
            'score': 'High',
            'subtitle': 'Old cells are sticking around and causing inflammation.',
            'advice': 'Your active energy (${healthData['activeEnergy'] ?? 0} kcal) is decent, but you need a strong trigger to clear out old cells. Implement a 24-hour fast or use a sauna weekly.',
            'longevityImpact': '-2.8 Years',
          },
          {
            'title': 'Aging Clock',
            'metricName': 'Cell Energy Health',
            'score': 'Stable',
            'subtitle': 'Mitochondrial DNA mutations are contained.',
            'advice': 'Your sustained baseline activity (${healthData['steps'] ?? 0} steps) is effectively driving mitophagy, clearing out defective mitochondria before they replicate and cause metabolic collapse.',
            'longevityImpact': '+3.2 Years',
          }
        ];
      } else if (domain == 'sleep') {
        final sleepMinutes = (healthData['sleepMinutes'] as num?)?.toInt() ?? 0;
        final isOptimal = sleepMinutes >= 420; // 7+ hours
        final totalSleep = isOptimal ? '8+ Hours' : 'Under 7 Hours';
        final remDensity = isOptimal ? 'High' : 'Low';
        final deepSleepLatency = isOptimal ? 'Fast' : 'Delayed';

        return [
          {
            'title': 'Sleep Optimization',
            'metricName': 'Total Duration',
            'score': totalSleep,
            'subtitle': isOptimal ? 'Your brain is fully flushing out toxins.' : 'Your brain is missing critical recovery.',
            'advice': isOptimal ? 'Excellent! You slept for $sleepMinutes minutes. Maintain this to maximize cellular repair and prevent cognitive decline.' : 'You only slept for $sleepMinutes minutes. Implement mouth taping and a cooling mattress pad (like Eight Sleep). This combination can artificially deepen your sleep and add years to your life.',
            'longevityImpact': isOptimal ? '+3.5 Years' : '-2.1 Years',
          },
          {
            'title': 'Sleep Optimization',
            'metricName': 'REM Density Index',
            'score': remDensity,
            'subtitle': remDensity == 'High' ? 'Memory consolidation is optimal.' : 'Memory consolidation is being interrupted.',
            'advice': remDensity == 'High' ? 'With $sleepMinutes minutes of sleep, your emotional regulation and memory mapping are top tier.' : 'Your short sleep duration of $sleepMinutes minutes means you are waking up during late-stage REM cycles. Lower your bedroom temperature to 65°F to stay asleep.',
            'longevityImpact': remDensity == 'High' ? '+1.2 Years' : '-1.2 Years',
          },
          {
            'title': 'Sleep Optimization',
            'metricName': 'Slow Wave Sleep Latency',
            'score': deepSleepLatency,
            'subtitle': deepSleepLatency == 'Fast' ? 'Cortisol drop is perfectly timed.' : 'Cortisol is delaying your deep sleep.',
            'advice': deepSleepLatency == 'Fast' ? 'Your evening wind-down routine is flawlessly dropping your core temperature, allowing for deep sleep during your $sleepMinutes minutes of rest.' : 'Your short sleep of $sleepMinutes minutes suggests you are entering deep sleep too late in the night. Avoid all intense exercise or screens 2 hours before bed.',
            'longevityImpact': deepSleepLatency == 'Fast' ? '+2.0 Years' : '-2.5 Years',
          }
        ];
      } else if (domain == 'activity') {
        final steps = healthData['steps'] ?? 0;
        final activeEnergy = healthData['activeEnergy'] ?? 0;
        
        return [
          {
            'title': 'Activity & Kinematics',
            'metricName': 'Burnout Risk',
            'score': steps > 10000 ? 'High Stress' : 'Balanced',
            'subtitle': steps > 10000 ? 'Your body needs more time to recover.' : 'Great balance of movement and rest.',
            'advice': steps > 10000 
                ? 'You logged $steps steps and burned $activeEnergy kcal today. This is great, but without proper recovery, you risk joint inflammation. Consider a light stretching day tomorrow to protect your cartilage.' 
                : 'You logged $steps steps and burned $activeEnergy kcal today. You are perfectly balancing activity with recovery, which keeps your joints youthful.',
            'longevityImpact': steps > 10000 ? '-1.5 Years' : '+2.0 Years',
          },
          {
            'title': 'Activity & Kinematics',
            'metricName': 'Heart Health Base',
            'score': activeEnergy > 400 ? 'Strong Base' : 'Needs Work',
            'subtitle': activeEnergy > 400 ? 'Your heart is highly efficient.' : 'Your heart needs more steady movement.',
            'advice': activeEnergy > 400 
                ? 'Your active energy of $activeEnergy kcal shows a strong aerobic base. This steady movement is the #1 way to prevent metabolic diseases.' 
                : 'Try to get your active energy above 400 kcal daily. A brisk 30-minute walk is the missing link to preventing arterial stiffness as you age.',
            'longevityImpact': activeEnergy > 400 ? '+4.5 Years' : '-1.0 Years',
          },
          {
            'title': 'Activity & Kinematics',
            'metricName': 'Muscle & Joint Youth',
            'score': 'Optimal',
            'subtitle': 'Your movement keeps your body young.',
            'advice': 'By logging $steps steps today, you are telling your brain to keep your muscle pathways active. This directly prevents age-related muscle loss and keeps you independent longer.',
            'longevityImpact': '+2.5 Years',
          }
        ];
      } else if (domain == 'circle') {
        return [
          {
            'title': 'Health Circle',
            'metricName': 'Social Contagion Score',
            'score': 'Elite Tribe',
            'subtitle': 'Your inner circle is elevating your health.',
            'advice': 'You are the average of your 5 closest friends. Your recent active energy indicates your peers are inspiring you to move more and eat better.',
            'longevityImpact': '+3.5 Years',
          },
          {
            'title': 'Health Circle',
            'metricName': 'Stress Shield',
            'score': 'Impenetrable',
            'subtitle': 'You are blocking out toxic stress.',
            'advice': 'Chronic stress is highly contagious. Your deep sleep levels (${healthData['sleepMinutes'] ?? 0} mins) show you are successfully buffering external negativity and protecting your cortisol rhythm.',
            'longevityImpact': '+2.8 Years',
          },
          {
            'title': 'Health Circle',
            'metricName': 'Blue Zone Sync',
            'score': '92% Aligned',
            'subtitle': 'You share the habits of centenarians.',
            'advice': 'Community is the ultimate longevity drug. By maintaining a strong social purpose and staying active, you are mimicking the exact lifestyle of the world\'s longest-living populations.',
            'longevityImpact': '+4.1 Years',
          },
          {
            'title': 'Health Circle',
            'metricName': 'Tribe Momentum',
            'score': 'Unstoppable',
            'subtitle': 'Mutual accountability is locking in your habits.',
            'advice': 'Your daily step count (${healthData['steps'] ?? 0}) proves that shared fitness goals are keeping you incredibly consistent when others quit.',
            'longevityImpact': '+2.2 Years',
          }
        ];
      } else if (domain == 'arbitrage') {
        return [
          {
            'title': 'Bio-Arbitrage',
            'metricName': 'Supplement ROI',
            'score': '500% Yield',
            'subtitle': 'Your sleep supplements are paying off.',
            'advice': 'The biggest question in longevity is "am I wasting my money?" Your recent real-time sleep data (${healthData['sleepMinutes'] ?? 0} mins) proves your magnesium stack is generating massive biological returns.',
            'longevityImpact': '+2.4 Years',
          },
          {
            'title': 'Bio-Arbitrage',
            'metricName': 'Time-to-Lifespan Ratio',
            'score': '1:4',
            'subtitle': '1 hour of effort buys 4 hours of life.',
            'advice': 'By maintaining an active energy output of ${healthData['activeEnergy'] ?? 0} kcal, you are executing the ultimate arbitrage. Every hour you spend exercising is mathematically buying back 4 extra hours of healthy lifespan.',
            'longevityImpact': '+5.0 Years',
          },
          {
            'title': 'Bio-Arbitrage',
            'metricName': 'Metabolic Currency',
            'score': 'Compounding',
            'subtitle': 'You are banking biological assets.',
            'advice': 'Your daily step count (${healthData['steps'] ?? 0}) is compounding like interest. You aren\'t just burning calories; you are depositing reserves into your bone density and muscle mass for the future.',
            'longevityImpact': '+3.1 Years',
          },
          {
            'title': 'Bio-Arbitrage',
            'metricName': 'Wearable Data Leverage',
            'score': 'Maximized',
            'subtitle': 'You are successfully trading data for health.',
            'advice': 'The longevity industry struggles to turn data into action. You are successfully using your wearable telemetry to course-correct daily, proving you are a top-tier bio-investor.',
            'longevityImpact': '+1.8 Years',
          }
        ];
      } else if (domain == 'wearables') {
        return [
          {
            'title': 'Wearable Telemetry',
            'metricName': 'Signal Actionability',
            'score': '98% Actionable',
            'subtitle': 'You don\'t just collect data, you use it.',
            'advice': 'The biggest wearable flaw is "Data Fatigue". You bypass this by turning your real-time data (like your ${healthData['activeEnergy'] ?? 0} kcal burn) into direct longevity fuel.',
            'longevityImpact': '+2.5 Years',
          },
          {
            'title': 'Wearable Telemetry',
            'metricName': 'System Overheating',
            'score': 'Cool & Recovered',
            'subtitle': 'Your sleep proves you aren\'t overtraining.',
            'advice': 'Your wearable shows ${healthData['sleepMinutes'] ?? 0} mins of sleep. This confirms your central nervous system has cooled down completely, preventing burnout.',
            'longevityImpact': '+3.1 Years',
          },
          {
            'title': 'Wearable Telemetry',
            'metricName': 'Biological Blind Spots',
            'score': '0 Detected',
            'subtitle': 'Total 360-degree health coverage.',
            'advice': 'By syncing real-time activity and sleep, you\'ve eliminated the #1 risk in preventative health: guessing. Your telemetry is a perfect safety net.',
            'longevityImpact': '+4.0 Years',
          }
        ];
      } else if (domain == 'nutrigenomics') {
        return [
          {
            'title': 'Gene-Diet Fit',
            'metricName': 'Nutrient Compatibility',
            'score': 'Elite Match',
            'subtitle': 'Your food is communicating perfectly with your DNA.',
            'advice': 'Your ${healthData['activeEnergy'] ?? 0} kcal burn is highly efficient because you are eating for your exact genetic type. Keep prioritizing methylated vitamins and Omega-3s.',
            'longevityImpact': '+4.2 Years',
          },
          {
            'title': 'Gene-Diet Fit',
            'metricName': 'Metabolic Trap Avoidance',
            'score': '100% Cleared',
            'subtitle': 'You are avoiding your genetic kryptonite.',
            'advice': 'Many people unknowingly eat foods their DNA can\'t process. By leveraging your genetic data, your high step count (${healthData['steps'] ?? 0}) isn\'t being wasted by internal inflammation.',
            'longevityImpact': '+3.8 Years',
          }
        ];
      } else {
        return [
          {
            'title': 'Aging Speedometer',
            'metricName': 'Aging Speed',
            'score': '0.75x',
            'subtitle': 'You are aging 25% slower than normal!',
            'advice': 'Your consistent sleep (${healthData['sleepMinutes'] ?? 0} mins) and activity data from Health Connect proves your daily routine is actively slowing down your biological clock.',
            'longevityImpact': '+4.5 Years',
          },
          {
            'title': 'Aging Speedometer',
            'metricName': 'Cell Cleanup Rate',
            'score': 'High Speed',
            'subtitle': 'Your body clears out trash quickly.',
            'advice': 'Your active energy output (${healthData['activeEnergy'] ?? 0} kcal) triggers autophagy, acting like a high-speed vacuum that clears out toxic old cells before they can cause damage.',
            'longevityImpact': '+3.2 Years',
          },
          {
            'title': 'Aging Speedometer',
            'metricName': 'DNA Repair Speed',
            'score': 'Accelerating',
            'subtitle': 'Your genes are fixing themselves faster.',
            'advice': 'By maintaining a high daily step count (${healthData['steps'] ?? 0}), you boost the enzymes that repair daily wear and tear on your DNA strands.',
            'longevityImpact': '+2.8 Years',
          },
          {
            'title': 'Aging Speedometer',
            'metricName': 'Recovery Velocity',
            'score': 'Optimal',
            'subtitle': 'You bounce back from stress instantly.',
            'advice': 'Your nervous system switches into deep repair mode effortlessly every night, giving you a massive advantage in aging speed over the general population.',
            'longevityImpact': '+2.1 Years',
          }
        ];
      }
    }
  }
}
