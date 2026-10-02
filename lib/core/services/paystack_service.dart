import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/payment/presentation/pages/paystack_checkout_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Result of pricing a checkout in USD with optional local conversion.
class PaystackCheckoutQuote {
  final double usdAmount;
  final int amountInSubunits;
  final PaystackChannel? channel;

  const PaystackCheckoutQuote({
    required this.usdAmount,
    required this.amountInSubunits,
    this.channel,
  });

  String get usdLabel => PaystackService().formatAmount(usdAmount, 'USD');
}

/// Country + channel chosen on the Paystack payment sheet.
class PaystackCheckoutSelection {
  final PaystackChannel channel;
  final PaystackCheckoutQuote quote;

  const PaystackCheckoutSelection({
    required this.channel,
    required this.quote,
  });
}

/// Paystack-supported payment channels.
/// [PaystackChannel.all] shows every channel enabled on your Paystack dashboard.
enum PaystackChannel {
  all,
  card,
  bank,
  ussd,
  mobileMoney,
  qr,
  bankTransfer,
  eft,
  payattitude,
}

extension PaystackChannelX on PaystackChannel {
  String get label {
    switch (this) {
      case PaystackChannel.all:
        return 'All Methods';
      case PaystackChannel.card:
        return 'Card';
      case PaystackChannel.bank:
        return 'Bank';
      case PaystackChannel.ussd:
        return 'USSD';
      case PaystackChannel.mobileMoney:
        return 'Mobile Money';
      case PaystackChannel.qr:
        return 'QR Code';
      case PaystackChannel.bankTransfer:
        return 'Bank Transfer';
      case PaystackChannel.eft:
        return 'EFT';
      case PaystackChannel.payattitude:
        return 'PayAttitude';
    }
  }

  String get subtitle {
    switch (this) {
      case PaystackChannel.all:
        return 'Cards, bank, USSD, mobile money & more';
      case PaystackChannel.card:
        return 'Visa, Mastercard, Verve';
      case PaystackChannel.bank:
        return 'Direct bank debit';
      case PaystackChannel.ussd:
        return 'Dial code on any phone';
      case PaystackChannel.mobileMoney:
        return 'M-Pesa, MTN MoMo & more';
      case PaystackChannel.qr:
        return 'Scan to pay instantly';
      case PaystackChannel.bankTransfer:
        return 'Dedicated transfer account';
      case PaystackChannel.eft:
        return 'South Africa EFT';
      case PaystackChannel.payattitude:
        return 'Nigeria PayAttitude';
    }
  }

  IconData get icon {
    switch (this) {
      case PaystackChannel.all:
        return Icons.payments_rounded;
      case PaystackChannel.card:
        return Icons.credit_card_rounded;
      case PaystackChannel.bank:
        return Icons.account_balance_rounded;
      case PaystackChannel.ussd:
        return Icons.dialpad_rounded;
      case PaystackChannel.mobileMoney:
        return Icons.phone_android_rounded;
      case PaystackChannel.qr:
        return Icons.qr_code_scanner_rounded;
      case PaystackChannel.bankTransfer:
        return Icons.swap_horiz_rounded;
      case PaystackChannel.eft:
        return Icons.sync_alt_rounded;
      case PaystackChannel.payattitude:
        return Icons.contactless_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case PaystackChannel.all:
        return const Color(0xFF00C3F7);
      case PaystackChannel.card:
        return const Color(0xFF6366F1);
      case PaystackChannel.bank:
        return const Color(0xFF0EA5E9);
      case PaystackChannel.ussd:
        return const Color(0xFF8B5CF6);
      case PaystackChannel.mobileMoney:
        return const Color(0xFF10B981);
      case PaystackChannel.qr:
        return const Color(0xFFF59E0B);
      case PaystackChannel.bankTransfer:
        return const Color(0xFF14B8A6);
      case PaystackChannel.eft:
        return const Color(0xFF3B82F6);
      case PaystackChannel.payattitude:
        return const Color(0xFFEC4899);
    }
  }

