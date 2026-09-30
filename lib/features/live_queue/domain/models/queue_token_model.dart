import 'package:flutter/foundation.dart';

enum TokenProgressStatus {
  waiting,
  called,
  withDoctor,
  completed,
  skipped;

  static TokenProgressStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'called':
        return TokenProgressStatus.called;
      case 'with_doctor':
      case 'withdoctor':
        return TokenProgressStatus.withDoctor;
      case 'completed':
        return TokenProgressStatus.completed;
      case 'skipped':
        return TokenProgressStatus.skipped;
      case 'waiting':
      default:
        return TokenProgressStatus.waiting;
    }
  }

  String toDbString() {
    switch (this) {
      case TokenProgressStatus.called:
        return 'called';
      case TokenProgressStatus.withDoctor:
        return 'with_doctor';
      case TokenProgressStatus.completed:
        return 'completed';
      case TokenProgressStatus.skipped:
        return 'skipped';
      case TokenProgressStatus.waiting:
        return 'waiting';
    }
  }
}

@immutable
class QueueTokenModel {
  final String id;
  final String appointmentId;
  final String doctorId;
  final DateTime queueDate;
  final int tokenNumber;
  final TokenProgressStatus status;
  final DateTime? calledAt;
  final DateTime? completedAt;
  final String patientName;
  final String patientPhone;
  final int patientAge;
  final String patientGender;
  final String? consultationReason;

  const QueueTokenModel({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.queueDate,
    required this.tokenNumber,
    this.status = TokenProgressStatus.waiting,
    this.calledAt,
    this.completedAt,
    this.patientName = 'Patient',
    this.patientPhone = '',
    this.patientAge = 30,
    this.patientGender = 'Other',
    this.consultationReason,
  });

  bool get isWaiting => status == TokenProgressStatus.waiting;
  bool get isCalled => status == TokenProgressStatus.called;
  bool get isWithDoctor => status == TokenProgressStatus.withDoctor;
  bool get isCompleted => status == TokenProgressStatus.completed;
  bool get isSkipped => status == TokenProgressStatus.skipped;

  factory QueueTokenModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    // Handle joined appointment/patient profile if returned in join
    final app = json['appointments'] as Map<String, dynamic>?;
    final profile = app?['profiles'] as Map<String, dynamic>?;
    final family = app?['family_members'] as Map<String, dynamic>?;

    String resolvedName = json['patient_name']?.toString() ?? '';
    int resolvedAge = (json['patient_age'] as num?)?.toInt() ?? 0;
    String resolvedGender = json['patient_gender']?.toString() ?? '';

    if (resolvedName.isEmpty) {
      if (family != null) {
        resolvedName = family['name']?.toString() ?? 'Family Member';
        resolvedAge = (family['age'] as num?)?.toInt() ?? 30;
        resolvedGender = family['gender']?.toString() ?? 'Other';
      } else if (profile != null) {
        resolvedName = profile['full_name']?.toString() ?? 'Patient';
      }
    }

    return QueueTokenModel(
      id: json['id']?.toString() ?? '',
      appointmentId: json['appointment_id']?.toString() ?? '',
      doctorId: json['doctor_id']?.toString() ?? '',
      queueDate: parseDate(json['queue_date']),
      tokenNumber: (json['token_number'] as num?)?.toInt() ?? 0,
      status: TokenProgressStatus.fromString(json['status']?.toString()),
      calledAt: parseNullableDate(json['called_at']),
      completedAt: parseNullableDate(json['completed_at']),
      patientName: resolvedName.isNotEmpty ? resolvedName : 'Patient',
      patientPhone: json['patient_phone']?.toString() ?? '',
      patientAge: resolvedAge > 0 ? resolvedAge : 30,
      patientGender: resolvedGender.isNotEmpty ? resolvedGender : 'Other',
      consultationReason: json['consultation_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointment_id': appointmentId,
      'doctor_id': doctorId,
      'queue_date': queueDate.toIso8601String().substring(0, 10),
      'token_number': tokenNumber,
      'status': status.toDbString(),
      'called_at': calledAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'patient_name': patientName,
      'patient_phone': patientPhone,
      'patient_age': patientAge,
      'patient_gender': patientGender,
      'consultation_reason': consultationReason,
    };
  }

  QueueTokenModel copyWith({
    String? id,
    String? appointmentId,
    String? doctorId,
    DateTime? queueDate,
    int? tokenNumber,
    TokenProgressStatus? status,
    DateTime? calledAt,
    DateTime? completedAt,
    String? patientName,
    String? patientPhone,
    int? patientAge,
    String? patientGender,
    String? consultationReason,
  }) {
    return QueueTokenModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      doctorId: doctorId ?? this.doctorId,
      queueDate: queueDate ?? this.queueDate,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      status: status ?? this.status,
      calledAt: calledAt ?? this.calledAt,
      completedAt: completedAt ?? this.completedAt,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      consultationReason: consultationReason ?? this.consultationReason,
    );
  }
}
