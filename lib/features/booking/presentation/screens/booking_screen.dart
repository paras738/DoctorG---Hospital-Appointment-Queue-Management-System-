import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/slot_model.dart';
import '../../domain/models/family_member_model.dart';
import '../controllers/booking_controller.dart';
import '../widgets/add_family_member_sheet.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../doctor_directory/presentation/controllers/doctor_directory_controller.dart';
import '../../../payment/presentation/controllers/payment_controller.dart';
import '../../../payment/presentation/widgets/payment_receipt_sheet.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const BookingScreen({super.key, required this.doctorId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  @override
  void initState() {
    super.initState();
    // Reset selected slot when entering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedSlotProvider.notifier).state = null;
      ref.read(bookingSubmissionControllerProvider.notifier).reset();
    });
  }

  void _openAddFamilyMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddFamilyMemberSheet(),
    );
  }

  Future<void> _handleConfirmBooking(double fee) async {
    final slot = ref.read(selectedSlotProvider);
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available appointment slot'),
        ),
      );
      return;
    }

    final paymentMode = ref.read(bookingPaymentModeProvider);
    final appointment = await ref
        .read(bookingSubmissionControllerProvider.notifier)
        .confirmBooking(doctorId: widget.doctorId, consultationFee: fee);

    if (appointment == null || !mounted) return;

    if (paymentMode == 'online_full') {
      final userProfile = ref.read(authControllerProvider).valueOrNull;
      final doctor = ref
          .read(doctorProfileProvider(widget.doctorId))
          .valueOrNull;

      final payment = await ref
          .read(paymentControllerProvider.notifier)
          .processOnlinePayment(
            appointmentId: appointment.id,
            amount: fee,
            doctorName: doctor != null ? 'Dr. ${doctor.name}' : 'Doctor',
            patientName: appointment.patientName,
            patientPhone: userProfile?.phone ?? '+919999999999',
            patientEmail: userProfile?.email ?? 'patient@doctorg.in',
            mode: 'full',
          );

      if (payment != null && mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => PaymentReceiptSheet(
            payment: payment,
            doctorName: doctor != null ? 'Dr. ${doctor.name}' : 'Doctor',
            hospitalName: doctor?.hospitalName,
            onContinue: () {
              if (mounted) {
                context.go(
                  '/booking-confirmation/${appointment.id}',
                  extra: appointment,
                );
              }
            },
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Online payment was cancelled or failed. Slot is held for 5 minutes. You can retry or choose Pay at Clinic.',
            ),
          ),
        );
      }
    } else {
      context.go('/booking-confirmation/${appointment.id}', extra: appointment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedBookingDateProvider);
    final selectedSlot = ref.watch(selectedSlotProvider);
    final patientType = ref.watch(selectedBookingPatientTypeProvider);
    final selectedFamily = ref.watch(selectedFamilyMemberProvider);
    final paymentMode = ref.watch(bookingPaymentModeProvider);
    final submissionState = ref.watch(bookingSubmissionControllerProvider);
    final paymentState = ref.watch(paymentControllerProvider);
    final isProcessing =
        submissionState.isSubmitting || paymentState.isProcessing;

    final doctorAsync = ref.watch(doctorProfileProvider(widget.doctorId));
    final slotsAsync = ref.watch(
      doctorSlotsProvider((doctorId: widget.doctorId, date: selectedDate)),
    );
    final familyAsync = ref.watch(familyMembersListProvider);
    final userProfile = ref.watch(authControllerProvider).valueOrNull;

    final doctorFee = doctorAsync.valueOrNull?.consultationFee ?? 500.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: doctorAsync.when(
        data: (doctor) {
          if (doctor == null) {
            return const Center(child: Text('Doctor details not available'));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doctor Mini Card
                      _buildDoctorSummary(doctor),
                      const SizedBox(height: 16),

                      // Conflict Error Banner
                      if (submissionState.conflictError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.alertRed,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  submissionState.conflictError!,
                                  style: const TextStyle(
                                    color: AppTheme.alertRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 1. Date Selection Carousel
                      const Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDateCarousel(selectedDate),
                      const SizedBox(height: 20),

                      // 2. Real-time Slot Availability Grid
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Slots',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                            onPressed: () => ref.refresh(
                              doctorSlotsProvider((
                                doctorId: widget.doctorId,
                                date: selectedDate,
                              )),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      slotsAsync.when(
                        data: (slots) => _buildSlotGroups(slots, selectedSlot),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                        error: (err, _) => Text('Could not load slots: $err'),
                      ),
                      const SizedBox(height: 20),

                      // 3. Patient Details Selection
                      const Text(
                        'Patient Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPatientSelector(
                        patientType,
                        userProfile?.fullName,
                        selectedFamily,
                        familyAsync,
                      ),
                      const SizedBox(height: 20),

                      // 4. Payment Mode Option
                      const Text(
                        'Payment Option',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentModeSelector(paymentMode, doctorFee),
                    ],
                  ),
                ),
              ),

              // Bottom Confirmation Bar
              _buildBottomBar(selectedSlot, doctorFee, isProcessing),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDoctorSummary(dynamic doctor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryLightTeal,
            backgroundImage: doctor.photoUrl != null
                ? NetworkImage(doctor.photoUrl)
                : null,
            child: doctor.photoUrl == null
                ? const Icon(Icons.person, color: AppTheme.primaryTeal)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  doctor.specialization,
                  style: const TextStyle(
                    color: AppTheme.secondaryBlue,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${doctor.consultationFee.round()}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDarkTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCarousel(DateTime selectedDate) {
    final now = DateTime.now();
    final dates = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day + i),
    );

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final d = dates[index];
          final isSelected =
              d.year == selectedDate.year &&
              d.month == selectedDate.month &&
              d.day == selectedDate.day;

          final dayName = index == 0 ? 'Today' : DateFormat('E').format(d);
          final dayNum = DateFormat('d').format(d);

          return GestureDetector(
            onTap: () {
              ref.read(selectedBookingDateProvider.notifier).state = d;
              ref.read(selectedSlotProvider.notifier).state =
                  null; // reset slot selection
            },
            child: Container(
              width: 58,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryTeal : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryTeal
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGroups(List<SlotModel> slots, SlotModel? selectedSlot) {
    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No slots available for this date. Please pick another date.',
          ),
        ),
      );
    }

    final morning = slots.where((s) => s.timePeriod == 'Morning').toList();
    final afternoon = slots.where((s) => s.timePeriod == 'Afternoon').toList();
    final evening = slots.where((s) => s.timePeriod == 'Evening').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (morning.isNotEmpty)
          _buildSlotCategory(
            'Morning (09:00 AM - 12:00 PM)',
            morning,
            selectedSlot,
          ),
        if (afternoon.isNotEmpty)
          _buildSlotCategory(
            'Afternoon (12:00 PM - 04:00 PM)',
            afternoon,
            selectedSlot,
          ),
        if (evening.isNotEmpty)
          _buildSlotCategory(
            'Evening (04:00 PM - 08:00 PM)',
            evening,
            selectedSlot,
          ),
      ],
    );
  }

  Widget _buildSlotCategory(
    String title,
    List<SlotModel> slots,
    SlotModel? selectedSlot,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isAvailable = slot.isAvailable;
            final isSelected = selectedSlot?.id == slot.id;

            return InkWell(
              onTap: isAvailable
                  ? () => ref.read(selectedSlotProvider.notifier).state = slot
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryTeal
                      : (isAvailable ? Colors.white : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryTeal
                        : (isAvailable
                              ? AppTheme.primaryTeal.withOpacity(0.4)
                              : Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.formattedTime,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isAvailable
                                  ? Colors.black87
                                  : Colors.grey.shade500),
                        decoration: isAvailable
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    if (!isAvailable) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPatientSelector(
    String patientType,
    String? userName,
    FamilyMemberModel? selectedFamily,
    AsyncValue<List<FamilyMemberModel>> familyAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            dense: true,
            title: Text('Booking for Myself (${userName ?? "Patient"})'),
            value: 'self',
            groupValue: patientType,
            activeColor: AppTheme.primaryTeal,
            onChanged: (val) =>
                ref.read(selectedBookingPatientTypeProvider.notifier).state =
                    val!,
          ),
          RadioListTile<String>(
            dense: true,
            title: const Text('Booking for a Family Member'),
            value: 'family',
            groupValue: patientType,
            activeColor: AppTheme.primaryTeal,
            onChanged: (val) =>
                ref.read(selectedBookingPatientTypeProvider.notifier).state =
                    val!,
          ),
          if (patientType == 'family') ...[
            const Divider(),
            familyAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Family Member Profile'),
                    onPressed: _openAddFamilyMemberSheet,
                  );
                }

                return Column(
                  children: [
                    DropdownButtonFormField<FamilyMemberModel>(
                      value: selectedFamily ?? members.first,
                      decoration: const InputDecoration(
                        labelText: 'Select Member',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: members.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            '${m.name} (${m.relationship}, ${m.age}y)',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          ref
                                  .read(selectedFamilyMemberProvider.notifier)
                                  .state =
                              val,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Another Member'),
                        onPressed: _openAddFamilyMemberSheet,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentModeSelector(String paymentMode, double fee) {
    return Column(
      children: [
        RadioListTile<String>(
          dense: true,
          title: const Text('Pay at Clinic (Free Online Token)'),
          subtitle: const Text(
            'Zero advance fee. Pay consultation amount directly during OPD visit.',
          ),
          value: 'clinic_pay',
          groupValue: paymentMode,
          activeColor: AppTheme.primaryTeal,
          onChanged: (val) =>
              ref.read(bookingPaymentModeProvider.notifier).state = val!,
        ),
        RadioListTile<String>(
          dense: true,
          title: Text('Pay Online Full (₹${fee.round()})'),
          subtitle: const Text('Fast check-in via Razorpay Test Gateway.'),
          value: 'online_full',
          groupValue: paymentMode,
          activeColor: AppTheme.primaryTeal,
          onChanged: (val) =>
              ref.read(bookingPaymentModeProvider.notifier).state = val!,
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    SlotModel? selectedSlot,
    double fee,
    bool isSubmitting,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedSlot != null
                    ? selectedSlot.formattedTime
                    : 'No slot chosen',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Total: ₹${fee.round()}',
                style: const TextStyle(
                  color: AppTheme.primaryDarkTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          FilledButton(
            onPressed: (selectedSlot == null || isSubmitting)
                ? null
                : () => _handleConfirmBooking(fee),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }
}
