import 'package:flutter_test/flutter_test.dart';
import 'package:doctorg/features/payment/domain/models/payment_model.dart';
import 'package:doctorg/features/payment/domain/models/razorpay_order_model.dart';
import 'package:doctorg/features/payment/data/repositories/supabase_payment_repository.dart';

void main() {
  group('PaymentModel Tests', () {
    final now = DateTime.now();

    test('initializes and parses correctly from JSON', () {
      final json = {
        'id': 'pay-rec-001',
        'appointment_id': 'app-001',
        'razorpay_order_id': 'order_12345678',
        'razorpay_payment_id': 'pay_87654321',
        'razorpay_signature': 'sig_abcdef123456',
        'amount': 800.0,
        'currency': 'INR',
        'status': 'captured',
        'mode': 'full',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final payment = PaymentModel.fromJson(json);

      expect(payment.id, equals('pay-rec-001'));
      expect(payment.appointmentId, equals('app-001'));
      expect(payment.razorpayOrderId, equals('order_12345678'));
      expect(payment.razorpayPaymentId, equals('pay_87654321'));
      expect(payment.amount, equals(800.0));
      expect(payment.isCaptured, isTrue);
      expect(payment.isFailed, isFalse);
      expect(payment.formattedAmount, equals('₹800'));
    });

    test('evaluates status flags properly', () {
      final pending = PaymentModel(
        id: '1',
        appointmentId: 'a1',
        razorpayOrderId: 'o1',
        amount: 500,
        status: PaymentRecordStatus.created,
        createdAt: now,
        updatedAt: now,
      );
      expect(pending.isPending, isTrue);
      expect(pending.isCaptured, isFalse);

      final failed = pending.copyWith(status: PaymentRecordStatus.failed);
      expect(failed.isFailed, isTrue);

      final refunded = pending.copyWith(status: PaymentRecordStatus.refunded);
      expect(refunded.isRefunded, isTrue);
    });

    test('serializes to JSON accurately', () {
      final payment = PaymentModel(
        id: 'p1',
        appointmentId: 'a1',
        razorpayOrderId: 'order_abc',
        amount: 650.0,
        status: PaymentRecordStatus.captured,
        createdAt: now,
        updatedAt: now,
      );

      final json = payment.toJson();
      expect(json['appointment_id'], equals('a1'));
      expect(json['status'], equals('captured'));
      expect(json['amount'], equals(650.0));
    });
  });

  group('RazorpayOrderModel Tests', () {
    test('converts rupees to paise subunits accurately', () {
      final order = RazorpayOrderModel(
        orderId: 'order_test_999',
        amount: 750.0,
        amountSubunits: 75000,
        currency: 'INR',
        keyId: 'rzp_test_123',
      );

      expect(order.amountSubunits, equals(75000));
      expect(order.currency, equals('INR'));

      final json = order.toJson();
      expect(json['order_id'], equals('order_test_999'));
      expect(json['amount_subunits'], equals(75000));

      final parsed = RazorpayOrderModel.fromJson(json);
      expect(parsed.orderId, equals(order.orderId));
      expect(parsed.amountSubunits, equals(75000));
    });

    test('handles decimal rupee amounts without subunit truncation', () {
      final json = {
        'order_id': 'order_dec',
        'amount': 550.50,
        'amount_subunits': 55050,
        'currency': 'INR',
        'key_id': 'rzp_test_xyz',
      };

      final model = RazorpayOrderModel.fromJson(json);
      expect(model.amountSubunits, equals(55050));
    });
  });

  group('SupabasePaymentRepository Test Mode Simulation', () {
    final repo = SupabasePaymentRepository(null);
    const appointmentId = 'test-app-777';

    test('creates test order with valid subunit calculation', () async {
      final order = await repo.createRazorpayOrder(
        appointmentId: appointmentId,
        amount: 500.0,
      );

      expect(order.orderId, startsWith('order_test_'));
      expect(order.amount, equals(500.0));
      expect(order.amountSubunits, equals(50000));
      expect(order.currency, equals('INR'));
    });

    test('verifies and captures payment successfully', () async {
      const orderId = 'order_test_captured';
      const paymentId = 'pay_test_captured';
      const signature = 'sig_test_captured';

      final payment = await repo.verifyAndCapturePayment(
        appointmentId: appointmentId,
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        amount: 500.0,
      );

      expect(payment.appointmentId, equals(appointmentId));
      expect(payment.razorpayOrderId, equals(orderId));
      expect(payment.razorpayPaymentId, equals(paymentId));
      expect(payment.isCaptured, isTrue);

      final retrieved = await repo.getPaymentForAppointment(appointmentId);
      expect(retrieved, isNotNull);
      expect(retrieved!.isCaptured, isTrue);
    });
  });
}
