import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_config.dart';

class RazorpayService {
  late Razorpay _razorpay;

  final Function(PaymentSuccessResponse)? onSuccess;
  final Function(PaymentFailureResponse)? onFailure;
  final Function(ExternalWalletResponse)? onExternalWallet;

  RazorpayService({
    this.onSuccess,
    this.onFailure,
    this.onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Razorpay Success: ${response.paymentId}");
    if (onSuccess != null) {
      onSuccess!(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Razorpay Error: ${response.code} - ${response.message}");
    if (onFailure != null) {
      onFailure!(response);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("Razorpay Wallet: ${response.walletName}");
    if (onExternalWallet != null) {
      onExternalWallet!(response);
    }
  }

  void openCheckout({
    required int amountInr,
    required String name,
    required String description,
    required String userEmail,
    required String userContact,
    Map<String, String>? notes,
  }) {
    // Generate a pseudo-OrderId if we don't have backend (not recommended for production)
    // Pseudo order ID generation normally goes here for backend.

    var options = {
      'key': AppConfig.razorpayApiKey,
      'amount': amountInr * 100, // Amount should be in paisa
      'name': name,
      'description': description,
      'prefill': {
        'contact': userContact,
        'email': userEmail,
      },
      // Remove complex filtering temporarily to see if UPI shows up by default at all.
      // If UPI is missing even with default settings, it is an emulator or dashboard issue.
    };
    if (notes != null && notes.isNotEmpty) {
      options['notes'] = notes;
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error launching Razorpay: $e");
    }
  }

  void dispose() {
    _razorpay.clear(); // Removes all listeners
  }
}
