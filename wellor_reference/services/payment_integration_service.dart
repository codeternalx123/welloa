/// Payment Processing Integration for Wellor
/// Handles Stripe payments, insurance verification, and HSA/FSA support
/// 
/// SETUP INSTRUCTIONS:
/// 1. Add dependencies to pubspec.yaml:
///    - flutter_stripe: ^10.0.0
///    - http: ^1.1.0
/// 
/// 2. Create Firebase Cloud Functions for secure payment processing
/// 3. Store Stripe API keys in Firebase Remote Config (never in client code)
/// 4. Enable PCI compliance in Stripe Dashboard

library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Stripe Payment Service
/// Handles credit card payments, subscriptions, and one-time purchases
class StripePaymentService {
  // NOTE: NEVER store API keys in client code - use Firebase Cloud Functions
  static const String _baseUrl = 'https://api.stripe.com/v1';
  
  /// Initialize Stripe SDK
  /// Call this in main.dart before runApp()
  /// 
  /// ```dart
  /// await Stripe.instance.applySettings(
  ///   merchantIdentifier: 'merchant.com.Wellor',
  ///   urlScheme: 'Wellor',
  ///   publishableKey: await _fetchPublishableKey(),
  /// );
  /// ```
  static Future<void> initialize() async {
    debugPrint(
      'StripePaymentService.initialize: no-op. Wire flutter_stripe + Remote Config in main.dart when needed.',
    );
  }
  
  /// Create payment intent for one-time payment
  /// Used for: Pharmacy orders, bio-subscription first payment
  /// 
  /// Server-side Cloud Function should:
  /// 1. Validate user authentication
  /// 2. Calculate amount (including taxes)
  /// 3. Create Stripe PaymentIntent
  /// 4. Return client_secret to client
  static Future<Map<String, dynamic>> createPaymentIntent({
    required String userId,
    required double amount,
    required String currency,
    required Map<String, dynamic> metadata,
  }) async {
    // Call Firebase Cloud Function
    final response = await http.post(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/createPaymentIntent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'amount': (amount * 100).toInt(), // Stripe uses cents
        'currency': currency,
        'metadata': metadata,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create payment intent: ${response.body}');
    }
  }
  
  /// Process payment with Stripe
  /// Returns payment confirmation or throws error
  static Future<Map<String, dynamic>> processPayment({
    required String paymentIntentClientSecret,
    required Map<String, String> billingDetails,
  }) async {
    // Implementation using flutter_stripe:
    // 
    // await Stripe.instance.confirmPayment(
    //   paymentIntentClientSecret: paymentIntentClientSecret,
    //   data: PaymentMethodParams.card(
    //     paymentMethodData: PaymentMethodData(
    //       billingDetails: BillingDetails(
    //         email: billingDetails['email'],
    //         name: billingDetails['name'],
    //         address: Address(...),
    //       ),
    //     ),
    //   ),
    // );
    
    debugPrint(
      'StripePaymentService.processPayment: client-side confirm not implemented — use Paystack checkout or flutter_stripe.confirmPayment.',
    );
    return {
      'success': false,
      'reason': 'client_stripe_confirm_not_implemented',
    };
  }
  
  /// Create subscription for recurring payments
  /// Used for: Bio-subscriptions, managed dietitian payments
  /// 
  /// Creates Stripe subscription with:
  /// - Monthly billing cycle
  /// - Automatic payment retry on failure
  /// - Email receipts
  /// - Proration for plan changes
  static Future<Map<String, dynamic>> createSubscription({
    required String userId,
    required String priceId, // Stripe Price ID for subscription tier
    required String paymentMethodId,
    required Map<String, dynamic> metadata,
  }) async {
    final response = await http.post(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/createSubscription'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'priceId': priceId,
        'paymentMethodId': paymentMethodId,
        'metadata': metadata,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create subscription: ${response.body}');
    }
  }
  
  /// Cancel subscription
  /// Cancels at period end to honor current billing cycle
  static Future<void> cancelSubscription({
    required String subscriptionId,
    bool cancelImmediately = false,
  }) async {
    final response = await http.post(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/cancelSubscription'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'subscriptionId': subscriptionId,
        'cancelAtPeriodEnd': !cancelImmediately,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel subscription: ${response.body}');
    }
  }
  
