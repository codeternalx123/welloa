import 'dart:math';
import '../models/health_subcategories_data.dart';

/// UNICORN GRADE: AI-Powered Health Search Engine
/// Features: Natural Language Understanding, Symptom Mapping,
/// Fuzzy Matching, Semantic Search, and Intelligent Suggestions

class HealthAISearchService {
  static final HealthAISearchService _instance = HealthAISearchService._internal();
  factory HealthAISearchService() => _instance;
  HealthAISearchService._internal();

  /// AI Search Result Model
  static List<AISearchResult> performAISearch(String query, {bool searchGoals = true, bool searchConditions = true}) {
    if (query.trim().isEmpty) return [];

    final results = <AISearchResult>[];
    final normalizedQuery = query.toLowerCase().trim();

    // 1. Check symptom mapping first (only for conditions - symptomToConditionMap maps to conditions)
    if (searchConditions) {
      final symptomMatches = _findSymptomMatches(normalizedQuery);
      for (final match in symptomMatches) {
        results.add(AISearchResult(
          item: match,
          matchType: AIMatchType.symptomBased,
          confidence: 0.95,
          explanation: 'Based on symptoms you described',
        ));
      }
    }
    
    // 1b. Check goal-based symptom mapping (for goals)
    if (searchGoals) {
      final goalMatches = _findGoalMatchesFromDescription(normalizedQuery);
      for (final match in goalMatches) {
        results.add(AISearchResult(
          item: match,
          matchType: AIMatchType.symptomBased,
          confidence: 0.95,
          explanation: 'Based on what you described',
        ));
      }
    }

    // 2. Direct keyword matching
    if (searchGoals) {
      for (final goal in HealthSubcategoriesData.allHealthGoals) {
        final score = _calculateMatchScore(normalizedQuery, goal.toLowerCase());
        if (score > 0.3) {
          results.add(AISearchResult(
            item: goal,
            matchType: AIMatchType.directMatch,
            confidence: score,
            explanation: 'Health goal match',
            category: _findCategoryForItem(goal, isGoal: true),
          ));
        }
      }
    }

    if (searchConditions) {
      for (final condition in HealthSubcategoriesData.allDiseaseConditions) {
        final score = _calculateMatchScore(normalizedQuery, condition.toLowerCase());
        if (score > 0.3) {
          results.add(AISearchResult(
            item: condition,
            matchType: AIMatchType.directMatch,
            confidence: score,
            explanation: 'Health condition match',
            category: _findCategoryForItem(condition, isGoal: false),
          ));
        }
      }
    }

    // 3. Synonym-based matching
    final synonymMatches = _findSynonymMatches(normalizedQuery, searchGoals, searchConditions);
    for (final match in synonymMatches) {
      if (!results.any((r) => r.item == match)) {
        results.add(AISearchResult(
          item: match,
          matchType: AIMatchType.synonymMatch,
          confidence: 0.7,
          explanation: 'Related term match',
        ));
      }
    }

    // 4. Sort by confidence and remove duplicates
    final uniqueResults = <String, AISearchResult>{};
    for (final result in results) {
      if (!uniqueResults.containsKey(result.item) || 
          uniqueResults[result.item]!.confidence < result.confidence) {
        uniqueResults[result.item] = result;
      }
    }

    final sortedResults = uniqueResults.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return sortedResults.take(50).toList();
  }

  /// Find matches based on symptom descriptions
  static List<String> _findSymptomMatches(String query) {
    final matches = <String>[];
    
    for (final entry in HealthSubcategoriesData.symptomToConditionMap.entries) {
      final symptom = entry.key.toLowerCase();
      final conditions = entry.value;
      
      // Check if query contains the symptom phrase
      if (query.contains(symptom) || _fuzzyMatch(query, symptom) > 0.6) {
        matches.addAll(conditions);
      }
      
      // Check individual words
      final queryWords = query.split(' ').where((w) => w.length > 2).toList();
      final symptomWords = symptom.split(' ').where((w) => w.length > 2).toList();
      
      int matchedWords = 0;
      for (final qw in queryWords) {
        for (final sw in symptomWords) {
          if (qw == sw || _fuzzyMatch(qw, sw) > 0.7) {
            matchedWords++;
          }
        }
      }
      
      if (matchedWords >= 2 || (symptomWords.length == 1 && matchedWords == 1)) {
        matches.addAll(conditions);
      }
    }
    
    return matches.toSet().toList();
  }

