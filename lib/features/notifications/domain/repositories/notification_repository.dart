import '../models/notification_model.dart';

abstract class NotificationRepository {
  /// Fetch all notifications for current user
  Future<List<NotificationModel>> getNotifications(String userId);

  /// Watch real-time stream of incoming notifications scoped strictly to the current user
  Stream<List<NotificationModel>> watchNotifications(String userId);

  /// Mark specific notification as read
  Future<void> markAsRead(String notificationId);

  /// Mark all notifications as read for current user
  Future<void> markAllAsRead(String userId);

  /// Store / update FCM device token in Supabase
  Future<void> syncDeviceToken({
    required String userId,
    required String fcmToken,
    String deviceType = 'android',
  });

  /// Trigger a notification (via Edge Function or test simulation)
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    NotificationType type = NotificationType.queueAlert,
    Map<String, dynamic>? data,
  });
}