  /// Update subscription (upgrade/downgrade tier)
  /// Prorates charges automatically
  static Future<Map<String, dynamic>> updateSubscription({
    required String subscriptionId,
    required String newPriceId,
  }) async {
    final response = await http.post(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/updateSubscription'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'subscriptionId': subscriptionId,
        'newPriceId': newPriceId,
        'prorationBehavior': 'always_invoice', // Immediate proration
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update subscription: ${response.body}');
    }
  }
  
  /// Get payment methods for user
  /// Lists saved cards for quick checkout
  static Future<List<Map<String, dynamic>>> getPaymentMethods({
    required String userId,
  }) async {
    final response = await http.get(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/getPaymentMethods?userId=$userId'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['paymentMethods']);
    } else {
      throw Exception('Failed to fetch payment methods: ${response.body}');
    }
  }
  
  /// Add payment method
  /// Securely tokenizes card and attaches to customer
  static Future<Map<String, dynamic>> addPaymentMethod({
    required String userId,
    required String paymentMethodId,
  }) async {
    final response = await http.post(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/addPaymentMethod'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'paymentMethodId': paymentMethodId,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add payment method: ${response.body}');
    }
  }
}

/// Insurance Verification Service
/// Integrates with Eligible API for real-time insurance verification
class InsuranceVerificationService {
  static const String _eligibleApiUrl = 'https://gds.eligibleapi.com/v1.5';
  
  /// Verify insurance eligibility in real-time
  /// Returns coverage details, copays, deductibles
  /// 
  /// ELIGIBLE API DOCUMENTATION:
  /// https://eligibleapi.com/rest-api-v1-5/coverage/
  /// 
  /// REQUIRED SETUP:
  /// 1. Sign up at eligibleapi.com
  /// 2. Get API key
  /// 3. Store in Firebase Remote Config
  /// 4. Enable in production (sandbox mode for testing)
  static Future<Map<String, dynamic>> verifyInsuranceCoverage({
    required String insuranceProvider,
    required String memberId,
    required String groupNumber,
    required String subscriberDob,
    required String patientFirstName,
    required String patientLastName,
    List<String>? serviceCodes, // CPT codes to check coverage for
  }) async {
    // Call Eligible API via Firebase Cloud Function (to hide API key)
    final response = await http.post(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/verifyInsurance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': insuranceProvider,
        'memberId': memberId,
        'groupNumber': groupNumber,
        'dob': subscriberDob,
        'firstName': patientFirstName,
        'lastName': patientLastName,
        'serviceCodes': serviceCodes,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      return {
        'isActive': data['insurance_plan']['active'] ?? false,
        'planName': data['insurance_plan']['plan_name'],
        'groupNumber': data['insurance_plan']['group_number'],
        'deductible': data['deductible']?['individual']?['in_network']?['amount'] ?? 0,
        'deductibleMet': data['deductible']?['individual']?['in_network']?['used'] ?? 0,
        'deductibleRemaining': data['deductible']?['individual']?['in_network']?['remaining'] ?? 0,
        'oopMax': data['stop_loss']?['individual']?['in_network']?['amount'] ?? 0,
        'oopMet': data['stop_loss']?['individual']?['in_network']?['used'] ?? 0,
        'copays': {
          'primaryCare': data['copay']?['primary_care_visit'] ?? 0,
          'specialist': data['copay']?['specialist_visit'] ?? 0,
          'genericDrug': data['copay']?['generic_drug'] ?? 0,
          'brandDrug': data['copay']?['brand_drug'] ?? 0,
          'specialtyDrug': data['copay']?['specialty_drug'] ?? 0,
        },
        'coveragePercentage': data['coinsurance']?['individual']?['in_network'] ?? 80,
      };
    } else {
      throw Exception('Insurance verification failed: ${response.body}');
    }
  }
  