  /// Channels shown in the payment picker (excludes [all] — shown separately).
  static List<PaystackChannel> get specificChannels => PaystackChannel.values
      .where((c) => c != PaystackChannel.all)
      .toList(growable: false);

  String? get apiValue {
    switch (this) {
      case PaystackChannel.all:
        return null;
      case PaystackChannel.card:
        return 'card';
      case PaystackChannel.bank:
        return 'bank';
      case PaystackChannel.ussd:
        return 'ussd';
      case PaystackChannel.mobileMoney:
        return 'mobile_money';
      case PaystackChannel.qr:
        return 'qr';
      case PaystackChannel.bankTransfer:
        return 'bank_transfer';
      case PaystackChannel.eft:
        return 'eft';
      case PaystackChannel.payattitude:
        return 'payattitude';
    }
  }
}

/// Country options on the Paystack checkout sheet.
class PaystackCountryOption {
  final String code;
  final String name;
  final String currency;

  const PaystackCountryOption(this.code, this.name, this.currency);
}

/// Payment result returned after checkout.
class PaymentResult {
  final bool success;
  final String? ref;
  final String? transactionId;
  final PaystackChannel? channel;
  final String? message;
  final Map<String, dynamic>? details;

  PaymentResult({
    required this.success,
    this.ref,
    this.transactionId,
    this.channel,
    this.message,
    this.details,
  });
}

/// Paystack REST + hosted checkout integration.
class PaystackService {
  static final PaystackService _instance = PaystackService._internal();
  factory PaystackService() => _instance;
  PaystackService._internal();

  static const String _apiBase = 'https://api.paystack.co';
  static const Color brandBlue = Color(0xFF00C3F7);
  static const Color brandNavy = Color(0xFF011B33);

  String? _publicKey;
  String? _secretKey;
  String _callbackUrl = 'https://wellor.app/payment/callback';
  List<String> _merchantCurrencies = const ['NGN'];

  static const Set<String> _supportedCurrencies = {
    'NGN',
    'GHS',
    'ZAR',
    'KES',
    'USD',
  };

  static const String defaultDisplayCurrency = 'USD';




  static const Map<String, String> _currencySymbols = {
    'NGN': '₦',
    'GHS': 'GH₵',
    'ZAR': 'R',
    'KES': 'KSh',
    'UGX': 'USh',
    'TZS': 'TSh',
    'GBP': '£',
    'CAD': 'CA\$',
    'EUR': '€',
    'USD': '\$',
  };

  Future<void> init({
    String? publicKey,
    String? secretKey,
    String? callbackUrl,
  }) async {
    _publicKey = (publicKey ?? '').trim();
    _secretKey = (secretKey ?? '').trim();

    if ((callbackUrl ?? '').trim().isNotEmpty) {
      _callbackUrl = callbackUrl!.trim();
    }

    if (_secretKey!.isEmpty) {
      debugPrint(
        '⚠️ Paystack: Secret key not configured. '
        'Payments will not work.',
      );
    }

    debugPrint(
      '✅ Paystack initialized (${_publicKey!.startsWith('pk_test') ? 'TEST' : 'LIVE'})',
    );

    await _loadMerchantCurrencies();
  }

  /// Currencies enabled on this Paystack merchant (from /balance).
  List<String> get merchantCurrencies => List.unmodifiable(_merchantCurrencies);

  String get primaryCurrency =>
      _merchantCurrencies.isNotEmpty ? _merchantCurrencies.first : 'NGN';

  Future<void> _loadMerchantCurrencies() async {
    if ((_secretKey ?? '').isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$_apiBase/balance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_secretKey',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint(
          '⚠️ Paystack balance lookup failed (${response.statusCode})',
        );
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['status'] != true) return;

