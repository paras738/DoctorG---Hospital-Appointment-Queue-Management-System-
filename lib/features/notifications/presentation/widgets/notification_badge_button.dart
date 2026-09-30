import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/notification_controller.dart';

class NotificationBadgeButton extends ConsumerWidget {
  final Color iconColor;

  const NotificationBadgeButton({super.key, this.iconColor = Colors.white});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: iconColor),
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.alertRed,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
