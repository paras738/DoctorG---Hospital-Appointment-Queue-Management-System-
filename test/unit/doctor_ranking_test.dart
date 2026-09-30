import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_g/features/doctor_directory/domain/models/doctor_model.dart';
import 'package:doctor_g/features/doctor_directory/domain/models/doctor_filter.dart';

void main() {
  group('Bayesian Ranking & Doctor Model Tests', () {
    test('computes Bayesian score formula correctly', () {
      // Formula: (v / (v + m)) * R + (m / (v + m)) * C + (0.25 if available now)
      // m = 10, C = 4.0
      const m = 10.0;
      const c = 4.0;

      double computeScore(double r, int v, bool availableNow) {
        final base = ((v / (v + m)) * r) + ((m / (v + m)) * c);
        return base + (availableNow ? 0.25 : 0.0);
      }

      // Case 1: Doctor with 50 reviews, average 4.8, not available now
      final scoreDoc1 = computeScore(4.8, 50, false);
      // (50/60)*4.8 + (10/60)*4.0 = 4.0 + 0.6667 = 4.667
      expect(scoreDoc1, closeTo(4.667, 0.01));

      // Case 2: Doctor with 2 reviews, average 5.0 (untested), not available now
      final scoreDoc2 = computeScore(5.0, 2, false);
      // (2/12)*5.0 + (10/12)*4.0 = 0.833 + 3.333 = 4.167
      // Bayesian pulls score towards global average 4.0
      expect(scoreDoc2, closeTo(4.167, 0.01));
      expect(scoreDoc1, greaterThan(scoreDoc2));

      // Case 3: Availability boost gives +0.25 edge
      final scoreDoc2Boosted = computeScore(5.0, 2, true);
      expect(scoreDoc2Boosted, closeTo(4.417, 0.01));
    });

    test('DoctorModel serialization preserves Bayesian score and top rated flag', () {
      final doc = DoctorModel(
        id: 'doc-001',
        fullName: 'Dr. Rajesh Sharma',
        registrationNumber: 'KMC-10001',
        specialization: 'Cardiologist',
        experienceYears: 18,
        consultationFee: 800.0,
        languages: const ['English', 'Hindi'],
        isVerified: true,
        isAvailableToday: true,
        isAvailableNow: true,
        avgConsultationMinutes: 15,
        reviewCount: 52,
        avgRating: 4.8,
        bayesianScore: 4.917,
        isTopRated: true,
        hospitalName: 'Fortis Hospital',
        hospitalAddress: 'Cunningham Rd, Bengaluru',
        distanceMeters: 2300,
      );

      final json = doc.toJson();
      expect(json['doctor_id'], equals('doc-001'));
      expect(json['is_top_rated'], isTrue);
      expect(json['bayesian_score'], equals(4.917));
      expect(json['consultation_fee'], equals(800.0));

      final recreated = DoctorModel.fromJson(json);
      expect(recreated.id, equals(doc.id));
      expect(recreated.fullName, equals(doc.fullName));
      expect(recreated.isTopRated, isTrue);
      expect(recreated.hospitalName, equals('Fortis Hospital'));
    });
  });

  group('DoctorFilter Tests', () {
    test('detects active filters and counts accurately', () {
      var filter = const DoctorFilter();
      expect(filter.hasActiveFilters, isFalse);
      expect(filter.activeFilterCount, equals(0));

      filter = filter.copyWith(specialization: 'Dermatologist');
      expect(filter.hasActiveFilters, isTrue);
      expect(filter.activeFilterCount, equals(1));

      filter = filter.copyWith(availableNow: true);
      expect(filter.activeFilterCount, equals(2));

      filter = filter.copyWith(sortBy: DoctorSortBy.distanceNearest);
      expect(filter.activeFilterCount, equals(3));

      final reset = filter.reset();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.activeFilterCount, equals(0));
    });
  });
}
