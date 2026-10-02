import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Branded Paystack hosted checkout (WebView).
class PaystackCheckoutScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final String callbackUrl;
  final String? planName;
  final String? amountLabel;
  final Future<Map<String, dynamic>?> Function(String reference) onVerify;
  final void Function(bool success) onComplete;

  const PaystackCheckoutScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.callbackUrl,
    this.planName,
    this.amountLabel,
    required this.onVerify,
    required this.onComplete,
  });

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen>
    with SingleTickerProviderStateMixin {
  static const _paystackBlue = Color(0xFF00C3F7);
  static const _paystackNavy = Color(0xFF011B33);

  late final WebViewController _controller;
  late final AnimationController _pulseController;
  bool _isLoading = true;
  bool _isVerifying = false;
  double _loadProgress = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Wellor/Flutter Paystack Checkout')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _loadProgress = progress / 100);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) async {
            final url = request.url;
            if (_isVerifying) return NavigationDecision.navigate;

            if (url.contains('cancelurl.com') ||
                url.contains('paystack.co/close') ||
                url.contains(widget.callbackUrl)) {
              await _verifyAndClose();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndClose() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);
    HapticFeedback.mediumImpact();

    final verification = await widget.onVerify(widget.reference);
    final data = verification?['data'] as Map<String, dynamic>?;
    final gatewayResponse =
        data?['gateway_response']?.toString().toLowerCase() ?? '';
    final status = data?['status']?.toString().toLowerCase() ?? '';

    final success = status == 'success' ||
        gatewayResponse == 'approved' ||
        gatewayResponse == 'successful';

    if (!mounted) return;

    if (success) {
      await _showResultOverlay(
        icon: Icons.verified_rounded,
        title: 'Payment successful',
        subtitle: 'Activating your subscription…',
        color: const Color(0xFF10B981),
      );
    } else {
      await _showResultOverlay(
        icon: Icons.error_outline_rounded,
        title: 'Payment not completed',
        subtitle: data?['gateway_response']?.toString() ?? 'Please try again',
        color: Colors.redAccent,
      );
    }

    widget.onComplete(success);
  }

  Future<void> _showResultOverlay({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, _, __) {
        return FadeTransition(
          opacity: anim,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 56, color: color),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: _paystackNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _cancelCheckout() {
    HapticFeedback.lightImpact();
    widget.onComplete(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paystackNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoading || _loadProgress < 1)
              LinearProgressIndicator(
                value: _loadProgress > 0 ? _loadProgress : null,
                minHeight: 3,
                backgroundColor: Colors.white12,
                color: _paystackBlue,
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_isVerifying)
                      Container(
                        color: Colors.white.withValues(alpha: 0.92),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: _paystackBlue),
                              SizedBox(height: 16),
                              Text(
                                'Verifying payment…',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isLoading && !_isVerifying)
                      Container(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ScaleTransition(
                                scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                                  CurvedAnimation(
                                    parent: _pulseController,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: _paystackBlue.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: _paystackBlue,
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Loading secure checkout',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: _paystackNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Powered by Paystack',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _paystackNavy,
                _paystackNavy.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _cancelCheckout,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paystack Checkout',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.planName != null)
                          Text(
                            widget.planName!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.amountLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _paystackBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _paystackBlue.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        widget.amountLabel!,
                        style: const TextStyle(
                          color: _paystackBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _trustChip(Icons.https_rounded, '256-bit SSL'),
                  const SizedBox(width: 8),
                  _trustChip(Icons.verified_user_rounded, 'PCI DSS'),
                  const SizedBox(width: 8),
                  _trustChip(Icons.account_balance_rounded, 'Paystack'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trustChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: _paystackBlue),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
