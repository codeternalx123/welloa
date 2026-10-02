import 'dart:convert';
import 'package:crypto/crypto.dart';

class AiCacheService {
  // In-memory cache for the session, backed up by SQLite in a full implementation.
  final Map<String, _CacheEntry> _cache = {};
  
  // Cache lives for 24 hours to avoid re-billing the LLM for identical prompts within a day
  final Duration cacheTTL;

  AiCacheService({this.cacheTTL = const Duration(hours: 24)});

  String _generateHash(String systemPrompt, dynamic userMessage) {
    final rawString = systemPrompt + jsonEncode(userMessage);
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  dynamic getCachedResponse(String systemPrompt, dynamic userMessage) {
    final hash = _generateHash(systemPrompt, userMessage);
    final entry = _cache[hash];

    if (entry != null) {
      if (DateTime.now().difference(entry.timestamp) < cacheTTL) {
        return entry.response;
      } else {
        // Expired
        _cache.remove(hash);
      }
    }
    return null;
  }

  void saveResponse(String systemPrompt, dynamic userMessage, dynamic response) {
    final hash = _generateHash(systemPrompt, userMessage);
    _cache[hash] = _CacheEntry(
      response: response,
      timestamp: DateTime.now(),
    );
  }
}

class _CacheEntry {
  final dynamic response;
  final DateTime timestamp;

  _CacheEntry({required this.response, required this.timestamp});
}
