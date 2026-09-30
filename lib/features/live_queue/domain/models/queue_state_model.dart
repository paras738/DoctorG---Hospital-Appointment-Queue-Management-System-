import 'package:flutter/foundation.dart';

enum QueueStatus { active, paused, ended }

enum QueueAlertLevel {
  waiting,
  leaveNow, // <= 3 patients ahead
  nextInLine, // 1 patient ahead (next)
  serving, // Currently with doctor
  completed, // Turn finished
  skipped, // Missed / No-show
}

@immutable
class QueueStateModel {
  final String doctorId;
  final DateTime queueDate;
  final int currentToken;
  final int lastToken;
  final int avgMinutes;
  final int delayMinutes;
  final QueueStatus status;
  final DateTime updatedAt;

  const QueueStateModel({
    required this.doctorId,
    required this.queueDate,
    required this.currentToken,
    required this.lastToken,
    this.avgMinutes = 15,
    this.delayMinutes = 0,
    this.status = QueueStatus.active,
    required this.updatedAt,
  });

  /// Number of patients strictly ahead of [userToken]
  int patientsAhead(int userToken) {
    if (userToken <= currentToken) return 0;
    return userToken - currentToken - 1;
  }

  /// Calculates dynamic estimated wait time in minutes including any doctor delay
  int estimatedWaitMinutes(int userToken) {
    if (userToken <= currentToken) return 0;
    final queueDiff = userToken - currentToken;
    final baseWait = queueDiff * avgMinutes;
    final totalWait = baseWait + delayMinutes;
    return totalWait > 0 ? totalWait : 0;
  }

  /// Evaluates smart alert trigger for patient notification
  QueueAlertLevel getAlertLevel(int userToken) {
    if (userToken < currentToken) {
      return QueueAlertLevel.completed;
    }
    if (userToken == currentToken) {
      return QueueAlertLevel.serving;
    }
    final ahead = patientsAhead(userToken);
    if (ahead == 0) {
      return QueueAlertLevel.nextInLine;
    }
    if (ahead <= 3) {
      return QueueAlertLevel.leaveNow;
    }
    return QueueAlertLevel.waiting;
  }

  bool get isPaused => status == QueueStatus.paused;
  bool get isEnded => status == QueueStatus.ended;
  bool get isActive => status == QueueStatus.active;

  factory QueueStateModel.fromJson(Map<String, dynamic> json) {
    QueueStatus parseStatus(String? val) {
      switch (val) {
        case 'paused':
          return QueueStatus.paused;
        case 'ended':
          return QueueStatus.ended;
        case 'active':
        default:
          return QueueStatus.active;
      }
    }

    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return QueueStateModel(
      doctorId: json['doctor_id']?.toString() ?? '',
      queueDate: parseDate(json['queue_date']),
      currentToken: (json['current_token'] as num?)?.toInt() ?? 0,
      lastToken: (json['last_token'] as num?)?.toInt() ?? 0,
      avgMinutes: (json['avg_minutes'] as num?)?.toInt() ?? 15,
      delayMinutes: (json['delay_minutes'] as num?)?.toInt() ?? 0,
      status: parseStatus(json['status']?.toString()),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    String statusString(QueueStatus s) {
      switch (s) {
        case QueueStatus.paused:
          return 'paused';
        case QueueStatus.ended:
          return 'ended';
        case QueueStatus.active:
          return 'active';
      }
    }

    return {
      'doctor_id': doctorId,
      'queue_date': queueDate.toIso8601String().substring(0, 10),
      'current_token': currentToken,
      'last_token': lastToken,
      'avg_minutes': avgMinutes,
      'delay_minutes': delayMinutes,
      'status': statusString(status),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  QueueStateModel copyWith({
    String? doctorId,
    DateTime? queueDate,
    int? currentToken,
    int? lastToken,
    int? avgMinutes,
    int? delayMinutes,
    QueueStatus? status,
    DateTime? updatedAt,
  }) {
    return QueueStateModel(
      doctorId: doctorId ?? this.doctorId,
      queueDate: queueDate ?? this.queueDate,
      currentToken: currentToken ?? this.currentToken,
      lastToken: lastToken ?? this.lastToken,
      avgMinutes: avgMinutes ?? this.avgMinutes,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
