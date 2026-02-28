import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class BillingVerificationResult {
  final bool success;
  final String message;

  const BillingVerificationResult({
    required this.success,
    required this.message,
  });
}

class BillingVerificationService {
  Future<BillingVerificationResult> verifyRazorpayPayment({
    required String paymentId,
    required String planType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const BillingVerificationResult(
        success: false,
        message: 'Please sign in again and retry verification.',
      );
    }

    final idToken = await user.getIdToken(true);
    final baseUrl = AppConfig.webBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl/api/billing/verify');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'paymentId': paymentId,
          'planType': planType,
        }),
      );

      final raw = response.body;
      final body =
          raw.isNotEmpty ? jsonDecode(raw) as Map<String, dynamic> : {};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BillingVerificationResult(
          success: body['success'] == true,
          message: (body['message'] ?? 'Membership verified successfully.')
              .toString(),
        );
      }

      return BillingVerificationResult(
        success: false,
        message: (body['error'] ?? 'Payment verification failed.').toString(),
      );
    } catch (_) {
      return const BillingVerificationResult(
        success: false,
        message:
            'Could not verify payment right now. Please try again shortly.',
      );
    }
  }
}
