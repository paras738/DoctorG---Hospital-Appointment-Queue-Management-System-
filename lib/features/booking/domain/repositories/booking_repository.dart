import '../models/slot_model.dart';
import '../models/family_member_model.dart';
import '../models/appointment_model.dart';

class SlotConflictException implements Exception {
  final String message;
  SlotConflictException([
    this.message =
        'Slot was just taken by another patient, please pick another slot.',
  ]);

  @override
  String toString() => message;
}

abstract class BookingRepository {
  /// Fetch real-time available slots for doctor on a specific date
  Future<List<SlotModel>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  });

  /// Atomically locks slot for 5 minutes during patient checkout
  /// Returns false if slot was locked or taken concurrently
  Future<bool> lockSlot({required String slotId});

  /// Confirms booking and issues queue token number
  /// Catches duplicate booking constraint and raises SlotConflictException
  Future<AppointmentModel> bookAppointment({
    required String doctorId,
    required String slotId,
    required String patientId,
    String? familyMemberId,
    required String bookingType, // 'online_full' or 'clinic_pay'
    required double fee,
    String? patientName,
  });

  /// List saved family members for patient
  Future<List<FamilyMemberModel>> getFamilyMembers(String userId);

  /// Add new family member
  Future<FamilyMemberModel> addFamilyMember(FamilyMemberModel member);

  /// List patient's appointments (upcoming and past)
  Future<List<AppointmentModel>> getUserAppointments(String userId);

  /// Cancel appointment
  Future<void> cancelAppointment({
    required String appointmentId,
    required String reason,
  });

  /// Reschedule appointment to a new available slot
  Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newSlotId,
  });
}
