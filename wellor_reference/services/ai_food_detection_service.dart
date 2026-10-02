import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../models/clinical_food_vision_service.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Senior-Level Clinical Vision Service for Wellor
/// Implements Redundancy, Local Localization, and User-Correction Logic
class ClinicalFoodVisionService {
  // Load API key from .env at runtime. Add `GEMINI_API_KEY=your_api_key` to .env
  static String get _geminiApiKey {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('GEMINI_API_KEY is not set in .env. Please configure it.');
      throw Exception('GEMINI_API_KEY not configured. See .env file.');
    }
    return apiKey;
  }

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static ImageLabeler? _labeler;

  /// CORE ORCHESTRATOR: Hierarchical Detection
  /// 1. Cloud Tier (Gemini) + 2. Local Tier (ML Kit) + 3. User Tier (Fail-safe)
  static Future<ClinicalDetectionResult> detectWithCertainty(String imagePath) async {
    // Start local ML Kit labeling immediately for validation/latency masking
    final localLabels = await _getLocalLabels(imagePath);
    
    try {
      final imageFile = File(imagePath);
      final base64Image = base64Encode(await imageFile.readAsBytes());

      // Clinical Prompt: Includes instructions for "Local Names" and "Uncertainty"
      final prompt = _buildClinicalPrompt(localLabels);

      final response = await http.post(
        Uri.parse('$_endpoint?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [
              {'text': prompt},
              {'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}}
            ]
          }],
          'generationConfig': {
            'temperature': 0.1, // Near-zero for deterministic clinical accuracy
            'response_mime_type': 'application/json'
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawJson = data['candidates'][0]['content']['parts'][0]['text'];
        final result = ClinicalDetectionResult.fromJson(jsonDecode(rawJson));

        // FAIL-SAFE: If AI is uncertain (< 85%), trigger "Ask User" logic
        if (result.needsUserClarification) {
          return result.copyWith(status: DetectionStatus.requiresInput);
        }
        
        return result.copyWith(status: DetectionStatus.success);
      }
    } catch (e) {
      debugPrint('Cloud Tier Failed. Reverting to Local Tier logic.');
    }

    // FINAL FALLBACK: Local labels + Manual Input trigger
    return ClinicalDetectionResult.fallback(localLabels);
  }

  static Future<List<String>> _getLocalLabels(String path) async {
    _labeler ??= ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
    final labels = await _labeler!.processImage(InputImage.fromFilePath(path));
    return labels.map((l) => l.label).toList();
  }

  static String _buildClinicalPrompt(List<String> hints) {
    return '''
    ACT AS: Clinical Dietitian & Computer Vision Expert.
    CONTEXT: User has provided an image. Your task is 100% accuracy.
    LOCAL HINTS (from ML Kit): ${hints.join(', ')}

    DIRECTIONS:
    1. Identify all foods. If you see regional/local variations (e.g., Jollof Rice, Ugali, Arepa), use the LOCAL NAME.
    2. Estimate volume in cubic cm and convert to grams based on density.
    3. If any item is obscured or uncertain, set "is_uncertain": true.
    4. Provide clinical-grade macro/micro breakdown.

    RETURN JSON:
    {
      "items": [{
        "name": "Local/Global Name",
        "grams": 150.0,
        "is_uncertain": false,
        "macros": {"calories": 0, "protein": 0, "carbs": 0, "fat": 0},
        "micros": {"sodium_mg": 0, "potassium_mg": 0}
      }],
      "overall_confidence": 0.95
    }
    ''';
  }
}

// Clinical models (DetectedFoodItem, ClinicalDetectionResult, DetectionStatus)
// are defined in `lib/models/clinical_food_vision_service.dart` and imported above.