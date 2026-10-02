import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../home/presentation/widgets/upgrade_modal_bottom_sheet.dart';
import '../../../../core/services/paystack_service.dart';
import '../../../../core/providers/profile_provider.dart';

/// Shows a polished Paystack payment bottom sheet.
/// Returns checkout selection (country, channel, converted quote) or null if dismissed.
Future<PaystackCheckoutSelection?> showPaystackPaymentSheet({
  required BuildContext context,
  required SubscriptionTier tier,
  PaystackChannel initialChannel = PaystackChannel.all,
}) {
  return showModalBottomSheet<PaystackCheckoutSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PaystackPaymentSheet(
      tier: tier,
      initialChannel: initialChannel,
    ),
  );
}

class PaystackPaymentSheet extends StatefulWidget {
  final SubscriptionTier tier;
  final PaystackChannel initialChannel;

  const PaystackPaymentSheet({
    super.key,
    required this.tier,
    this.initialChannel = PaystackChannel.all,
  });

  @override
  State<PaystackPaymentSheet> createState() => _PaystackPaymentSheetState();
}

class _PaystackPaymentSheetState extends State<PaystackPaymentSheet> {
  late PaystackChannel _selected;

  final _paystack = PaystackService();
  bool _currenciesLoaded = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialChannel;

    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    await _paystack.ensureMerchantCurrenciesLoaded();
    if (mounted) setState(() => _currenciesLoaded = true);
  }

  PaystackCheckoutQuote get _quote => _paystack.checkoutQuote(
        usdAmount: _getPrice(widget.tier),
        channel: _selected,
      );

  double _getPrice(SubscriptionTier tier) {
    if (tier == SubscriptionTier.premium) {
      return 119.99;
    } else {
      return 149.99;
    }
  }

  Color get _tierColor {
    switch (widget.tier) {
      case SubscriptionTier.premium:
        return Colors.amberAccent;
      case SubscriptionTier.ultra:
        return const Color(0xFFE81CFF);
      case SubscriptionTier.freemium:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final prices = _paystack.priceLabels(
      usdPrice: _getPrice(widget.tier),
    );
    final period = 'year';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final merchantCurrencies = _paystack.merchantCurrencies;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: PaystackService.brandNavy.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                PaystackService.brandBlue,
                                PaystackService.brandBlue.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Secure checkout',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: PaystackService.brandNavy,
                                ),
                              ),
                              Text(
                                'Powered by Paystack',
                                style: TextStyle(
                                  color: PaystackService.brandBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _PlanSummaryCard(
                      tier: widget.tier,
                      tierColor: _tierColor,
                      usdPrice: prices.usd,
                      currency: prices.currency,
                      period: period,
                    ),
                    const SizedBox(height: 16),
                    if (_currenciesLoaded && merchantCurrencies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Merchant accepts: ${merchantCurrencies.join(', ')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: PaystackService.brandBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ChannelHeroTile(
                      channel: PaystackChannel.all,
                      selected: _selected == PaystackChannel.all,
                      onTap: () => setState(() => _selected = PaystackChannel.all),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'OR CHOOSE A METHOD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: PaystackChannelX.specificChannels.length,
                      itemBuilder: (context, index) {
                        final channel = PaystackChannelX.specificChannels[index];
                        return _ChannelGridTile(
                          channel: channel,
                          selected: _selected == channel,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = channel);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_tierColor, _tierColor.withValues(alpha: 0.85)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _tierColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            Navigator.pop(
                              context,
                              PaystackCheckoutSelection(
                                channel: _selected,
                                quote: _quote,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_rounded, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Pay ${quote.usdLabel} with Paystack',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _PaystackSecurityFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  final SubscriptionTier tier;
  final Color tierColor;
  final String usdPrice;
  final String currency;
  final String period;

  const _PlanSummaryCard({
    required this.tier,
    required this.tierColor,
    required this.usdPrice,
    required this.currency,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tierColor.withValues(alpha: 0.12),
            PaystackService.brandBlue.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier == SubscriptionTier.premium ? 'Welloa Premium' : 'Welloa ULTRA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: PaystackService.brandNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Billed per $period',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                usdPrice,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: tierColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelHeroTile extends StatelessWidget {
  final PaystackChannel channel;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelHeroTile({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      PaystackService.brandBlue.withValues(alpha: 0.18),
                      PaystackService.brandBlue.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            color: selected ? null : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? PaystackService.brandBlue
                  : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PaystackService.brandBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(channel.icon, color: PaystackService.brandBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: PaystackService.brandNavy,
                      ),
                    ),
                    Text(
                      channel.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: PaystackService.brandBlue),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelGridTile extends StatelessWidget {
  final PaystackChannel channel;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelGridTile({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? channel.accentColor.withValues(alpha: 0.12)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? channel.accentColor : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(channel.icon, color: channel.accentColor, size: 22),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_rounded, color: channel.accentColor, size: 18),
                ],
              ),
              const Spacer(),
              Text(
                channel.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: PaystackService.brandNavy,
                ),
              ),
              Text(
                channel.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaystackSecurityFooter extends StatelessWidget {
  const _PaystackSecurityFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _badge(Icons.https_rounded, 'Encrypted'),
          const SizedBox(width: 8),
          _badge(Icons.verified_user_rounded, 'PCI DSS'),
          const SizedBox(width: 8),
          _badge(Icons.account_balance_rounded, 'Paystack'),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Success dialog after subscription payment.
Future<void> showPaystackSuccessDialog(
  BuildContext context, {
  required PaymentResult result,
  required String planName,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'success',
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: Color(0xFF10B981),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome to Premium!',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: PaystackService.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$planName is now active.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                    if (result.ref != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Ref: ${result.ref}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Start exploring',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}



/// Supported Paystack methods strip for subscription screen.
class PaystackMethodsStrip extends StatelessWidget {
  const PaystackMethodsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final methods = PaystackChannelX.specificChannels.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCEPTED ON PAYSTACK',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: methods.map((c) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.accentColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.icon, size: 14, color: c.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.accentColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
