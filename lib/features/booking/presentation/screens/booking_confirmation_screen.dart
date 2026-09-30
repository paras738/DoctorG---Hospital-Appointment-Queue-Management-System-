import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/appointment_model.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final String appointmentId;
  final AppointmentModel? appointment;

  const BookingConfirmationScreen({
    super.key,
    required this.appointmentId,
    this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final token = appointment?.tokenNumber ?? 12;
    final docName = appointment?.doctorName ?? 'Dr. Specialist';
    final dateStr = appointment != null
        ? DateFormat('EEEE, MMM d, yyyy').format(appointment!.appointmentDate)
        : DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());
    final timeStr = appointment?.formattedSlotTime ?? '11:15 AM';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success Animated Badge
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLightTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryTeal, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primaryTeal,
                      size: 54,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Appointment Confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Booking details and queue confirmation have been saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Large Token Number Display Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.primaryTeal.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryTeal.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR OPD QUEUE TOKEN',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDarkTeal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '#$token',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryDarkTeal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              size: 14,
                              color: Color(0xFFE65100),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Estimated wait: ~35 min',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Appointment Details Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.person_outline, 'Doctor', docName),
                      const Divider(height: 16),
                      _buildDetailRow(
                        Icons.calendar_today_outlined,
                        'Date',
                        dateStr,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(Icons.schedule, 'Time Slot', timeStr),
                      const Divider(height: 16),
                      _buildDetailRow(
                        Icons.payments_outlined,
                        'Payment',
                        appointment?.bookingType == 'clinic_pay'
                            ? 'Pay at Clinic (Free Token)'
                            : 'Paid Online',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Add to Calendar Action
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.event_available,
                    color: AppTheme.secondaryBlue,
                  ),
                  label: const Text('Add to Device Calendar'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Appointment reminder added to calendar'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Live Queue Button (Phase 5 key differentiator)
                FilledButton.icon(
                  icon: const Icon(Icons.stream),
                  label: const Text('Watch Live Queue Position'),
                  onPressed: () {
                    if (appointment != null) {
                      context.go('/live-queue/${appointment!.doctorId}');
                    } else {
                      context.go('/home');
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Back to Home
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
