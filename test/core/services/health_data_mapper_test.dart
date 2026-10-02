import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:longevity/core/services/health/health_data_mapper.dart';
import 'package:mocktail/mocktail.dart';

class MockHealthDataPoint extends Mock implements HealthDataPoint {}
class MockNumericHealthValue extends Mock implements NumericHealthValue {}

void main() {
  group('HealthDataMapper', () {
    late MockHealthDataPoint point1;
    late MockHealthDataPoint point2;
    late MockHealthDataPoint invalidPoint;
    late MockHealthDataPoint hrvValid;
    late MockHealthDataPoint hrvTooHigh;
    late MockHealthDataPoint hrvTooLow;

    setUp(() {
      point1 = MockHealthDataPoint();
      point2 = MockHealthDataPoint();
      invalidPoint = MockHealthDataPoint();
      hrvValid = MockHealthDataPoint();
      hrvTooHigh = MockHealthDataPoint();
      hrvTooLow = MockHealthDataPoint();

      final val1 = MockNumericHealthValue();
      when(() => val1.numericValue).thenReturn(100.0);
      when(() => point1.value).thenReturn(val1);
      when(() => point1.dateFrom).thenReturn(DateTime(2023, 10, 1, 8, 0));

      final val2 = MockNumericHealthValue();
      when(() => val2.numericValue).thenReturn(50.0);
      when(() => point2.value).thenReturn(val2);
      when(() => point2.dateFrom).thenReturn(DateTime(2023, 10, 1, 14, 0));

      // Negative value
      final valInvalid = MockNumericHealthValue();
      when(() => valInvalid.numericValue).thenReturn(-500.0);
      when(() => invalidPoint.value).thenReturn(valInvalid);
      when(() => invalidPoint.dateFrom).thenReturn(DateTime(2023, 10, 1, 10, 0));

      // HRV
      final valHrvValid = MockNumericHealthValue();
      when(() => valHrvValid.numericValue).thenReturn(55.0);
      when(() => hrvValid.value).thenReturn(valHrvValid);
      when(() => hrvValid.dateFrom).thenReturn(DateTime(2023, 10, 1, 7, 0));

      final valHrvHigh = MockNumericHealthValue();
      when(() => valHrvHigh.numericValue).thenReturn(300.0);
      when(() => hrvTooHigh.value).thenReturn(valHrvHigh);
      when(() => hrvTooHigh.dateFrom).thenReturn(DateTime(2023, 10, 1, 8, 0));

      final valHrvLow = MockNumericHealthValue();
      when(() => valHrvLow.numericValue).thenReturn(5.0);
      when(() => hrvTooLow.value).thenReturn(valHrvLow);
      when(() => hrvTooLow.dateFrom).thenReturn(DateTime(2023, 10, 1, 9, 0));
    });

    test('aggregateByDay sums valid points by date', () {
      final data = [point1, point2, invalidPoint];
      final result = HealthDataMapper.aggregateByDay(data, sum: true);

      final targetDate = DateTime(2023, 10, 1);
      expect(result.containsKey(targetDate), isTrue);
      // Only 100 and 50 should be summed, -500 is ignored
      expect(result[targetDate], equals(150.0));
    });

    test('aggregateByDay averages valid points by date', () {
      final data = [point1, point2, invalidPoint];
      final result = HealthDataMapper.aggregateByDay(data, sum: false);

      final targetDate = DateTime(2023, 10, 1);
      expect(result.containsKey(targetDate), isTrue);
      // (100 + 50) / 2 = 75.0, ignoring negative -500
      expect(result[targetDate], equals(75.0));
    });

    test('extractLatestHRV filters physically impossible bounds', () {
      // It should skip 300 (too high) and 5 (too low), and find 55.
      final result = HealthDataMapper.extractLatestHRV([hrvTooHigh, hrvTooLow, hrvValid]);
      expect(result, equals(55.0));
    });

    test('extractLatestHRV returns null if no valid entries', () {
      final result = HealthDataMapper.extractLatestHRV([hrvTooHigh, hrvTooLow]);
      expect(result, isNull);
    });
  });
}
