import 'package:flutter_test/flutter_test.dart';
import 'package:longevity/core/services/ai_cache_service.dart';

void main() {
  late AiCacheService aiCacheService;

  setUp(() {
    // We use a short TTL for testing expiration
    aiCacheService = AiCacheService(cacheTTL: const Duration(milliseconds: 100));
  });

  group('AiCacheService', () {
    test('returns null for cache miss', () {
      final result = aiCacheService.getCachedResponse('System Prompt', 'User Message');
      expect(result, isNull);
    });

    test('returns cached response for identical prompts', () {
      final systemPrompt = 'You are a bot';
      final userMessage = 'Hello';
      final mockResponse = {'reply': 'Hi there'};

      aiCacheService.saveResponse(systemPrompt, userMessage, mockResponse);

      final result = aiCacheService.getCachedResponse(systemPrompt, userMessage);
      
      expect(result, equals(mockResponse));
    });

    test('returns null for different prompts', () {
      final systemPrompt = 'You are a bot';
      final mockResponse = {'reply': 'Hi there'};

      aiCacheService.saveResponse(systemPrompt, 'Hello', mockResponse);

      final result1 = aiCacheService.getCachedResponse(systemPrompt, 'Different Message');
      final result2 = aiCacheService.getCachedResponse('Different System', 'Hello');

      expect(result1, isNull);
      expect(result2, isNull);
    });

    test('returns null when cache TTL expires', () async {
      final systemPrompt = 'You are a bot';
      final userMessage = 'Hello';
      final mockResponse = {'reply': 'Hi there'};

      aiCacheService.saveResponse(systemPrompt, userMessage, mockResponse);

      // Verify it's cached
      expect(aiCacheService.getCachedResponse(systemPrompt, userMessage), isNotNull);

      // Wait for TTL to expire
      await Future.delayed(const Duration(milliseconds: 150));

      // Verify it's expired and evicted
      final resultAfterExpiry = aiCacheService.getCachedResponse(systemPrompt, userMessage);
      expect(resultAfterExpiry, isNull);
    });
  });
}
