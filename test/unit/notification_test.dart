import 'package:flutter_test/flutter_test.dart';
import 'package:doctorg/features/notifications/domain/models/notification_model.dart';
import 'package:doctorg/features/notifications/data/repositories/supabase_notification_repository.dart';

void main() {
  group('NotificationModel Tests', () {
    final now = DateTime.now();

    test('initializes and parses correctly from JSON', () {
      final json = {
        'id': 'notif-123',
        'user_id': 'user-456',
        'title': '🚗 Leave for Clinic Now!',
        'body': 'Only 3 patients ahead for Dr. Rajesh Sharma',
        'type': 'queue_alert',
        'data': {'doctor_id': 'doc-789', 'token_number': '14'},
        'is_read': false,
        'created_at': now.toIso8601String(),
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, equals('notif-123'));
      expect(model.userId, equals('user-456'));
      expect(model.title, contains('Leave for Clinic'));
      expect(model.type, equals(NotificationType.queueAlert));
      expect(model.isRead, isFalse);
      expect(model.targetRoute, equals('/live-queue/doc-789?token=14'));
    });

    test('resolves direct route when provided in data payload', () {
      final notif = NotificationModel(
        id: 'n1',
        userId: 'u1',
        title: 'Appointment Confirmed',
        body: 'Your slot is confirmed',
        type: NotificationType.reminder,
        data: {'route': '/my-appointments'},
        isRead: true,
        createdAt: now,
      );

      expect(notif.targetRoute, equals('/my-appointments'));
      expect(notif.type, equals(NotificationType.reminder));
    });

    test('serializes to JSON correctly', () {
      final notif = NotificationModel(
        id: 'n2',
        userId: 'u2',
        title: 'Doctor Delayed',
        body: 'Running 20 min late',
        type: NotificationType.delay,
        data: {'delay_minutes': 20},
        isRead: false,
        createdAt: now,
      );

      final json = notif.toJson();
      expect(json['id'], equals('n2'));
      expect(json['type'], equals('delay'));
      expect(json['is_read'], isFalse);

      final recreated = NotificationModel.fromJson(json);
      expect(recreated.type, equals(NotificationType.delay));
      expect(recreated.title, equals(notif.title));
    });
  });

  group('SupabaseNotificationRepository Tests', () {
    final repo = SupabaseNotificationRepository(null);
    const testUserId = 'test-user-999';

    test('returns default notifications for user', () async {
      final notifs = await repo.getNotifications(testUserId);
      expect(notifs, isNotEmpty);
      expect(notifs.first.userId, equals(testUserId));
    });

    test('marks individual notification as read', () async {
      final initial = await repo.getNotifications(testUserId);
      final unread = initial.firstWhere((n) => !n.isRead);

      await repo.markAsRead(unread.id);

      final updated = await repo.getNotifications(testUserId);
      final target = updated.firstWhere((n) => n.id == unread.id);
      expect(target.isRead, isTrue);
    });

    test('marks all notifications as read', () async {
      await repo.markAllAsRead(testUserId);

      final updated = await repo.getNotifications(testUserId);
      final unreadCount = updated.where((n) => !n.isRead).length;
      expect(unreadCount, equals(0));
    });

    test('sending notification prepends to list and broadcasts', () async {
      await repo.sendNotification(
        userId: testUserId,
        title: '🚨 Test Emergency Notice',
        body: 'OPD delayed briefly',
        type: NotificationType.delay,
        data: {'doctor_id': 'doc-1'},
      );

      final notifs = await repo.getNotifications(testUserId);
      expect(notifs.first.title, contains('Test Emergency Notice'));
      expect(notifs.first.type, equals(NotificationType.delay));
    });
  });
}
