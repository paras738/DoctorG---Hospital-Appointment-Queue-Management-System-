import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/slot_model.dart';
import '../../domain/models/family_member_model.dart';
import '../../domain/models/appointment_model.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../data/repositories/supabase_booking_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

final selectedBookingDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final selectedSlotProvider = StateProvider<SlotModel?>((ref) => null);

final selectedBookingPatientTypeProvider = StateProvider<String>(
  (ref) => 'self',
); // 'self' or 'family'

final selectedFamilyMemberProvider = StateProvider<FamilyMemberModel?>(
  (ref) => null,
);

final bookingPaymentModeProvider = StateProvider<String>(
  (ref) => 'clinic_pay',
); // 'online_full' or 'clinic_pay'

final doctorSlotsProvider =
    FutureProvider.family<List<SlotModel>, ({String doctorId, DateTime date})>((
      ref,
      arg,
    ) {
      final repo = ref.watch(bookingRepositoryProvider);
      return repo.getAvailableSlots(doctorId: arg.doctorId, date: arg.date);
    });

final familyMembersListProvider = FutureProvider<List<FamilyMemberModel>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getFamilyMembers(user.id);
});

final userAppointmentsListProvider = FutureProvider<List<AppointmentModel>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getUserAppointments(user.id);
});

class BookingSubmissionState {
  final bool isSubmitting;
  final AppointmentModel? appointment;
  final String? conflictError;

  const BookingSubmissionState({
    this.isSubmitting = false,
    this.appointment,
    this.conflictError,
  });

  BookingSubmissionState copyWith({
    bool? isSubmitting,
    AppointmentModel? appointment,
    String? conflictError,
  }) {
    return BookingSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      appointment: appointment ?? this.appointment,
      conflictError: conflictError,
    );
  }
}

final bookingSubmissionControllerProvider =
    StateNotifierProvider<BookingSubmissionController, BookingSubmissionState>((
      ref,
    ) {
      final repo = ref.watch(bookingRepositoryProvider);
      return BookingSubmissionController(repo, ref);
    });

class BookingSubmissionController
    extends StateNotifier<BookingSubmissionState> {
  final BookingRepository _repo;
  final Ref _ref;

  BookingSubmissionController(this._repo, this._ref)
    : super(const BookingSubmissionState());

  Future<AppointmentModel?> confirmBooking({
    required String doctorId,
    required double consultationFee,
  }) async {
    final slot = _ref.read(selectedSlotProvider);
    final user = _ref.read(currentUserProvider);
    final userProfile = _ref.read(authControllerProvider).valueOrNull;
    final patientType = _ref.read(selectedBookingPatientTypeProvider);
    final familyMember = _ref.read(selectedFamilyMemberProvider);
    final paymentMode = _ref.read(bookingPaymentModeProvider);

    if (slot == null || user == null) return null;

    state = state.copyWith(isSubmitting: true, conflictError: null);

    try {
      // 1. Attempt atomic lock on slot
      final locked = await _repo.lockSlot(slotId: slot.id);
      if (!locked) {
        state = state.copyWith(
          isSubmitting: false,
          conflictError: 'Slot was just taken by another patient, please pick another slot.',
        );
        return null;
      }

      // 2. Book appointment with double-booking prevention constraint
      final appointment = await _repo.bookAppointment(
        doctorId: doctorId,
        slotId: slot.id,
        patientId: user.id,
        familyMemberId: patientType == 'family' ? familyMember?.id : null,
        bookingType: paymentMode,
        fee: consultationFee,
        patientName: patientType == 'family' && familyMember != null
            ? familyMember.name
            : (userProfile?.fullName ?? 'Patient'),
      );

      state = state.copyWith(
        isSubmitting: false,
        appointment: appointment,
        conflictError: null,
      );

      // Refresh appointments list
      _ref.refresh(userAppointmentsListProvider);

      return appointment;
    } on SlotConflictException catch (e) {
      state = state.copyWith(isSubmitting: false, conflictError: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        conflictError: e.toString().contains('unique_doctor_slot')
            ? 'Slot was just taken by another patient, please pick another slot.'
            : 'Booking failed: $e',
      );
      return null;
    }
  }

  void reset() {
    state = const BookingSubmissionState();
  }
}