  /// Find goal matches based on natural language descriptions
  static List<String> _findGoalMatchesFromDescription(String query) {
    final matches = <String>[];
    
    // Map of descriptions/feelings to related health goals
    const descriptionToGoalMap = <String, List<String>>{
      // Energy and fatigue
      'tired': ['Boost Energy Levels', 'Improve Sleep Quality', 'Better Recovery'],
      'fatigue': ['Boost Energy Levels', 'Improve Sleep Quality', 'Manage Fatigue'],
      'exhausted': ['Boost Energy Levels', 'Improve Sleep Quality', 'Better Recovery'],
      'no energy': ['Boost Energy Levels', 'Improve Metabolism'],
      'low energy': ['Boost Energy Levels', 'Improve Metabolism'],
      'sluggish': ['Boost Energy Levels', 'Improve Metabolism', 'Detox Support'],
      
      // Weight management
      'lose weight': ['Weight Loss', 'Fat Burning', 'Improve Metabolism'],
      'losing weight': ['Weight Loss', 'Fat Burning', 'Improve Metabolism'],
      'gain weight': ['Weight Gain', 'Build Muscle', 'Increase Appetite'],
      'gaining weight': ['Weight Management', 'Portion Control'],
      'overweight': ['Weight Loss', 'Fat Burning', 'Portion Control'],
      'underweight': ['Weight Gain', 'Build Muscle', 'Increase Appetite'],
      'belly fat': ['Fat Burning', 'Core Strength', 'Weight Loss'],
      
      // Sleep
      'cant sleep': ['Improve Sleep Quality', 'Reduce Stress', 'Better Recovery'],
      'insomnia': ['Improve Sleep Quality', 'Reduce Stress', 'Relaxation'],
      'sleep better': ['Improve Sleep Quality', 'Better Recovery'],
      'trouble sleeping': ['Improve Sleep Quality', 'Reduce Stress'],
      'wake up tired': ['Improve Sleep Quality', 'Better Recovery', 'Boost Energy Levels'],
      
      // Stress and mental health
      'stressed': ['Reduce Stress', 'Relaxation', 'Mental Wellness'],
      'anxious': ['Reduce Anxiety', 'Relaxation', 'Mental Wellness'],
      'anxiety': ['Reduce Anxiety', 'Relaxation', 'Mental Wellness'],
      'depressed': ['Mood Enhancement', 'Mental Wellness', 'Emotional Balance'],
      'sad': ['Mood Enhancement', 'Mental Wellness', 'Emotional Balance'],
      'brain fog': ['Mental Clarity', 'Cognitive Function', 'Brain Health'],
      'focus': ['Improve Focus', 'Cognitive Function', 'Mental Clarity'],
      'concentrate': ['Improve Focus', 'Cognitive Function', 'Mental Clarity'],
      'memory': ['Improve Memory', 'Brain Health', 'Cognitive Function'],
      
      // Fitness
      'get fit': ['Build Fitness', 'Build Muscle', 'Endurance Training'],
      'build muscle': ['Build Muscle', 'Strength Training', 'Protein Optimization'],
      'stronger': ['Build Strength', 'Build Muscle', 'Resistance Training'],
      'run faster': ['Improve Cardio', 'Endurance Training', 'Athletic Performance'],
      'endurance': ['Endurance Training', 'Improve Cardio', 'Stamina'],
      'flexibility': ['Improve Flexibility', 'Mobility', 'Joint Health'],
      
      // Digestion
      'bloated': ['Reduce Bloating', 'Digestive Health', 'Gut Health'],
      'bloating': ['Reduce Bloating', 'Digestive Health', 'Gut Health'],
      'constipated': ['Digestive Health', 'Gut Health', 'Fiber Intake'],
      'digestion': ['Digestive Health', 'Gut Health', 'Nutrient Absorption'],
      'stomach': ['Digestive Health', 'Gut Health', 'Reduce Bloating'],
      
      // Skin and appearance
      'clear skin': ['Skin Health', 'Clear Complexion', 'Anti-Aging'],
      'acne': ['Skin Health', 'Clear Complexion', 'Hormonal Balance'],
      'aging': ['Anti-Aging', 'Skin Health', 'Longevity'],
      'hair': ['Hair Health', 'Nutrient Optimization', 'Protein Intake'],
      'nails': ['Nail Health', 'Nutrient Optimization', 'Collagen Support'],
      
      // Immunity
      'sick': ['Boost Immunity', 'Immune Support', 'Disease Prevention'],
      'immune': ['Boost Immunity', 'Immune Support', 'Disease Prevention'],
      'getting sick': ['Boost Immunity', 'Immune Support', 'Vitamin C Intake'],
      'cold': ['Boost Immunity', 'Immune Support', 'Recovery'],
      
      // Heart and blood
      'heart': ['Heart Health', 'Cardiovascular Fitness', 'Lower Cholesterol'],
      'blood pressure': ['Lower Blood Pressure', 'Heart Health', 'Reduce Sodium'],
      'cholesterol': ['Lower Cholesterol', 'Heart Health', 'Healthy Fats'],
      
      // Blood sugar
      'blood sugar': ['Blood Sugar Control', 'Stable Energy', 'Reduce Sugar Intake'],
      'sugar cravings': ['Reduce Cravings', 'Blood Sugar Control', 'Balanced Diet'],
      'cravings': ['Reduce Cravings', 'Appetite Control', 'Balanced Diet'],
      
      // General wellness
      'healthier': ['General Wellness', 'Balanced Nutrition', 'Lifestyle Improvement'],
      'feel better': ['General Wellness', 'Boost Energy Levels', 'Mood Enhancement'],
      'more energy': ['Boost Energy Levels', 'Improve Metabolism', 'Better Nutrition'],
      'eat better': ['Balanced Nutrition', 'Clean Eating', 'Meal Planning'],
      'nutrition': ['Balanced Nutrition', 'Nutrient Optimization', 'Vitamin Intake'],
    };
    
    // Check each description pattern
    for (final entry in descriptionToGoalMap.entries) {
      final description = entry.key.toLowerCase();
      final goals = entry.value;
      
      if (query.contains(description) || _fuzzyMatch(query, description) > 0.6) {
        matches.addAll(goals);
      }
    }
    
    // Also check if query matches any existing health goals directly
    for (final goal in HealthSubcategoriesData.allHealthGoals) {
      if (_fuzzyMatch(query, goal.toLowerCase()) > 0.5) {
        matches.add(goal);
      }
    }
    
    return matches.toSet().toList();
  }

