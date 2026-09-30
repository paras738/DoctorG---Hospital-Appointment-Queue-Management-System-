import 'package:flutter/material.dart';

enum NotificationType {
  queueAlert,
  reminder,
  delay,
  cancellation,
  availability;

  static NotificationType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'reminder':
        return NotificationType.reminder;
      case 'delay':
        return NotificationType.delay;
      case 'cancellation':
        return NotificationType.cancellation;
      case 'availability':
        return NotificationType.availability;
      case 'queue_alert':
      case 'queuealert':
      default:
        return NotificationType.queueAlert;
    }
  }

  String toDbString() {
    switch (this) {
      case NotificationType.queueAlert:
        return 'queue_alert';
      case NotificationType.reminder:
        return 'reminder';
      case NotificationType.delay:
        return 'delay';
      case NotificationType.cancellation:
        return 'cancellation';
      case NotificationType.availability:
        return 'availability';
    }
  }
}

@immutable
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = NotificationType.queueAlert,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  String? get targetRoute {
    if (data.containsKey('route')) {
      return data['route']?.toString();
    }
    if (data.containsKey('doctor_id')) {
      final docId = data['doctor_id'];
      final token = data['token_number'] ?? '12';
      return '/live-queue/$docId?token=$token';
    }
    if (data.containsKey('appointment_id')) {
      return '/my-appointments';
    }
    return null;
  }

  IconData get icon {
    switch (type) {
      case NotificationType.queueAlert:
        return Icons.directions_car_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.delay:
        return Icons.access_time_filled_rounded;
      case NotificationType.cancellation:
        return Icons.cancel_outlined;
      case NotificationType.availability:
        return Icons.medical_services_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.queueAlert:
        return Colors.orange;
      case NotificationType.reminder:
        return const Color(0xFF00897B); // Primary teal
      case NotificationType.delay:
        return Colors.deepOrange;
      case NotificationType.cancellation:
        return Colors.red;
      case NotificationType.availability:
        return Colors.blue;
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: NotificationType.fromString(json['type']?.toString()),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type.toDbString(),
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
