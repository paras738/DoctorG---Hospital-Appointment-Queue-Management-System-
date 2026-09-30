import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_g/features/auth/domain/models/user_profile.dart';

void main() {
  group('UserProfile and UserRole', () {
    test('parses UserRole accurately from string', () {
      expect(UserRole.fromString('patient'), equals(UserRole.patient));
      expect(UserRole.fromString('doctor'), equals(UserRole.doctor));
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      expect(UserRole.fromString('UNKNOWN'), equals(UserRole.patient));
    });

    test('serializes and deserializes UserProfile correctly', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'user-123',
        email: 'patient@example.com',
        phone: '+919988776655',
        fullName: 'Rohan Verma',
        role: UserRole.patient,
        createdAt: now,
      );

      final json = profile.toJson();
      expect(json['id'], equals('user-123'));
      expect(json['role'], equals('patient'));

      final recreated = UserProfile.fromJson(json);
      expect(recreated.id, equals(profile.id));
      expect(recreated.email, equals(profile.email));
      expect(recreated.fullName, equals(profile.fullName));
      expect(recreated.role, equals(UserRole.patient));
    });
  });
}
