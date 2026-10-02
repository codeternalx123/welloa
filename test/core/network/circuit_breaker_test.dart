import 'package:flutter_test/flutter_test.dart';
import 'package:longevity/core/network/circuit_breaker.dart';
import 'package:longevity/core/error/failures.dart';

void main() {
  late CircuitBreaker circuitBreaker;

  setUp(() {
    circuitBreaker = CircuitBreaker(
      maxFailures: 3,
      resetTimeout: const Duration(milliseconds: 100),
    );
  });

  group('CircuitBreaker', () {
    test('initial state should be closed', () {
      expect(circuitBreaker.state, CircuitState.closed);
    });

    test('successful execution keeps circuit closed', () async {
      final result = await circuitBreaker.execute(() async => 'success');
      expect(result, 'success');
      expect(circuitBreaker.state, CircuitState.closed);
    });

    test('opens after max failures', () async {
      // 1st failure
      try {
        await circuitBreaker.execute(() async => throw Exception('1'));
      } catch (_) {}
      expect(circuitBreaker.state, CircuitState.closed);

      // 2nd failure
      try {
        await circuitBreaker.execute(() async => throw Exception('2'));
      } catch (_) {}
      expect(circuitBreaker.state, CircuitState.closed);

      // 3rd failure (trips circuit)
      try {
        await circuitBreaker.execute(() async => throw Exception('3'));
      } catch (_) {}
      expect(circuitBreaker.state, CircuitState.open);
    });

    test('throws ServerFailure immediately when open without executing action', () async {
      // Trip the circuit
      for (int i = 0; i < 3; i++) {
        try {
          await circuitBreaker.execute(() async => throw Exception('error'));
        } catch (_) {}
      }

      expect(circuitBreaker.state, CircuitState.open);

      bool actionExecuted = false;
      try {
        await circuitBreaker.execute(() async {
          actionExecuted = true;
          return 'should not run';
        });
        fail('Should have thrown ServerFailure');
      } catch (e) {
        expect(e, isA<ServerFailure>());
        expect(actionExecuted, false);
      }
    });

    test('transitions to halfOpen after timeout and then closes on success', () async {
      // Trip the circuit
      for (int i = 0; i < 3; i++) {
        try {
          await circuitBreaker.execute(() async => throw Exception('error'));
        } catch (_) {}
      }

      expect(circuitBreaker.state, CircuitState.open);

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 150));
      expect(circuitBreaker.state, CircuitState.halfOpen);

      // Execute successful action while halfOpen
      final result = await circuitBreaker.execute(() async => 'success');
      
      expect(result, 'success');
      expect(circuitBreaker.state, CircuitState.closed);
    });

    test('transitions from halfOpen back to open on failure', () async {
      // Trip the circuit
      for (int i = 0; i < 3; i++) {
        try {
          await circuitBreaker.execute(() async => throw Exception('error'));
        } catch (_) {}
      }

      // Wait for timeout to become halfOpen
      await Future.delayed(const Duration(milliseconds: 150));
      expect(circuitBreaker.state, CircuitState.halfOpen);

      // Execute failing action while halfOpen
      try {
        await circuitBreaker.execute(() async => throw Exception('error again'));
      } catch (_) {}
      
      // Should instantly trip back to open since we use maxFailures.
      // Note: In our current implementation, it increments failure count. Since it's already >= 3, it instantly goes back to OPEN.
      expect(circuitBreaker.state, CircuitState.open);
    });
  });
}
