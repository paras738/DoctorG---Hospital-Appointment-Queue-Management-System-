import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_notification_repository.dart';
import '../../domain/models/notification_model.dart';

final fcmNotificationServiceProvider = Provider<FcmNotificationService>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return FcmNotificationService(repo);
});

class FcmNotificationService {
  final dynamic _repository;
  bool _isInitialized = false;

  FcmNotificationService(this._repository);

  /// Initializes FCM permissions, retrieves device token and configures message handlers
  Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;

    // FCM operates on Android, iOS, and Web with native Firebase setup
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        // Ensure Firebase Core is initialized
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }

        final messaging = FirebaseMessaging.instance;

        // 1. Request notification permissions (Android 13+ / iOS)
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          // 2. Fetch FCM device token
          final token = await messaging.getToken();
          if (token != null) {
            await _repository.syncDeviceToken(
              userId: userId,
              fcmToken: token,
              deviceType: defaultTargetPlatform == TargetPlatform.android
                  ? 'android'
                  : 'ios',
            );
          }

          // 3. Listen to token refreshes
          messaging.onTokenRefresh.listen((newToken) {
            _repository.syncDeviceToken(
              userId: userId,
              fcmToken: newToken,
              deviceType: defaultTargetPlatform == TargetPlatform.android
                  ? 'android'
                  : 'ios',
            );
          });

          // 4. Foreground message listener
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            final notification = message.notification;
            if (notification != null) {
              _repository.sendNotification(
                userId: userId,
                title: notification.title ?? 'DoctorG Alert',
                body: notification.body ?? '',
                type: NotificationType.fromString(message.data['type']),
                data: message.data,
              );
            }
          });
        }
      } catch (err) {
        // Safe fallback in test or simulator environment
        debugPrint('FCM Native setup note: $err');
      }
    }

    _isInitialized = true;
  }
}