  /// Find matches using synonym mapping
  static List<String> _findSynonymMatches(String query, bool searchGoals, bool searchConditions) {
    final matches = <String>[];
    final queryWords = query.split(' ').where((w) => w.length > 2).toList();
    
    for (final entry in HealthSubcategoriesData.searchSynonyms.entries) {
      final keyword = entry.key;
      final synonyms = entry.value;
      
      bool hasMatch = queryWords.any((w) => w == keyword || synonyms.any((s) => w == s));
      
      if (hasMatch) {
        // Search for items containing the keyword or synonyms
        if (searchGoals) {
          for (final goal in HealthSubcategoriesData.allHealthGoals) {
            final goalLower = goal.toLowerCase();
            if (goalLower.contains(keyword) || synonyms.any((s) => goalLower.contains(s))) {
              matches.add(goal);
            }
          }
        }
        
        if (searchConditions) {
          for (final condition in HealthSubcategoriesData.allDiseaseConditions) {
            final condLower = condition.toLowerCase();
            if (condLower.contains(keyword) || synonyms.any((s) => condLower.contains(s))) {
              matches.add(condition);
            }
          }
        }
      }
    }
    
    return matches.toSet().toList();
  }

  /// Calculate match score between query and target
  static double _calculateMatchScore(String query, String target) {
    // Exact match
    if (target == query) return 1.0;
    
    // Contains match
    if (target.contains(query)) return 0.9;
    if (query.contains(target)) return 0.85;
    
    // Word-level matching
    final queryWords = query.split(' ').where((w) => w.length > 2).toList();
    final targetWords = target.split(' ').where((w) => w.length > 2).toList();
    
    if (queryWords.isEmpty || targetWords.isEmpty) return 0.0;
    
    int matchedWords = 0;
    for (final qw in queryWords) {
      for (final tw in targetWords) {
        if (tw.contains(qw) || qw.contains(tw)) {
          matchedWords++;
          break;
        }
        // Fuzzy match for typos
        if (_fuzzyMatch(qw, tw) > 0.7) {
          matchedWords++;
          break;
        }
      }
    }
    
    return matchedWords / queryWords.length;
  }

