import 'package:flutter/foundation.dart';

@immutable
class RazorpayOrderModel {
  final String orderId;
  final double amount; // in INR
  final int amountSubunits; // in Paise (amount * 100)
  final String currency;
  final String keyId;

  const RazorpayOrderModel({
    required this.orderId,
    required this.amount,
    required this.amountSubunits,
    this.currency = 'INR',
    required this.keyId,
  });

  factory RazorpayOrderModel.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final subunits =
        (json['amount_subunits'] as num?)?.toInt() ?? (amt * 100).round();

    return RazorpayOrderModel(
      orderId: json['order_id']?.toString() ?? '',
      amount: amt,
      amountSubunits: subunits,
      currency: json['currency']?.toString() ?? 'INR',
      keyId: json['key_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'amount': amount,
      'amount_subunits': amountSubunits,
      'currency': currency,
      'key_id': keyId,
    };
  }
}
