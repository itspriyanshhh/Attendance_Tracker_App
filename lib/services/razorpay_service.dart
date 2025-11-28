import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:attendance_management/services/subscription_service.dart';

class RazorpayService {
  static RazorpayService? _instance;
  static RazorpayService get instance => _instance ??= RazorpayService._();
  RazorpayService._();

  late Razorpay _razorpay;

  // Your Razorpay credentials
  static const String _keyId = 'rzp_test_Rl9ah894nKuQDN';
  // ignore: unused_field
  static const String _keySecret = 'UHos9PX3XZY2GfsnSVVtx9KM';

  // Subscription plan amounts (in paise - 1 Rupee = 100 paise)
  static const int yearlyAmount = 9900; // ₹99
  static const int fourYearsAmount = 19900; // ₹199

  void initialize() {
    _razorpay = Razorpay();
  }

  void dispose() {
    _razorpay.clear();
  }

  /// Start payment for yearly subscription
  Future<void> purchaseYearlySubscription({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    required String userEmail,
    required String userPhone,
  }) async {
    await _startPayment(
      amount: yearlyAmount,
      description: 'Attendify Premium - 1 Year',
      subscriptionType: 'yearly',
      userEmail: userEmail,
      userPhone: userPhone,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  /// Start payment for 4-year subscription
  Future<void> purchaseFourYearsSubscription({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    required String userEmail,
    required String userPhone,
  }) async {
    await _startPayment(
      amount: fourYearsAmount,
      description: 'Attendify Premium - 4 Years',
      subscriptionType: 'four_years',
      userEmail: userEmail,
      userPhone: userPhone,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  /// Internal method to start payment
  Future<void> _startPayment({
    required int amount,
    required String description,
    required String subscriptionType,
    required String userEmail,
    required String userPhone,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
  }) async {
    final options = {
      'key': _keyId,
      'amount': amount,
      'currency': 'INR',
      'name': 'Attendify Premium',
      'description': description,
      'prefill': {'email': userEmail, 'contact': userPhone},
      'theme': {'color': '#8C9EFF'},
    };

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) async {
      final paymentResponse = response as PaymentSuccessResponse;

      print('Payment successful: ${paymentResponse.paymentId}');

      // Activate subscription
      // Note: For direct payments without creating orders, signature verification
      // is not available. In production, use Razorpay Orders API for secure verification.
      try {
        await SubscriptionService.instance.activateSubscription(
          subscriptionType: subscriptionType,
          paymentId: paymentResponse.paymentId ?? '',
          orderId: paymentResponse.orderId ?? '',
        );
        print('Subscription activated successfully');
        onSuccess(paymentResponse);
      } catch (e) {
        print('Error activating subscription: $e');
        // Still call onSuccess to show the UI, but log the error
        onSuccess(paymentResponse);
      }
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) {
      onFailure(response as PaymentFailureResponse);
    });

    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
      print('External wallet selected: $response');
    });

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
    }
  }
}
