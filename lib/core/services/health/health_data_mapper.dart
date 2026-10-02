import 'package:health/health.dart';

class HealthDataMapper {
  /// Sanitizes and groups raw health data points into a daily average or sum
  static Map<DateTime, double> aggregateByDay(List<HealthDataPoint> data, {bool sum = false}) {
    if (data.isEmpty) return {};

    final Map<DateTime, List<double>> dailyValues = {};

    for (var point in data) {
      // Basic sanitization: reject negative values
      final val = _extractValue(point.value);
      if (val < 0) continue;

      final date = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
      if (!dailyValues.containsKey(date)) {
        dailyValues[date] = [];
      }
      dailyValues[date]!.add(val);
    }

    final Map<DateTime, double> aggregated = {};
    dailyValues.forEach((date, values) {
      if (sum) {
        aggregated[date] = values.fold(0.0, (prev, element) => prev + element);
      } else {
        aggregated[date] = values.fold(0.0, (prev, element) => prev + element) / values.length;
      }
    });

    return aggregated;
  }

  static double _extractValue(dynamic value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    // Handle newer health package versions where value might be specific subclasses
    try {
      // Fallback dynamic cast if NumericHealthValue isn't the exact type
      return double.parse(value.toString());
    } catch (e) {
      return 0.0;
    }
  }

  /// Extracts the latest valid heart rate variability score (SDNN/RMSSD)
  static double? extractLatestHRV(List<HealthDataPoint> hrvData) {
    if (hrvData.isEmpty) return null;
    
    // Sort descending by date
    hrvData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
    
    for (var point in hrvData) {
      final val = _extractValue(point.value);
      // Valid HRV SDNN is usually between 20 and 200 ms
      if (val > 10 && val < 250) {
        return val;
      }
    }
    return null;
  }
}
