import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/supabase_client.dart';
import '../../domain/models/notification_model.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    return SupabaseNotificationRepository(supabase);
  } catch (_) {
    return SupabaseNotificationRepository(null);
  }
});

class SupabaseNotificationRepository implements NotificationRepository {
  final SupabaseClient? _supabase;
  final _uuid = const Uuid();

  // In-memory notifications fallback cache
  static final Map<String, List<NotificationModel>> _userNotifications = {};
  static final Map<String, StreamController<List<NotificationModel>>>
  _streamControllers = {};

  SupabaseNotificationRepository(this._supabase);

  StreamController<List<NotificationModel>> _getOrCreateController(
    String userId,
  ) {
    if (!_streamControllers.containsKey(userId) ||
        _streamControllers[userId]!.isClosed) {
      _streamControllers[userId] =
          StreamController<List<NotificationModel>>.broadcast();
    }
    return _streamControllers[userId]!;
  }

  List<NotificationModel> _getOrCreateInitialNotifications(String userId) {
    return _userNotifications.putIfAbsent(userId, () {
      final now = DateTime.now();
      return [
        NotificationModel(
          id: 'notif-1',
          userId: userId,
          title: '🚗 Time to Leave for Clinic Now!',
          body: 'You are 3 patients away from Dr. Rajesh Sharma. Estimated wait: ~35 min.',
          type: NotificationType.queueAlert,
          data: {
            'doctor_id': '20000000-0000-0000-0000-000000000001',
            'token_number': '12',
          },
          isRead: false,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        NotificationModel(
          id: 'notif-2',
          userId: userId,
          title: '⚠️ Doctor OPD Delay Alert',
          body: 'Dr. Rajesh Sharma is running 15 min delayed due to an emergency case.',
          type: NotificationType.delay,
          data: {
            'doctor_id': '20000000-0000-0000-0000-000000000001',
            'delay_minutes': '15',
          },
          isRead: false,
          createdAt: now.subtract(const Duration(minutes: 25)),
        ),
        NotificationModel(
          id: 'notif-3',
          userId: userId,
          title: '✅ Appointment Confirmed',
          body: 'Your slot for Cardiology consultation has been confirmed for today at 10:30 AM.',
          type: NotificationType.reminder,
          data: {'route': '/my-appointments'},
          isRead: true,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        NotificationModel(
          id: 'notif-4',
          userId: userId,
          title: '🩺 Doctor Available Now',
          body: 'Dr. Sunita Kulkarni is now available for walk-in live queue tokens at Manipal Hospital.',
          type: NotificationType.availability,
          data: {
            'doctor_id': '20000000-0000-0000-0000-000000000002',
            'route': '/doctor/20000000-0000-0000-0000-000000000002',
          },
          isRead: true,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
    });
  }

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    if (_supabase != null) {
      try {
        final response = await _supabase!
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final rawList = response as List<dynamic>;
        if (rawList.isNotEmpty) {
          final list = rawList
              .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
              .toList();
          _userNotifications[userId] = list;
          return list;
        }
      } catch (_) {}
    }

    return _getOrCreateInitialNotifications(userId);
  }

  @override
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    final controller = _getOrCreateController(userId);

    if (_supabase != null) {
      try {
        // Scoped strictly to current user's notifications (free tier friendly)
        final subStream = _supabase!
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        return subStream
            .map((rawList) {
              if (rawList.isEmpty) {
                return _getOrCreateInitialNotifications(userId);
              }
              final list = rawList
                  .map((j) => NotificationModel.fromJson(j))
                  .toList();
              _userNotifications[userId] = list;
              return list;
            })
            .handleError((_) {
              return _getOrCreateInitialNotifications(userId);
            });
      } catch (_) {}
    }

    final initial = _getOrCreateInitialNotifications(userId);
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(initial);
      }
    });
    return controller.stream;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    for (final list in _userNotifications.values) {
      final index = list.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        list[index] = list[index].copyWith(isRead: true);
        final userId = list[index].userId;
        if (_streamControllers.containsKey(userId)) {
          _streamControllers[userId]!.add(List.from(list));
        }
        break;
      }
    }

    if (_supabase != null) {
      try {
        await _supabase!
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      } catch (_) {}
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    final list = _getOrCreateInitialNotifications(userId);
    for (int i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(isRead: true);
    }
    _userNotifications[userId] = list;

    if (_streamControllers.containsKey(userId)) {
      _streamControllers[userId]!.add(List.from(list));
    }

    if (_supabase != null) {
      try {
        await _supabase!
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId);
      } catch (_) {}
    }
  }

  @override
  Future<void> syncDeviceToken({
    required String userId,
    required String fcmToken,
    String deviceType = 'android',
  }) async {
    if (_supabase != null) {
      try {
        await _supabase!.from('device_tokens').upsert({
          'user_id': userId,
          'fcm_token': fcmToken,
          'device_type': deviceType,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id, fcm_token');
      } catch (_) {}
    }
  }

  @override
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    NotificationType type = NotificationType.queueAlert,
    Map<String, dynamic>? data,
  }) async {
    final notif = NotificationModel(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data ?? {},
      isRead: false,
      createdAt: DateTime.now(),
    );

    final list = _getOrCreateInitialNotifications(userId);
    list.insert(0, notif);
    _userNotifications[userId] = list;

    if (_streamControllers.containsKey(userId)) {
      _streamControllers[userId]!.add(List.from(list));
    }

    if (_supabase != null) {
      try {
        // Try invoking Edge Function send-fcm-notification
        await _supabase!.functions.invoke(
          'send-fcm-notification',
          body: {
            'user_id': userId,
            'title': title,
            'body': body,
            'type': type.toDbString(),
            'data': data ?? {},
          },
        );
      } catch (_) {
        // If edge function not yet deployed, fallback directly to DB insert
        try {
          await _supabase!.from('notifications').insert(notif.toJson());
        } catch (_) {}
      }
    }
  }
}
