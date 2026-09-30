import 'package:flutter/foundation.dart';

enum PaymentRecordStatus {
  created,
  captured,
  failed,
  refunded;

  static PaymentRecordStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'captured':
        return PaymentRecordStatus.captured;
      case 'failed':
        return PaymentRecordStatus.failed;
      case 'refunded':
        return PaymentRecordStatus.refunded;
      case 'created':
      default:
        return PaymentRecordStatus.created;
    }
  }

  String toDbString() {
    switch (this) {
      case PaymentRecordStatus.captured:
        return 'captured';
      case PaymentRecordStatus.failed:
        return 'failed';
      case PaymentRecordStatus.refunded:
        return 'refunded';
      case PaymentRecordStatus.created:
        return 'created';
    }
  }
}

@immutable
class PaymentModel {
  final String id;
  final String appointmentId;
  final String razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final double amount;
  final String currency;
  final PaymentRecordStatus status;
  final String mode; // 'full' or 'booking_fee'
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentModel({
    required this.id,
    required this.appointmentId,
    required this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    required this.amount,
    this.currency = 'INR',
    this.status = PaymentRecordStatus.created,
    this.mode = 'full',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCaptured => status == PaymentRecordStatus.captured;
  bool get isFailed => status == PaymentRecordStatus.failed;
  bool get isRefunded => status == PaymentRecordStatus.refunded;
  bool get isPending => status == PaymentRecordStatus.created;

  String get formattedAmount => '₹${amount.toStringAsFixed(0)}';

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return PaymentModel(
      id: json['id']?.toString() ?? '',
      appointmentId: json['appointment_id']?.toString() ?? '',
      razorpayOrderId: json['razorpay_order_id']?.toString() ?? '',
      razorpayPaymentId: json['razorpay_payment_id']?.toString(),
      razorpaySignature: json['razorpay_signature']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      status: PaymentRecordStatus.fromString(json['status']?.toString()),
      mode: json['mode']?.toString() ?? 'full',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointment_id': appointmentId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'amount': amount,
      'currency': currency,
      'status': status.toDbString(),
      'mode': mode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PaymentModel copyWith({
    String? id,
    String? appointmentId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    double? amount,
    String? currency,
    PaymentRecordStatus? status,
    String? mode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpaySignature: razorpaySignature ?? this.razorpaySignature,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
