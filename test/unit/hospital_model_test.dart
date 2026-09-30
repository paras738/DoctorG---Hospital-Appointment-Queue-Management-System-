import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_g/features/hospitals_map/domain/models/hospital_model.dart';
import 'package:doctor_g/core/utils/distance_calculator.dart';
import 'package:doctor_g/core/config/app_config.dart';

void main() {
  group('HospitalModel Tests', () {
    test('parses hospital model with status determination', () {
      final json = {
        'id': 'hosp-001',
        'name': 'Manipal Hospital',
        'address': 'HAL Old Airport Rd, Bengaluru',
        'city': 'Bengaluru',
        'pincode': '560017',
        'latitude': 12.9592,
        'longitude': 77.6517,
        'distance_meters': 1850.5,
        'emergency_available': true,
        'doctors_today_count': 5,
        'rating': 4.8,
        'phone': '+91 80 2502 4444',
      };

      final hospital = HospitalModel.fromJson(json);
      expect(hospital.name, equals('Manipal Hospital'));
      expect(hospital.emergencyAvailable, isTrue);
      expect(hospital.doctorsTodayCount, equals(5));
      expect(hospital.status, equals(HospitalStatus.busyQueue));
      expect(hospital.distanceMeters, equals(1850.5));
    });

    test('sets closed status when doctorsTodayCount is 0', () {
      final json = {
        'id': 'hosp-002',
        'name': 'Closed Clinic',
        'address': 'Indiranagar',
        'city': 'Bengaluru',
        'pincode': '560038',
        'latitude': 12.9716,
        'longitude': 77.6412,
        'distance_meters': 900.0,
        'emergency_available': false,
        'doctors_today_count': 0,
      };

      final hospital = HospitalModel.fromJson(json);
      expect(hospital.status, equals(HospitalStatus.closed));
    });
  });

  group('Free-Tier Route Cost Rule Tests', () {
    test('enforces route cache threshold at 200 meters', () {
      expect(AppConfig.routeCacheThresholdMeters, equals(200));

      const startLat = 12.9716;
      const startLng = 77.5946;

      // Point 1: User shifted by ~100 meters (within cache limit)
      // Lat shift of 0.0009 is ~100m
      final distShort = DistanceCalculator.haversineDistanceMeters(
        startLat,
        startLng,
        startLat + 0.0008,
        startLng,
      );
      expect(
        distShort,
        lessThan(AppConfig.routeCacheThresholdMeters.toDouble()),
      );

      // Point 2: User moved by ~350 meters (should trigger re-fetch)
      final distLong = DistanceCalculator.haversineDistanceMeters(
        startLat,
        startLng,
        startLat + 0.003,
        startLng,
      );
      expect(
        distLong,
        greaterThan(AppConfig.routeCacheThresholdMeters.toDouble()),
      );
    });
  });
}
