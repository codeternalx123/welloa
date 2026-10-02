import 'dart:async';
import 'package:flutter/foundation.dart';
import '../error/failures.dart';

enum CircuitState { closed, open, halfOpen }

class CircuitBreaker {
  final int maxFailures;
  final Duration resetTimeout;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  Timer? _resetTimer;

  CircuitBreaker({
    this.maxFailures = 3,
    this.resetTimeout = const Duration(minutes: 5),
  });

  CircuitState get state => _state;

  Future<T> execute<T>(Future<T> Function() action) async {
    if (_state == CircuitState.open) {
      throw const ServerFailure('Circuit breaker is OPEN. API calls are suspended to save tokens and prevent hangs.');
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    if (_state == CircuitState.halfOpen) {
      debugPrint('CircuitBreaker: Action succeeded. Circuit CLOSED.');
      _state = CircuitState.closed;
      _failureCount = 0;
    }
  }

  void _onFailure() {
    _failureCount++;
    if (_failureCount >= maxFailures) {
      if (_state != CircuitState.open) {
        debugPrint('CircuitBreaker: Max failures reached (\$_failureCount). Circuit OPENED.');
        _state = CircuitState.open;
        
        // Schedule half-open state
        _resetTimer?.cancel();
        _resetTimer = Timer(resetTimeout, () {
          debugPrint('CircuitBreaker: Timeout reached. Circuit HALF-OPEN.');
          _state = CircuitState.halfOpen;
        });
      }
    }
  }
}