      final balances = decoded['data'] as List<dynamic>? ?? [];
      final currencies = balances
          .map((b) => (b as Map<String, dynamic>)['currency']?.toString())
          .whereType<String>()
          .map((c) => c.toUpperCase())
          .where((c) => c.isNotEmpty)
          .toList();

      if (currencies.isNotEmpty) {
        _merchantCurrencies = currencies;
        debugPrint('💳 Paystack merchant currencies: $_merchantCurrencies');
      }
    } catch (e) {
      debugPrint('⚠️ Paystack currency discovery error: $e');
    }
  }

  Future<void> ensureMerchantCurrenciesLoaded() => _loadMerchantCurrencies();

  bool get isConfigured =>
      (_secretKey ?? '').isNotEmpty;

  String? get publicKey => _publicKey;

  /// Plans are listed in USD; checkout converts based on country + payment method.
  String get displayCurrency => defaultDisplayCurrency;

  bool merchantSupports(String currency) =>
      _merchantCurrencies.contains(currency.toUpperCase());

  /// Currency implied by payment channel (e.g. Visa/card → USD when supported).
  String? currencyHintForChannel(PaystackChannel channel) {
    switch (channel) {
      case PaystackChannel.card:
        return 'USD';
      case PaystackChannel.ussd:
      case PaystackChannel.payattitude:
        return 'NGN';
      case PaystackChannel.eft:
        return 'ZAR';
      case PaystackChannel.mobileMoney:
      case PaystackChannel.bank:
      case PaystackChannel.bankTransfer:
      case PaystackChannel.qr:
      case PaystackChannel.all:
        return null;
    }
  }

  String countryCurrency(String countryCode) {
    return defaultDisplayCurrency;
  }

  /// Resolve charge currency: USD default, then country/channel, clamped to merchant.
  String resolveCheckoutCurrency({
    required String countryCode,
    PaystackChannel? channel,
  }) {
    final override = dotenv.env['PAYSTACK_CURRENCY'] ?? '';
    if (override.isNotEmpty && merchantSupports(override)) {
      return override.toUpperCase();
    }

    final hints = <String?>[
      if (channel != null) currencyHintForChannel(channel),
      countryCurrency(countryCode),
      defaultDisplayCurrency,
      primaryCurrency,
    ];

    for (final hint in hints) {
      if (hint == null) continue;
      final upper = hint.toUpperCase();
      if (merchantSupports(upper)) return upper;
    }

    return primaryCurrency;
  }

  PaystackCheckoutQuote checkoutQuote({
    required double usdAmount,
    PaystackChannel? channel,
  }) {
    return PaystackCheckoutQuote(
      usdAmount: usdAmount,
      amountInSubunits: _toSubunits(usdAmount, 'USD'),
      channel: channel,
    );
  }

  String resolveCurrencyFromDevice() => defaultDisplayCurrency;

  String formatAmount(double amount, String currency) {
    final sym = _currencySymbols[currency.toUpperCase()] ?? currency;
    final upper = currency.toUpperCase();
    final decimals = upper == 'USD' || upper == 'GBP' || upper == 'EUR' ? 2 : 0;
    return '$sym${amount.toStringAsFixed(decimals)}';
  }

  /// USD-only labels.
  ({String usd, String currency}) priceLabels({
    required double usdPrice,
    PaystackChannel? channel,
  }) {
    final quote = checkoutQuote(
      usdAmount: usdPrice,
      channel: channel,
    );
    return (
      usd: quote.usdLabel,
      currency: 'USD',
    );
  }

  Future<List<Map<String, dynamic>>> getSavedTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('paystack_transactions') ?? [];
      return raw
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList()
        ..sort((a, b) => (b['timestamp'] as String? ?? '')
            .compareTo(a['timestamp'] as String? ?? ''));
    } catch (_) {
      return [];
    }
  }

  /// Run Paystack hosted checkout from a pre-built [quote].
  Future<PaymentResult> executeCheckoutFromQuote({
    required BuildContext context,
    required PaystackCheckoutQuote quote,
    required String customerEmail,
    PaystackChannel channel = PaystackChannel.all,
    String? description,
    String? planName,
    Map<String, dynamic>? metadata,
  }) {
    return executeCheckout(
      context: context,
      amount: quote.usdAmount,
      customerEmail: customerEmail,
      currency: 'USD',
      channel: channel,
      description: description,
      planName: planName,
      metadata: {
        ...?metadata,
        'usd_amount': quote.usdAmount,
        'charged_currency': 'USD',
      },
    );
  }

  /// Run Paystack hosted checkout (all supported channels).
  Future<PaymentResult> executeCheckout({
    required BuildContext context,
    required double amount,
    required String customerEmail,
    required String currency,
    PaystackChannel channel = PaystackChannel.all,
    String? description,
    String? planName,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isConfigured) {
      return PaymentResult(
        success: false,
        message: 'Paystack is not configured. Please contact support.',
      );
    }

    if (customerEmail.trim().isEmpty) {
      return PaymentResult(
        success: false,
        message: 'A valid email address is required for payment.',
      );
    }

    await _loadMerchantCurrencies();
    var normalizedCurrency = currency.toUpperCase();
    var finalAmount = amount;
    
    if (!merchantSupports(normalizedCurrency)) {
      normalizedCurrency = primaryCurrency;
      // Convert USD to fallback merchant currency to avoid undercharging
      if (currency.toUpperCase() == 'USD') {
        if (normalizedCurrency == 'KES') finalAmount = amount * 130.0;
        else if (normalizedCurrency == 'NGN') finalAmount = amount * 1500.0;
        else if (normalizedCurrency == 'GHS') finalAmount = amount * 15.0;
        else if (normalizedCurrency == 'ZAR') finalAmount = amount * 19.0;
      }
    }
    final reference = 'WL_${DateTime.now().millisecondsSinceEpoch}';
    final amountInSubunits = _toSubunits(finalAmount, normalizedCurrency);

    debugPrint(
      '📝 Paystack checkout: $reference | $finalAmount $normalizedCurrency '
      '($amountInSubunits subunits) | channel: ${channel.label} | '
      'merchant currencies: $_merchantCurrencies',
    );

    final checkoutMetadata = <String, dynamic>{
      if (description != null) 'description': description,
      ...?metadata,
      'cancel_action': 'cancelurl.com',
    };

    try {
      final initResult = await _initializeTransaction(
        email: customerEmail.trim(),
        amount: amountInSubunits,
        currency: normalizedCurrency,
        reference: reference,
        channel: channel,
        metadata: checkoutMetadata,
      );

      if (initResult.data == null) {
        return PaymentResult(
          success: false,
          ref: reference,
          message: initResult.error ?? 'Failed to initialize Paystack transaction',
        );
      }

      final initData = initResult.data!;

      final authUrl = initData['authorization_url'] as String?;
      final txnReference = initData['reference'] as String? ?? reference;

      if (authUrl == null || authUrl.isEmpty) {
        return PaymentResult(
          success: false,
          ref: reference,
          message: 'Paystack did not return a checkout URL',
        );
      }

      final approved = await _launchCheckoutWebView(
        context: context,
        authorizationUrl: authUrl,
        reference: txnReference,
        planName: planName ?? description,
        amountLabel: formatAmount(amount, normalizedCurrency),
      );

      if (!approved) {
        return PaymentResult(
          success: false,
          ref: txnReference,
          channel: channel == PaystackChannel.all ? null : channel,
          message: 'Payment cancelled',
        );
      }

      final verification = await verifyTransaction(txnReference);
      if (verification == null || verification['status'] != true) {
        return PaymentResult(
          success: false,
          ref: txnReference,
          message: 'Unable to verify payment',
        );
      }

      final data = verification['data'] as Map<String, dynamic>?;
      final gatewayResponse =
          data?['gateway_response']?.toString().toLowerCase() ?? '';
      final status = data?['status']?.toString().toLowerCase() ?? '';

      final isSuccessful = status == 'success' ||
          gatewayResponse == 'approved' ||
          gatewayResponse == 'successful';

      if (!isSuccessful) {
        return PaymentResult(
          success: false,
          ref: txnReference,
          message: data?['gateway_response']?.toString() ?? 'Payment failed',
          details: verification,
        );
      }

      final transactionId = data?['id']?.toString();
      await _saveTransaction(
        reference: txnReference,
        transactionId: transactionId,
        amount: amount,
        currency: normalizedCurrency,
        channel: channel,
      );

      return PaymentResult(
        success: true,
        ref: txnReference,
        transactionId: transactionId,
        channel: channel == PaystackChannel.all ? null : channel,
        message: 'Payment completed successfully',
        details: verification,
      );
    } catch (e) {
      debugPrint('❌ Paystack checkout error: $e');
      return PaymentResult(success: false, message: e.toString());
    }
  }

  Future<Map<String, dynamic>?> verifyTransaction(String reference) async {
    if (!isConfigured) return null;

    try {
      final response = await http.get(
        Uri.parse('$_apiBase/transaction/verify/$reference'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_secretKey',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint(
        '❌ Paystack verify failed (${response.statusCode}): ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('❌ Paystack verify error: $e');
      return null;
    }
  }



  String _normalizeCurrency(String currency) {
    final upper = currency.toUpperCase();
    if (_merchantCurrencies.contains(upper)) return upper;
    if (_supportedCurrencies.contains(upper)) return upper;
    return primaryCurrency;
  }

  int _toSubunits(double amount, String currency) {
    return (amount * 100).round();
  }

  Future<({Map<String, dynamic>? data, String? error})> _initializeTransaction({
    required String email,
    required int amount,
    required String currency,
    required String reference,
    required PaystackChannel channel,
    required Map<String, dynamic> metadata,
  }) async {
    final amountInt = amount;
    final body = <String, dynamic>{
      'email': email,
      'amount': amountInt,
      'reference': reference,
      'currency': currency,
      'metadata': metadata,
      'callback_url': _callbackUrl,
    };

    final channelValue = channel.apiValue;
    if (channelValue != null) {
      body['channels'] = [channelValue];
    }

    final response = await http.post(
      Uri.parse('$_apiBase/transaction/initialize'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_secretKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final err = _extractApiError(response.body);
      debugPrint(
        '❌ Paystack initialize failed (${response.statusCode}): ${response.body}',
      );
      return (data: null, error: err);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['status'] != true) {
      return (data: null, error: decoded['message']?.toString());
    }
    return (data: decoded['data'] as Map<String, dynamic>?, error: null);
  }

  String? _extractApiError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _launchCheckoutWebView({
    required BuildContext context,
    required String authorizationUrl,
    required String reference,
    String? planName,
    String? amountLabel,
  }) async {
    final completer = Completer<bool>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaystackCheckoutScreen(
          authorizationUrl: authorizationUrl,
          reference: reference,
          callbackUrl: _callbackUrl,
          planName: planName,
          amountLabel: amountLabel,
          onVerify: verifyTransaction,
          onComplete: (success) {
            Navigator.of(context).pop();
            if (!completer.isCompleted) completer.complete(success);
          },
        ),
      ),
    );

    if (!completer.isCompleted) completer.complete(false);
    return completer.future;
  }

  Future<void> _saveTransaction({
    required String reference,
    String? transactionId,
    required double amount,
    required String currency,
    required PaystackChannel channel,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactions = prefs.getStringList('paystack_transactions') ?? [];
      transactions.add(jsonEncode({
        'reference': reference,
        'transactionId': transactionId,
        'amount': amount,
        'currency': currency,
        'channel': channel.apiValue ?? 'all',
        'channelLabel': channel.label,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList('paystack_transactions', transactions);
    } catch (e) {
      debugPrint('⚠️ Failed to save Paystack transaction: $e');
    }
  }
}
