import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/supabase_notification_repository.dart';
import '../../domain/models/notification_model.dart';

/// StreamProvider autoDisposing notifications for the current authenticated user
final userNotificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
      final user = ref.watch(authControllerProvider).valueOrNull;
      final userId = user?.id ?? '30000000-0000-0000-0000-000000000001';
      final repo = ref.watch(notificationRepositoryProvider);
      return repo.watchNotifications(userId);
    });

/// Provider computing count of unread notifications
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifsAsync = ref.watch(userNotificationsStreamProvider);
  return notifsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

class NotificationController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NotificationController(this._ref) : super(const AsyncValue.data(null));

  Future<void> markAsRead(String notificationId) async {
    final repo = _ref.read(notificationRepositoryProvider);
    await repo.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    final user = _ref.read(authControllerProvider).valueOrNull;
    final userId = user?.id ?? '30000000-0000-0000-0000-000000000001';
    final repo = _ref.read(notificationRepositoryProvider);
    await repo.markAllAsRead(userId);
  }

  Future<void> simulateQueueLeaveNowAlert({
    required String doctorId,
    required String doctorName,
    required int userToken,
  }) async {
    final user = _ref.read(authControllerProvider).valueOrNull;
    final userId = user?.id ?? '30000000-0000-0000-0000-000000000001';
    final repo = _ref.read(notificationRepositoryProvider);

    await repo.sendNotification(
      userId: userId,
      title: '🚗 Time to Leave for Clinic Now!',
      body:
          'Only 3 patients ahead of you for $doctorName. Please start traveling now.',
      type: NotificationType.queueAlert,
      data: {
        'doctor_id': doctorId,
        'token_number': userToken.toString(),
        'route': '/live-queue/$doctorId?token=$userToken',
      },
    );
  }

  Future<void> simulateDoctorDelayAlert({
    required String doctorId,
    required String doctorName,
    required int delayMinutes,
  }) async {
    final user = _ref.read(authControllerProvider).valueOrNull;
    final userId = user?.id ?? '30000000-0000-0000-0000-000000000001';
    final repo = _ref.read(notificationRepositoryProvider);

    await repo.sendNotification(
      userId: userId,
      title: '⚠️ Doctor OPD Delay Alert',
      body:
          '$doctorName is running $delayMinutes mins delayed due to an emergency.',
      type: NotificationType.delay,
      data: {'doctor_id': doctorId, 'delay_minutes': delayMinutes.toString()},
    );
  }
}

final notificationControllerProvider =
    StateNotifierProvider.autoDispose<NotificationController, AsyncValue<void>>(
      (ref) => NotificationController(ref),
    );
