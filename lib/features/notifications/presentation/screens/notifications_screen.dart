import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/notification_model.dart';
import '../controllers/notification_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(userNotificationsStreamProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        actions: [
          TextButton(
            onPressed: () => controller.markAllAsRead(),
            child: const Text(
              'Mark All Read',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Simulate Notification',
            onSelected: (val) {
              if (val == 'leave_now') {
                controller.simulateQueueLeaveNowAlert(
                  doctorId: '20000000-0000-0000-0000-000000000001',
                  doctorName: 'Dr. Rajesh Sharma',
                  userToken: 12,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Simulated "3 Patients Ahead — Leave Now!" alert',
                    ),
                  ),
                );
              } else if (val == 'delay') {
                controller.simulateDoctorDelayAlert(
                  doctorId: '20000000-0000-0000-0000-000000000001',
                  doctorName: 'Dr. Rajesh Sharma',
                  delayMinutes: 20,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Simulated "Doctor Delay +20 mins" alert'),
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'leave_now',
                child: Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text('Simulate "Leave Now" Alert'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delay',
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_filled,
                      color: Colors.deepOrange,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text('Simulate "Doctor Delay" Alert'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notifsAsync.when(
        data: (notifs) {
          if (notifs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Live queue movements, slot reminders and OPD delays will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notif = notifs[index];
              return _buildNotificationCard(context, notif, controller);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
        error: (err, _) =>
            Center(child: Text('Error loading notifications: $err')),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notif,
    NotificationController controller,
  ) {
    final timeStr = _formatTimestamp(notif.createdAt);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        controller.markAsRead(notif.id);
        final route = notif.targetRoute;
        if (route != null) {
          context.go(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? Colors.grey.shade200
                : AppTheme.primaryTeal.withOpacity(0.4),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored Category Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: notif.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(notif.icon, color: notif.color, size: 24),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (notif.targetRoute != null)
                        const Row(
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: AppTheme.primaryTeal,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }
}
