import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/appointment_model.dart';
import '../controllers/booking_controller.dart';
import '../../data/repositories/supabase_booking_repository.dart';
import '../../../reviews/presentation/widgets/leave_review_sheet.dart';

class MyAppointmentsScreen extends ConsumerStatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  ConsumerState<MyAppointmentsScreen> createState() =>
      _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends ConsumerState<MyAppointmentsScreen> {
  int _tabIndex = 0; // 0 = Upcoming, 1 = Past

  void _showCancelDialog(AppointmentModel app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cancellation & Refund Policy:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '• Pay at Clinic bookings can be cancelled anytime with zero penalty.\n'
              '• Online prepaid bookings receive an automated 100% refund if cancelled at least 2 hours prior to the slot.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to cancel your slot with ${app.doctorName}?',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Appointment'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(bookingRepositoryProvider)
                  .cancelAppointment(
                    appointmentId: app.id,
                    reason: 'Cancelled by patient',
                  );
              ref.refresh(userAppointmentsListProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appointment cancelled successfully.'),
                  ),
                );
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _openLeaveReviewSheet(AppointmentModel app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LeaveReviewSheet(
        appointmentId: app.id,
        doctorId: app.doctorId,
        doctorName: app.doctorName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(userAppointmentsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments & Tokens'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Upcoming Slots')),
                ButtonSegment(value: 1, label: Text('Past / Completed')),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (val) =>
                  setState(() => _tabIndex = val.first),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(userAppointmentsListProvider),
        color: AppTheme.primaryTeal,
        child: appointmentsAsync.when(
          data: (appointments) {
            final now = DateTime.now();
            final filtered = _tabIndex == 0
                ? appointments
                      .where(
                        (a) =>
                            a.slotStart.isAfter(now) && a.status != 'cancelled',
                      )
                      .toList()
                : appointments
                      .where(
                        (a) =>
                            a.slotStart.isBefore(now) ||
                            a.status == 'cancelled',
                      )
                      .toList();

            if (filtered.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabIndex == 0 ? Icons.event_available : Icons.history,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tabIndex == 0
                            ? 'No upcoming appointments'
                            : 'No past appointments',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tabIndex == 0
                            ? 'Book a consultation slot with top doctors nearby.'
                            : 'Your consultation history will appear here.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final app = filtered[index];
                return _buildAppointmentCard(app);
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryTeal),
          ),
          error: (err, _) =>
              Center(child: Text('Error loading appointments: $err')),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel app) {
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(app.appointmentDate);

    Color statusColor = AppTheme.successGreen;
    if (app.status == 'cancelled') statusColor = AppTheme.alertRed;
    if (app.status == 'in_progress') statusColor = AppTheme.accentAmber;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Token # + Status Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightTeal,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryTeal),
                  ),
                  child: Text(
                    'TOKEN #${app.tokenNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDarkTeal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    app.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Doctor & Hospital
            Text(
              app.doctorName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${app.doctorSpecialization} • ${app.hospitalName ?? "Clinic OPD"}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),

            // Date & Slot Time
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 15,
                  color: AppTheme.secondaryBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  '$dateStr at ${app.formattedSlotTime}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),

            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Live Queue Button
                if (app.status == 'confirmed' || app.status == 'in_progress')
                  FilledButton.icon(
                    icon: const Icon(Icons.stream, size: 16),
                    label: const Text(
                      'Live Queue',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      minimumSize: const Size(100, 36),
                    ),
                    onPressed: () => context.go(
                      '/live-queue/${app.doctorId}?token=${app.tokenNumber}',
                    ),
                  )
                else if (app.status == 'completed')
                  FilledButton.icon(
                    icon: const Icon(Icons.star_rounded, size: 16),
                    label: const Text(
                      'Leave Review',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentAmber,
                      foregroundColor: Colors.brown.shade900,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      minimumSize: const Size(110, 36),
                    ),
                    onPressed: () => _openLeaveReviewSheet(app),
                  )
                else
                  const SizedBox.shrink(),

                // Cancel Button
                if (app.canCancel)
                  OutlinedButton(
                    onPressed: () => _showCancelDialog(app),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertRed,
                      side: const BorderSide(color: AppTheme.alertRed),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