  /// Fuzzy string matching (Levenshtein-based)
  static double _fuzzyMatch(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final len1 = s1.length;
    final len2 = s2.length;
    
    // Quick check for very different lengths
    if ((len1 - len2).abs() > max(len1, len2) * 0.5) return 0.0;
    
    // Calculate Levenshtein distance
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));
    
    for (int i = 0; i <= len1; i++) matrix[i][0] = i;
    for (int j = 0; j <= len2; j++) matrix[0][j] = j;
    
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    
    final maxLen = max(len1, len2);
    return 1.0 - (matrix[len1][len2] / maxLen);
  }

  /// Find the category for an item
  static String? _findCategoryForItem(String item, {required bool isGoal}) {
    final categories = isGoal 
        ? HealthSubcategoriesData.healthGoalCategories 
        : HealthSubcategoriesData.diseaseCategories;
    
    for (final entry in categories.entries) {
      if (entry.value.contains(item)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Get AI-suggested categories based on query
  static List<String> getSuggestedCategories(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    final suggestions = <String, int>{};
    
    // Check goals categories
    for (final entry in HealthSubcategoriesData.healthGoalCategories.entries) {
      int score = 0;
      for (final item in entry.value) {
        if (item.toLowerCase().contains(normalizedQuery)) {
          score += 2;
        }
      }
      if (entry.key.toLowerCase().contains(normalizedQuery)) {
        score += 5;
      }
      if (score > 0) {
        suggestions[entry.key] = score;
      }
    }
    
    // Check condition categories
    for (final entry in HealthSubcategoriesData.diseaseCategories.entries) {
      int score = 0;
      for (final item in entry.value) {
        if (item.toLowerCase().contains(normalizedQuery)) {
          score += 2;
        }
      }
      if (entry.key.toLowerCase().contains(normalizedQuery)) {
        score += 5;
      }
      if (score > 0) {
        suggestions[entry.key] = (suggestions[entry.key] ?? 0) + score;
      }
    }
    
    final sorted = suggestions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(5).map((e) => e.key).toList();
  }

  /// Get related items for a selected condition/goal
  static List<String> getRelatedItems(String item) {
    final related = <String>[];
    final itemLower = item.toLowerCase();
    
    // Find items in the same category
    String? category;
    bool isGoal = false;
    
    for (final entry in HealthSubcategoriesData.healthGoalCategories.entries) {
      if (entry.value.contains(item)) {
        category = entry.key;
        isGoal = true;
        break;
      }
    }
    
    if (category == null) {
      for (final entry in HealthSubcategoriesData.diseaseCategories.entries) {
        if (entry.value.contains(item)) {
          category = entry.key;
          break;
        }
      }
    }
    
    if (category != null) {
      final categoryItems = isGoal 
          ? HealthSubcategoriesData.healthGoalCategories[category]!
          : HealthSubcategoriesData.diseaseCategories[category]!;
      related.addAll(categoryItems.where((i) => i != item).take(10));
    }
    
    // Find items with similar words
    final itemWords = itemLower.split(' ').where((w) => w.length > 3).toList();
    
    for (final goal in HealthSubcategoriesData.allHealthGoals) {
      if (goal == item) continue;
      final goalLower = goal.toLowerCase();
      for (final word in itemWords) {
        if (goalLower.contains(word) && !related.contains(goal)) {
          related.add(goal);
          break;
        }
      }
    }
    
    for (final condition in HealthSubcategoriesData.allDiseaseConditions) {
      if (condition == item) continue;
      final condLower = condition.toLowerCase();
      for (final word in itemWords) {
        if (condLower.contains(word) && !related.contains(condition)) {
          related.add(condition);
          break;
        }
      }
    }
    
    return related.take(15).toList();
  }

  /// Generate AI explanation for why a condition was suggested
  static String generateExplanation(String query, String result) {
    final queryLower = query.toLowerCase();
    final resultLower = result.toLowerCase();
    
    // Check symptom mapping
    for (final entry in HealthSubcategoriesData.symptomToConditionMap.entries) {
      if (queryLower.contains(entry.key) && entry.value.contains(result)) {
        return 'Commonly associated with "${entry.key}"';
      }
    }
    
    // Check direct match
    if (resultLower.contains(queryLower)) {
      return 'Direct match for "$query"';
    }
    
    // Check word overlap
    final queryWords = queryLower.split(' ').where((w) => w.length > 2).toSet();
    final resultWords = resultLower.split(' ').where((w) => w.length > 2).toSet();
    final overlap = queryWords.intersection(resultWords);
    
    if (overlap.isNotEmpty) {
      return 'Matches: ${overlap.join(", ")}';
    }
    
    return 'Related to your search';
  }
}

/// AI Search Result Model
class AISearchResult {
  final String item;
  final AIMatchType matchType;
  final double confidence;
  final String explanation;
  final String? category;

  AISearchResult({
    required this.item,
    required this.matchType,
    required this.confidence,
    required this.explanation,
    this.category,
  });

  /// Get confidence as percentage string
  String get confidencePercent => '${(confidence * 100).toInt()}%';

  /// Get match type icon
  String get matchIcon {
    switch (matchType) {
      case AIMatchType.symptomBased:
        return '🧠';
      case AIMatchType.directMatch:
        return '✓';
      case AIMatchType.synonymMatch:
        return '🔗';
      case AIMatchType.fuzzyMatch:
        return '~';
      case AIMatchType.relatedMatch:
        return '→';
    }
  }
}

/// Match type enum
enum AIMatchType {
  symptomBased,
  directMatch,
  synonymMatch,
  fuzzyMatch,
  relatedMatch,
}
