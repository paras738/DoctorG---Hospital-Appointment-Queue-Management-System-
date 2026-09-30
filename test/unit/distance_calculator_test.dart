import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_g/core/utils/distance_calculator.dart';

void main() {
  group('DistanceCalculator', () {
    test('calculates accurate distance between known Bangalore points', () {
      // Manipal Hospital Old Airport Rd (12.9592, 77.6517)
      // Fortis Hospital Cunningham Rd (12.9882, 77.5947)
      final distance = DistanceCalculator.haversineDistanceMeters(
        12.9592,
        77.6517,
        12.9882,
        77.5947,
      );

      // Expected straight line distance ~6.9 to ~7.1 km (approx 7000m)
      expect(distance, greaterThan(6500));
      expect(distance, lessThan(7500));
    });

    test('formats meters and kilometers correctly', () {
      expect(DistanceCalculator.formatDistance(450), equals('450 m'));
      expect(DistanceCalculator.formatDistance(1250), equals('1.3 km'));
      expect(DistanceCalculator.formatDistance(5000), equals('5.0 km'));
    });
  });
}
