import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/unicorn_glass_card.dart';
import '../../../../shared/widgets/animated_glow_border.dart';
import '../../../payment/presentation/widgets/paystack_payment_sheet.dart';
import '../../../../core/services/paystack_service.dart';

class UpgradeModalBottomSheet extends ConsumerStatefulWidget {
  const UpgradeModalBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<UpgradeModalBottomSheet> createState() => _UpgradeModalBottomSheetState();
}

class _UpgradeModalBottomSheetState extends ConsumerState<UpgradeModalBottomSheet> {
  bool _isYearly = true; // Default to the discounted yearly plan

  void _upgrade(SubscriptionTier tier, String title) async {
    final selection = await showPaystackPaymentSheet(
      context: context,
      tier: tier,
    );
    
    if (selection != null && mounted) {
      final email = ref.read(authServiceProvider).currentUser?.email ?? 'user@welloa.app';
      
      final result = await PaystackService().executeCheckoutFromQuote(
        context: context,
        quote: selection.quote,
        customerEmail: email,
        channel: selection.channel,
        planName: title,
      );

      if (mounted) {
        if (result.success) {
          ref.read(profileProvider.notifier).updateTier(tier);
        } else if (result.message != null && result.message != 'Payment cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message!)),
          );
        }
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(Icons.workspace_premium, size: 64, color: Colors.amberAccent),
                const SizedBox(height: 16),
                const Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock unlimited access and advanced tools.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                
                // Toggle Monthly/Yearly
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isYearly = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isYearly ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Monthly', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isYearly = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isYearly ? Colors.amberAccent.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Yearly (-25%)', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Plans
                _buildPlanCard(
                  tier: SubscriptionTier.premium,
                  title: 'Welloa Premium',
                  monthlyPrice: 19.99,
                  yearlyPrice: 179.99, // $14.99/mo equivalent (-25%)
                  color: Colors.amberAccent,
                  isPopular: false,
                  features: [
                    'Unlimited food scans',
                    'Aging Speedometer',
                    'Causal Health Insights',
                    'Wearable Telemetry Access',
                  ],
                ),
                const SizedBox(height: 16),
                _buildPlanCard(
                  tier: SubscriptionTier.ultra,
                  title: 'Welloa ULTRA',
                  monthlyPrice: 49.99,
                  yearlyPrice: 449.99, // $37.49/mo equivalent
                  color: const Color(0xFFE81CFF),
                  isPopular: true,
                  features: [
                    'Everything in Premium',
                    'Aging Clock & Biometrics',
                    'Future Self Simulator',
                    'Gut Health Specialist AI',
                    'Advanced DNA Insights',
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionTier tier,
    required String title,
    required double monthlyPrice,
    required double yearlyPrice,
    required Color color,
    required List<String> features,
    bool isPopular = false,
  }) {
    final priceStr = _isYearly ? yearlyPrice.toStringAsFixed(2) : monthlyPrice.toStringAsFixed(2);
    final period = _isYearly ? '/yr' : '/mo';
    
    return UnicornGlassCard(
      child: AnimatedGlowBorder(
        glowColor: color,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              Text(title, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('\$', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(priceStr, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text(period, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
              if (_isYearly)
                 Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text('Billed annually. 50% discount applied.', style: TextStyle(color: Colors.greenAccent.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
                 ),
              const SizedBox(height: 24),
              ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(color: Colors.white70))),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.2),
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _upgrade(tier, title),
                child: Text('Choose $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
