import '../models/payment_model.dart';
import '../models/razorpay_order_model.dart';

abstract class PaymentRepository {
  /// Calls create-razorpay-order edge function to create order on Razorpay
  Future<RazorpayOrderModel> createRazorpayOrder({
    required String appointmentId,
    required double amount,
    String mode = 'full',
  });

  /// Client-side verification and recording of captured payment
  Future<PaymentModel> verifyAndCapturePayment({
    required String appointmentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required double amount,
  });

  /// Retrieve payment record for an appointment
  Future<PaymentModel?> getPaymentForAppointment(String appointmentId);
}