  /// Submit insurance claim for CPT code billing
  /// Used for Digital Therapeutics programs
  /// 
  /// CHANGE HEALTHCARE CLEARINGHOUSE:
  /// https://www.changehealthcare.com/
  /// 
  /// CPT CODES SUPPORTED:
  /// - 99453: RPM setup ($19)
  /// - 99454: RPM device supply ($60)
  /// - 99457: RPM monitoring 20+ min ($51)
  /// - 99458: Additional 20 min ($41)
  /// - 99490: CCM 20+ min ($43)
  static Future<Map<String, dynamic>> submitInsuranceClaim({
    required String patientId,
    required String providerId, // Dietitian NPI
    required String diagnosisCode, // ICD-10
    required List<String> cptCodes,
    required DateTime serviceDate,
    required Map<String, dynamic> insuranceInfo,
  }) async {
    final response = await http.post(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/submitClaim'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patientId': patientId,
        'providerId': providerId,
        'diagnosisCode': diagnosisCode,
        'cptCodes': cptCodes,
        'serviceDate': serviceDate.toIso8601String(),
        'insuranceInfo': insuranceInfo,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'claimId': data['claim_id'],
        'status': data['status'], // 'submitted', 'accepted', 'rejected'
        'expectedReimbursement': data['expected_reimbursement'],
        'submittedAt': DateTime.parse(data['submitted_at']),
      };
    } else {
      throw Exception('Claim submission failed: ${response.body}');
    }
  }
  
  /// Check claim status
  /// Track reimbursement progress
  static Future<Map<String, dynamic>> checkClaimStatus({
    required String claimId,
  }) async {
    final response = await http.get(
      Uri.parse('https://us-central1-bitelab.cloudfunctions.net/getClaimStatus?claimId=$claimId'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to check claim status: ${response.body}');
    }
  }
}

/// HSA/FSA Card Support
/// Enable payments from Health Savings Accounts and Flexible Spending Accounts
class HsaFsaPaymentService {
  /// Check if card is HSA/FSA eligible
  /// Some services are HSA/FSA eligible:
  /// - Digital Therapeutics (FDA cleared)
  /// - Bio-subscriptions (preventive care)
  /// - Certain supplements (with prescription)
  static bool isHsaFsaEligible({
    required String productType,
    required bool hasPrescription,
  }) {
    final eligibleTypes = [
      'digital_therapeutics',
      'bio_subscription',
      'cgm_device',
      'diabetes_medication',
    ];
    
    if (eligibleTypes.contains(productType)) {
      return true;
    }
    
    // Supplements eligible only with prescription
    if (productType == 'supplement' && hasPrescription) {
      return true;
    }
    
    return false;
  }
  
