import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_g/features/booking/domain/models/slot_model.dart';
import 'package:doctor_g/features/booking/domain/models/appointment_model.dart';
import 'package:doctor_g/features/booking/domain/models/family_member_model.dart';

void main() {
  group('SlotModel & Double-Booking Protection Tests', () {
    final now = DateTime.now();

    test('verifies slot availability with atomic lock timeout', () {
      // 1. Available and unlocked
      final slot1 = SlotModel(
        id: 'slot-1',
        doctorId: 'doc-1',
        slotDate: now,
        slotStart: now.add(const Duration(hours: 1)),
        slotEnd: now.add(const Duration(hours: 1, minutes: 15)),
        isLocked: false,
        status: 'available',
      );
      expect(slot1.isAvailable, isTrue);

      // 2. Locked with future expiry (e.g. user currently in checkout)
      final slot2 = SlotModel(
        id: 'slot-2',
        doctorId: 'doc-1',
        slotDate: now,
        slotStart: now.add(const Duration(hours: 2)),
        slotEnd: now.add(const Duration(hours: 2, minutes: 15)),
        isLocked: true,
        lockedUntil: now.add(const Duration(minutes: 4)),
        status: 'available',
      );
      expect(slot2.isAvailable, isFalse);

      // 3. Locked but lock timed out (> 5 min elapsed without checkout)
      final slot3 = SlotModel(
        id: 'slot-3',
        doctorId: 'doc-1',
        slotDate: now,
        slotStart: now.add(const Duration(hours: 3)),
        slotEnd: now.add(const Duration(hours: 3, minutes: 15)),
        isLocked: true,
        lockedUntil: now.subtract(const Duration(minutes: 1)),
        status: 'available',
      );
      expect(slot3.isAvailable, isTrue);

      // 4. Already booked
      final slot4 = SlotModel(
        id: 'slot-4',
        doctorId: 'doc-1',
        slotDate: now,
        slotStart: now.add(const Duration(hours: 4)),
        slotEnd: now.add(const Duration(hours: 4, minutes: 15)),
        isLocked: false,
        status: 'booked',
      );
      expect(slot4.isAvailable, isFalse);
    });

    test('categorizes slot time periods correctly', () {
      final morningSlot = SlotModel(
        id: 's1',
        doctorId: 'd1',
        slotDate: now,
        slotStart: DateTime(now.year, now.month, now.day, 10, 15),
        slotEnd: DateTime(now.year, now.month, now.day, 10, 30),
        isLocked: false,
        status: 'available',
      );
      expect(morningSlot.timePeriod, equals('Morning'));
      expect(morningSlot.formattedTime, equals('10:15 AM'));

      final eveningSlot = SlotModel(
        id: 's2',
        doctorId: 'd1',
        slotDate: now,
        slotStart: DateTime(now.year, now.month, now.day, 17, 45),
        slotEnd: DateTime(now.year, now.month, now.day, 18, 00),
        isLocked: false,
        status: 'available',
      );
      expect(eveningSlot.timePeriod, equals('Evening'));
      expect(eveningSlot.formattedTime, equals('5:45 PM'));
    });
  });

  group('AppointmentModel & Cancellation Policy Tests', () {
    test('enforces refund cancellation window for online vs clinic bookings', () {
      final now = DateTime.now();

      // Clinic pay booking allows cancellation anytime before slot
      final clinicApp = AppointmentModel(
        id: 'app-1',
        doctorId: 'doc-1',
        doctorName: 'Dr. Rajesh Sharma',
        doctorSpecialization: 'Cardiologist',
        patientId: 'patient-1',
        patientName: 'Rohan Verma',
        slotId: 'slot-1',
        appointmentDate: now,
        slotStart: now.add(const Duration(minutes: 45)),
        slotEnd: now.add(const Duration(hours: 1)),
        tokenNumber: 8,
        status: 'confirmed',
        bookingType: 'clinic_pay',
        consultationFee: 800.0,
        createdAt: now,
      );
      expect(clinicApp.canCancel, isTrue);

      // Online prepaid booking allows refund only if >= 2 hours prior to slot
      final prepaidFar = AppointmentModel(
        id: 'app-2',
        doctorId: 'doc-1',
        doctorName: 'Dr. Rajesh Sharma',
        doctorSpecialization: 'Cardiologist',
        patientId: 'patient-1',
        patientName: 'Rohan Verma',
        slotId: 'slot-2',
        appointmentDate: now,
        slotStart: now.add(const Duration(hours: 4)),
        slotEnd: now.add(const Duration(hours: 4, minutes: 15)),
        tokenNumber: 9,
        status: 'confirmed',
        bookingType: 'online_full',
        consultationFee: 800.0,
        createdAt: now,
      );
      expect(prepaidFar.canCancel, isTrue);

      final prepaidClose = AppointmentModel(
        id: 'app-3',
        doctorId: 'doc-1',
        doctorName: 'Dr. Rajesh Sharma',
        doctorSpecialization: 'Cardiologist',
        patientId: 'patient-1',
        patientName: 'Rohan Verma',
        slotId: 'slot-3',
        appointmentDate: now,
        slotStart: now.add(const Duration(minutes: 30)),
        slotEnd: now.add(const Duration(minutes: 45)),
        tokenNumber: 10,
        status: 'confirmed',
        bookingType: 'online_full',
        consultationFee: 800.0,
        createdAt: now,
      );
      expect(prepaidClose.canCancel, isFalse);
    });
  });

  group('FamilyMemberModel Tests', () {
    test('serializes and deserializes family member accurately', () {
      final member = FamilyMemberModel(
        id: 'fam-01',
        userId: 'user-01',
        name: 'Aarav Verma',
        relationship: 'Child',
        age: 6,
        gender: 'Male',
      );

      final json = member.toJson();
      expect(json['name'], equals('Aarav Verma'));
      expect(json['relationship'], equals('Child'));
      expect(json['age'], equals(6));

      final recreated = FamilyMemberModel.fromJson(json);
      expect(recreated.name, equals(member.name));
      expect(recreated.age, equals(6));
    });
  });
}
