// lib/services/payment_service.dart
// DECACORN-GRADE: Unified Payment Gateway
// M-Pesa Daraja API + Stripe + Apple Pay + Google Pay

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// ============================================
// PAYMENT MODELS
// ============================================

enum PaymentMethod {
  mpesa,
  stripe,
  applePay,
  googlePay,
  card,
}

enum PaymentStatus {
  pending,
  processing,
  successful,
  failed,
  cancelled,
  refunded,
}

class PaymentResult {
  final bool success;
  final String? transactionId;
  final PaymentStatus status;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  PaymentResult({
    required this.success,
    this.transactionId,
    required this.status,
    this.errorMessage,
    this.metadata = const {},
  });

  factory PaymentResult.success(String transactionId) => PaymentResult(
        success: true,
        transactionId: transactionId,
        status: PaymentStatus.successful,
      );

  factory PaymentResult.failed(String errorMessage) => PaymentResult(
        success: false,
        status: PaymentStatus.failed,
        errorMessage: errorMessage,
      );

  Map<String, dynamic> toJson() => {
        'success': success,
        'transactionId': transactionId,
        'status': status.toString().split('.').last,
        'errorMessage': errorMessage,
        'metadata': metadata,
      };
}

// ============================================
// PAYMENT SERVICE
// ============================================

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  static String get _mpesaConsumerKey =>
      dotenv.env['MPESA_CONSUMER_KEY'] ?? '';
  static String get _mpesaConsumerSecret =>
      dotenv.env['MPESA_CONSUMER_SECRET'] ?? '';
  static String get _mpesaShortcode => dotenv.env['MPESA_SHORTCODE'] ?? '';
  static String get _mpesaPasskey => dotenv.env['MPESA_PASSKEY'] ?? '';
  static const String _mpesaBaseUrl = 'https://api.safaricom.co.ke';

  static String get _stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  static String get _stripeSecretKey =>
      dotenv.env['STRIPE_SECRET_KEY'] ?? '';

  String? _mpesaAccessToken;
  DateTime? _mpesaTokenExpiry;

  /// Initialize payment service
  Future<void> initialize() async {
    debugPrint('💳 Initializing Payment Service...');
    if (_mpesaConsumerKey.isEmpty) {
      debugPrint(
          'PaymentService: MPESA_* keys missing in .env — M-Pesa calls will fail until configured.',
      );
      return;
    }
    await _refreshMpesaToken();
  }

  /// Process payment with selected method
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required PaymentMethod method,
    String? phoneNumber,
    String? email,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('💳 Processing payment: $amount $currency via $method');

    try {
      switch (method) {
        case PaymentMethod.mpesa:
          return await _processMpesaPayment(
            amount: amount,
            phoneNumber: phoneNumber!,
            metadata: metadata,
          );
        case PaymentMethod.stripe:
        case PaymentMethod.card:
          return await _processStripePayment(
            amount: amount,
            currency: currency,
            email: email,
            metadata: metadata,
          );
        case PaymentMethod.applePay:
          return await _processApplePayPayment(
            amount: amount,
            currency: currency,
            metadata: metadata,
          );
        case PaymentMethod.googlePay:
          return await _processGooglePayPayment(
            amount: amount,
            currency: currency,
            metadata: metadata,
          );
        default:
          return PaymentResult.failed('Unsupported payment method: $method');
      }
    } catch (e) {
      debugPrint('❌ Payment processing error: $e');
      return PaymentResult.failed('Payment failed: $e');
    }
  }

  /// Verify payment status
  Future<PaymentStatus> verifyPayment(String transactionId, PaymentMethod method) async {
    debugPrint('💳 Verifying payment: $transactionId');

    try {
      switch (method) {
        case PaymentMethod.mpesa:
          return await _verifyMpesaPayment(transactionId);
        case PaymentMethod.stripe:
        case PaymentMethod.card:
          return await _verifyStripePayment(transactionId);
        default:
          return PaymentStatus.pending;
      }
    } catch (e) {
      debugPrint('❌ Payment verification error: $e');
      return PaymentStatus.failed;
    }
  }

  // ============================================
  // M-PESA DARAJA API INTEGRATION
  // ============================================

  /// Refresh M-Pesa OAuth access token
  Future<void> _refreshMpesaToken() async {
    if (_mpesaAccessToken != null &&
        _mpesaTokenExpiry != null &&
        DateTime.now().isBefore(_mpesaTokenExpiry!)) {
      return; // Token still valid
    }

    try {
      final credentials = base64Encode(
        utf8.encode('$_mpesaConsumerKey:$_mpesaConsumerSecret'),
      );

      final response = await http.get(
        Uri.parse('$_mpesaBaseUrl/oauth/v1/generate?grant_type=client_credentials'),
        headers: {
          'Authorization': 'Basic $credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _mpesaAccessToken = data['access_token'];
        _mpesaTokenExpiry = DateTime.now().add(
          Duration(seconds: int.parse(data['expires_in'])),
        );
        debugPrint('✅ M-Pesa token refreshed');
      } else {
        debugPrint('❌ M-Pesa token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ M-Pesa token refresh error: $e');
    }
  }

  /// Process M-Pesa STK Push payment
  Future<PaymentResult> _processMpesaPayment({
    required double amount,
    required String phoneNumber,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _refreshMpesaToken();

      // 🏗️ PRODUCTION TODO: Implement M-Pesa STK Push
      // API Docs: https://developer.safaricom.co.ke/APIs/MpesaExpressSimulate
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
      final password = base64Encode(
        utf8.encode('$_mpesaShortcode$_mpesaPasskey$timestamp'),
      );

      final response = await http.post(
        Uri.parse('$_mpesaBaseUrl/mpesa/stkpush/v1/processrequest'),
        headers: {
          'Authorization': 'Bearer $_mpesaAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'BusinessShortCode': _mpesaShortcode,
          'Password': password,
          'Timestamp': timestamp,
          'TransactionType': 'CustomerPayBillOnline',
          'Amount': amount.toInt(),
          'PartyA': phoneNumber,
          'PartyB': _mpesaShortcode,
          'PhoneNumber': phoneNumber,
          'CallBackURL': 'https://yourdomain.com/api/mpesa/callback',
          'AccountReference': 'MetOS-${DateTime.now().millisecondsSinceEpoch}',
          'TransactionDesc': 'Meal Order Payment',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ResponseCode'] == '0') {
          debugPrint('✅ M-Pesa STK Push initiated');
          return PaymentResult(
            success: true,
            transactionId: data['CheckoutRequestID'],
            status: PaymentStatus.processing,
            metadata: metadata ?? {},
          );
        }
      }

      return PaymentResult.failed('M-Pesa payment initiation failed');
    } catch (e) {
      debugPrint('❌ M-Pesa payment error: $e');
      return PaymentResult.failed('M-Pesa error: $e');
    }
  }

  /// Verify M-Pesa payment status
  Future<PaymentStatus> _verifyMpesaPayment(String checkoutRequestId) async {
    try {
      await _refreshMpesaToken();

      // 🏗️ PRODUCTION TODO: Implement M-Pesa Query API
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
      final password = base64Encode(
        utf8.encode('$_mpesaShortcode$_mpesaPasskey$timestamp'),
      );

      final response = await http.post(
        Uri.parse('$_mpesaBaseUrl/mpesa/stkpushquery/v1/query'),
        headers: {
          'Authorization': 'Bearer $_mpesaAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'BusinessShortCode': _mpesaShortcode,
          'Password': password,
          'Timestamp': timestamp,
          'CheckoutRequestID': checkoutRequestId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ResultCode'] == '0') {
          return PaymentStatus.successful;
        } else if (data['ResultCode'] == '1032') {
          return PaymentStatus.cancelled;
        } else {
          return PaymentStatus.failed;
        }
      }

      return PaymentStatus.pending;
    } catch (e) {
      debugPrint('❌ M-Pesa verification error: $e');
      return PaymentStatus.pending;
    }
  }

  // ============================================
  // STRIPE INTEGRATION
  // ============================================

  Future<PaymentResult> _processStripePayment({
    required double amount,
    required String currency,
    String? email,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Stub: return failed — never call SubscriptionProvider.upgradeSubscription from here until implemented.
      // 🏗️ PRODUCTION TODO: Implement Stripe Payment Intent API (flutter_stripe + Cloud Functions).
      debugPrint('💳 Stripe payment processing stub');
      return PaymentResult.failed('Stripe integration not yet implemented');
    } catch (e) {
      debugPrint('❌ Stripe payment error: $e');
      return PaymentResult.failed('Stripe error: $e');
    }
  }

  Future<PaymentStatus> _verifyStripePayment(String paymentIntentId) async {
    // 🏗️ PRODUCTION TODO: Verify Stripe payment via API
    return PaymentStatus.pending;
  }

  // ============================================
  // APPLE PAY / GOOGLE PAY INTEGRATION
  // ============================================

  Future<PaymentResult> _processApplePayPayment({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    // Stub: do not grant entitlements from this path until native flow + server verification exist.
    // 🏗️ PRODUCTION TODO: Apple Pay via Stripe or PassKit.
    debugPrint('🍎 Apple Pay processing stub');
    return PaymentResult.failed('Apple Pay integration not yet implemented');
  }

  Future<PaymentResult> _processGooglePayPayment({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    // Stub: do not grant entitlements from this path until native flow + server verification exist.
    // 🏗️ PRODUCTION TODO: Google Pay via Stripe or Play billing.
    debugPrint('🤖 Google Pay processing stub');
    return PaymentResult.failed('Google Pay integration not yet implemented');
  }
}
