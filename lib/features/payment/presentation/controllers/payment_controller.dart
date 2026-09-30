import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_payment_repository.dart';
import '../../domain/models/payment_model.dart';
import '../../domain/models/razorpay_order_model.dart';
import '../services/razorpay_payment_service.dart';

@immutable
class PaymentState {
  final bool isProcessing;
  final RazorpayOrderModel? order;
  final PaymentModel? capturedPayment;
  final String? errorMessage;

  const PaymentState({
    this.isProcessing = false,
    this.order,
    this.capturedPayment,
    this.errorMessage,
  });

  PaymentState copyWith({
    bool? isProcessing,
    RazorpayOrderModel? order,
    PaymentModel? capturedPayment,
    String? errorMessage,
  }) {
    return PaymentState(
      isProcessing: isProcessing ?? this.isProcessing,
      order: order ?? this.order,
      capturedPayment: capturedPayment ?? this.capturedPayment,
      errorMessage: errorMessage,
    );
  }
}

class PaymentController extends StateNotifier<PaymentState> {
  final Ref _ref;
  final RazorpayPaymentService _service = RazorpayPaymentService();

  PaymentController(this._ref) : super(const PaymentState()) {
    _service.init();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<PaymentModel?> processOnlinePayment({
    required String appointmentId,
    required double amount,
    required String doctorName,
    required String patientName,
    required String patientPhone,
    required String patientEmail,
    String mode = 'full',
  }) async {
    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final repo = _ref.read(paymentRepositoryProvider);

      // 1. Create order on Edge Function / Razorpay
      final order = await repo.createRazorpayOrder(
        appointmentId: appointmentId,
        amount: amount,
        mode: mode,
      );
      state = state.copyWith(order: order);

      // 2. Launch checkout
      final result = await _service.launchCheckout(
        order: order,
        doctorName: doctorName,
        patientName: patientName,
        patientPhone: patientPhone,
        patientEmail: patientEmail,
      );

      // 3. Verify and capture payment
      final payment = await repo.verifyAndCapturePayment(
        appointmentId: appointmentId,
        razorpayOrderId: result.orderId,
        razorpayPaymentId: result.paymentId,
        razorpaySignature: result.signature,
        amount: amount,
      );

      state = state.copyWith(isProcessing: false, capturedPayment: payment);

      return payment;
    } catch (err) {
      final msg = err is RazorpayErrorResult
          ? err.message
          : 'Payment failed: $err';
      state = state.copyWith(isProcessing: false, errorMessage: msg);
      return null;
    }
  }
}

final paymentControllerProvider =
    StateNotifierProvider.autoDispose<PaymentController, PaymentState>((ref) {
      return PaymentController(ref);
    });