  /// Process HSA/FSA payment
  /// Stripe automatically detects FSA cards
  /// Just need to provide proper receipt with:
  /// - Itemized list of eligible products
  /// - Provider name (Wellor Health)
  /// - Provider TIN/EIN
  static Future<Map<String, dynamic>> processHsaFsaPayment({
    required String userId,
    required double amount,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    // Validate all items are HSA/FSA eligible
    for (var item in lineItems) {
      if (!isHsaFsaEligible(
        productType: item['type'],
        hasPrescription: item['has_prescription'] ?? false,
      )) {
        throw Exception('Item ${item['name']} is not HSA/FSA eligible');
      }
    }
    
    // Process payment via Stripe (same flow as credit card)
    return await StripePaymentService.createPaymentIntent(
      userId: userId,
      amount: amount,
      currency: 'usd',
      metadata: {
        'payment_type': 'hsa_fsa',
        'line_items': lineItems,
        'provider_name': 'Wellor Health',
        'provider_tin': '12-3456789', // Wellor's Tax ID
      },
    );
  }
  
  /// Generate HSA/FSA receipt
  /// Required for reimbursement claims
  static Map<String, dynamic> generateReceipt({
    required String transactionId,
    required DateTime purchaseDate,
    required List<Map<String, dynamic>> lineItems,
    required double totalAmount,
  }) {
    return {
      'receipt_id': transactionId,
      'provider_name': 'Wellor Health',
      'provider_tin': '12-3456789',
      'provider_address': '123 Health St, San Francisco, CA 94102',
      'purchase_date': purchaseDate.toIso8601String(),
      'line_items': lineItems.map((item) => {
        'description': item['name'],
        'amount': item['price'],
        'is_hsa_fsa_eligible': true,
      }).toList(),
      'total_amount': totalAmount,
      'payment_method': 'HSA/FSA Card',
    };
  }
}

/// Revenue Tracking Service
/// Track all payment transactions for analytics
class RevenueTrackingService {
  /// Log payment transaction
  /// Store in Firestore for analytics dashboard
  static Future<void> logTransaction({
    required String userId,
    required String transactionType, // 'pharmacy', 'dtx', 'bio_subscription', etc.
    required double amount,
    required String paymentMethod,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('revenue_transactions').add({
        'userId': userId,
        'transactionType': transactionType,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RevenueTrackingService.logTransaction: $e');
    }
  }
  
  /// Get revenue metrics
  /// Used by admin dashboard to track $1M milestone
  static Future<Map<String, dynamic>> getRevenueMetrics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('revenue_transactions')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();
      double total = 0;
      final byType = <String, double>{};
      for (final doc in snap.docs) {
        final m = doc.data();
        final ts = m['createdAt'];
        DateTime? created;
        if (ts is Timestamp) created = ts.toDate();
        if (created != null && created.isAfter(endDate)) continue;
        final a = (m['amount'] as num?)?.toDouble() ?? 0;
        total += a;
        final t = m['transactionType']?.toString() ?? 'unknown';
        byType[t] = (byType[t] ?? 0) + a;
      }
      return {'total': total, 'byType': byType, 'count': snap.docs.length};
    } catch (e) {
      debugPrint('RevenueTrackingService.getRevenueMetrics: $e');
      return {'total': 0.0, 'byType': <String, double>{}, 'count': 0, 'error': e.toString()};
    }
  }
}

/// STRIPE PRICE IDs FOR SUBSCRIPTION TIERS
/// Create these in Stripe Dashboard: https://dashboard.stripe.com/products
/// 
/// Bio-Subscription Tiers:
const Map<String, String> STRIPE_PRICE_IDS = {
  'bio_basic': 'price_basic_49_monthly',      // $49/month
  'bio_advanced': 'price_advanced_99_monthly', // $99/month
  'bio_platinum': 'price_platinum_199_monthly', // $199/month
  'bio_concierge': 'price_concierge_499_monthly', // $499/month
};

/// IMPLEMENTATION CHECKLIST:
/// 
/// ☐ 1. Add flutter_stripe dependency to pubspec.yaml
/// ☐ 2. Create Stripe account and get API keys
/// ☐ 3. Create Firebase Cloud Functions for:
///      - createPaymentIntent
///      - createSubscription
///      - cancelSubscription
///      - updateSubscription
///      - verifyInsurance (Eligible API)
///      - submitClaim (Change Healthcare)
/// ☐ 4. Sign up for Eligible API (insurance verification)
/// ☐ 5. Sign up for Change Healthcare clearinghouse (CPT billing)
/// ☐ 6. Create Stripe Products and Prices for subscription tiers
/// ☐ 7. Configure webhook endpoints in Stripe Dashboard
/// ☐ 8. Implement webhook handlers in Cloud Functions for:
///      - payment_intent.succeeded
///      - payment_intent.payment_failed
///      - customer.subscription.created
///      - customer.subscription.deleted
///      - invoice.payment_succeeded
/// ☐ 9. Test in Stripe test mode with test cards
/// ☐ 10. Enable PCI compliance in production
/// 
/// ESTIMATED INTEGRATION TIME: 2-3 weeks
/// 
/// EXTERNAL DEPENDENCIES:
/// - Stripe SDK: https://pub.dev/packages/flutter_stripe
/// - Eligible API: https://eligibleapi.com/
/// - Change Healthcare: https://www.changehealthcare.com/
/// 
/// COST ESTIMATES:
/// - Stripe: 2.9% + $0.30 per transaction
/// - Eligible API: $0.25 per eligibility check
/// - Change Healthcare: $1.50 per claim submission
