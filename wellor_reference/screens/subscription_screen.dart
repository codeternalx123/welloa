import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptic Feedback
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription_tier.dart';
import '../services/paystack_service.dart';
import '../widgets/paystack_payment_ui.dart';

/// Paystack-integrated subscription checkout.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionPlan? _selectedPlan;
  bool _isYearly = false; // NEW: Monthly/Yearly toggle

  @override
  void initState() {
    super.initState();
    // Default to the first available plan (Starter monthly)
    _selectedPlan = SubscriptionPlan.starterMonthly;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Wellor Premium',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          // 1. PREMIUM BACKGROUND: Soft Mesh FinTech Gradient
          _buildVaultBackground(),

          Consumer<SubscriptionProvider>(
            builder: (context, provider, child) {
              return SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // 2. CURRENT STATUS HEADER
                    SliverToBoxAdapter(child: _buildStatusHeader(provider)),

                    // 3. PLAN SELECTOR (Horizontal Kinetic List)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _buildPlanSelector(),
                      ),
                    ),

                    // 4. SELECTED PLAN DETAILS
                    if (_selectedPlan != null &&
                        _selectedPlan!.tier != SubscriptionTier.free) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: _buildSelectedPlanDetails(),
                        ),
                      ),
                    ],

                    // 5. PAYSTACK METHODS
                    if (_selectedPlan != null &&
                        _selectedPlan!.tier != SubscriptionTier.free) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: const SliverToBoxAdapter(
                          child: PaystackMethodsStrip(),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    ],

                    // 6. SUBSCRIBE BUTTON
                    if (_selectedPlan != null &&
                        _selectedPlan!.tier != SubscriptionTier.free) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _buildSubscribeButton(),
                        ),
                      ),
                    ],

                    // 7. FREE PLAN INFO
                    if (_selectedPlan?.tier == SubscriptionTier.free) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(child: _buildFreePlanInfo()),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================

  Widget _buildVaultBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.05,
          child: Icon(
            Icons.shield_moon_rounded,
            size: 400,
            color: Colors.blue[900],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(SubscriptionProvider provider) {
    final currentTier = provider.subscription?.tier ?? SubscriptionTier.free;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR MEMBERSHIP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.blue,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentTier == SubscriptionTier.free
                ? 'Wellor Free'
                : currentTier == SubscriptionTier.starter
                    ? 'Starter active'
                    : currentTier == SubscriptionTier.premium
                        ? 'Premium active'
                        : 'Ultra active',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    // Get plans based on monthly/yearly toggle
    final plans = _isYearly
        ? [
            SubscriptionPlan.free,
            SubscriptionPlan.starterYearly,
            SubscriptionPlan.premiumYearly,
            SubscriptionPlan.ultraYearly,
          ]
        : [
            SubscriptionPlan.free,
            SubscriptionPlan.starterMonthly,
            SubscriptionPlan.premiumMonthly,
            SubscriptionPlan.ultraMonthly,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHOOSE YOUR PLAN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              
              // MONTHLY/YEARLY TOGGLE
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton('Monthly', !_isYearly, () {
                        setState(() {
                          _isYearly = false;
                          // Update selected plan to monthly equivalent
                          if (_selectedPlan?.tier == SubscriptionTier.starter) {
                            _selectedPlan = SubscriptionPlan.starterMonthly;
                          } else if (_selectedPlan?.tier == SubscriptionTier.premium) {
                            _selectedPlan = SubscriptionPlan.premiumMonthly;
                          } else if (_selectedPlan?.tier == SubscriptionTier.ultra) {
                            _selectedPlan = SubscriptionPlan.ultraMonthly;
                          }
                        });
                      }),
                      _buildToggleButton('Yearly', _isYearly, () {
                        setState(() {
                          _isYearly = true;
                          // Update selected plan to yearly equivalent
                          if (_selectedPlan?.tier == SubscriptionTier.starter) {
                            _selectedPlan = SubscriptionPlan.starterYearly;
                          } else if (_selectedPlan?.tier == SubscriptionTier.premium) {
                            _selectedPlan = SubscriptionPlan.premiumYearly;
                          } else if (_selectedPlan?.tier == SubscriptionTier.ultra) {
                            _selectedPlan = SubscriptionPlan.ultraYearly;
                          }
                        });
                      }),
                    ],
                  ),
                ),
              ),
              
              // Savings badge for yearly
              if (_isYearly)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '🎉 SAVE UP TO 42% (5 MONTHS FREE!)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isSelected = _selectedPlan == plan;
              final isFree = plan.tier == SubscriptionTier.free;
              final isYearly = plan.period == SubscriptionPeriod.yearly;
              final isStarter = plan.tier == SubscriptionTier.starter;
              final isPremium = plan.tier == SubscriptionTier.premium;
              final isUltra = plan.tier == SubscriptionTier.ultra;

              // Tier colors
              Color tierColor = Colors.grey;
              if (isStarter) tierColor = const Color(0xFF3B82F6); // Blue
              if (isPremium) tierColor = const Color(0xFF8B5CF6); // Purple
              if (isUltra) tierColor = const Color(0xFFEC4899); // Pink

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedPlan = plan);
                  // Show plan details modal when tapping
                  _showPlanDetailsModal(plan);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFree
                        ? Colors.grey[100]
                        : isSelected
                        ? tierColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: tierColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                            ),
                          ],
                    border: Border.all(
                      color: isFree
                          ? Colors.grey[300]!
                          : (isSelected ? tierColor : Colors.transparent),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge
                      if (isFree) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'GEMINI AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                      ] else if (isStarter) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CLAUDE AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                      ] else if (isPremium) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AI COACH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                      ] else if (isUltra) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber[600],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AI HEALTH TEAM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                      ] else ...[
                        const SizedBox(height: 18),
                      ],

                      // Plan name
                      Text(
                        isFree ? 'Free' : (isStarter ? 'Starter' : (isPremium ? 'Premium' : 'Ultra')),
                        style: TextStyle(
                          color: isFree
                              ? Colors.grey[600]
                              : (isSelected ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Price
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isFree
                                ? 'FREE'
                                : '\$${plan.price.toStringAsFixed(plan.price == plan.price.toInt() ? 0 : 2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isFree
                                  ? Colors.grey[500]
                                  : (isSelected ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      Text(
                        isFree ? 'forever' : (isYearly ? '/year' : '/month'),
                        style: TextStyle(
                          color: isFree
                              ? Colors.grey[500]
                              : (isSelected ? Colors.white70 : Colors.grey),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const Spacer(),

                      // Tap to view hint
                      if (!isFree)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 10,
                                color: isSelected ? Colors.white : Colors.grey[600],
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  'Details',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '3 scans/day',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showPlanDetailsModal(SubscriptionPlan plan) {
    final isStarter = plan.tier == SubscriptionTier.starter;
    final isPremium = plan.tier == SubscriptionTier.premium;
    final isUltra = plan.tier == SubscriptionTier.ultra;
    final isFree = plan.tier == SubscriptionTier.free;
    
    Color primaryColor = Colors.grey[700]!;
    if (isStarter) primaryColor = const Color(0xFF3B82F6); // Blue
    if (isPremium) primaryColor = const Color(0xFF8B5CF6); // Purple
    if (isUltra) primaryColor = const Color(0xFFEC4899); // Pink

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isFree
                                  ? [Colors.grey[600]!, Colors.grey[400]!]
                                  : isStarter
                                      ? [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]
                                      : isPremium
                                          ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
                                          : [const Color(0xFFEC4899), const Color(0xFFF472B6)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isFree
                                ? Icons.lock_open_rounded
                                : isStarter
                                    ? Icons.workspace_premium_rounded
                                    : isPremium
                                        ? Icons.diamond_rounded
                                        : Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.displayName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    isFree
                                        ? 'FREE'
                                        : '\$${plan.price.toStringAsFixed(plan.price == plan.price.toInt() ? 0 : 2)}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: primaryColor,
                                    ),
                                  ),
                                  if (!isFree)
                                    Flexible(
                                      child: Text(
                                        plan.period == SubscriptionPeriod.yearly
                                            ? '/year'
                                            : '/month',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (isFree)
                                    Flexible(
                                      child: Text(
                                        '  forever',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[500],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Current plan badge for free
                    if (isFree)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Current Plan',
                                    style: TextStyle(
                                      color: Color(0xFF374151),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Upgrade anytime to unlock more features',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Savings badge for yearly
                    if (plan.period == SubscriptionPeriod.yearly)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.savings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.savingsText.isNotEmpty
                                        ? 'Annual Discount (${plan.savingsText})'
                                        : 'Annual Plan Savings',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Up to 5 months free with annual billing',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Features header
                    const Text(
                      'WHAT\'S INCLUDED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Features list
                    ...plan.features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                feature.contains('🎁')
                                    ? Icons.card_giftcard_rounded
                                    : feature.contains('🔓')
                                        ? Icons.lock_open_rounded
                                        : Icons.check_rounded,
                                color: primaryColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature
                                    .replaceAll('✅ ', '')
                                    .replaceAll('🎁 ', '')
                                    .replaceAll('🔓 ', ''),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF374151),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: isFree
                      ? OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Got It',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _selectedPlan = plan);
                      _openPaymentSheet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rocket_launch_rounded, size: 20),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Subscribe to ${isStarter ? "Starter" : (isPremium ? "Premium" : "Ultra")}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPlanDetails() {
    if (_selectedPlan == null) return const SizedBox.shrink();

    final isUltra = _selectedPlan!.tier == SubscriptionTier.ultra;
    final isPremium = _selectedPlan!.tier == SubscriptionTier.premium;
    final gradientColors = isUltra
        ? [
            const Color(0xFFEC4899), // Pink for ultra
            const Color(0xFFC026D3),
          ]
        : isPremium
        ? [
            const Color(0xFF8B5CF6), // Purple for premium
            const Color(0xFF7C3AED),
          ]
        : [
            const Color(0xFF3B82F6), // Blue for starter
            const Color(0xFF2563EB),
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                (isUltra ? const Color(0xFFEC4899) : isPremium ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6))
                    .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Gradient Background
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isUltra
                              ? Icons.auto_awesome_rounded
                              : isPremium
                              ? Icons.diamond_rounded
                              : Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPlan!.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _selectedPlan!.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showPlanDetailsModal(_selectedPlan!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'View All',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Top 4 features preview
                  ...(_selectedPlan!.features
                      .take(4)
                      .map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  feature
                                      .replaceAll('✅ ', '')
                                      .replaceAll('🎁 ', ''),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                  if (_selectedPlan!.features.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${_selectedPlan!.features.length - 4} more features',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Subtle Shine Effect - only at top, not covering content
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 60,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreePlanInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  size: 28,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Freemium Plan',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Included features at no cost',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'FREE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 20),

          // Section label
          const Text(
            'WHAT\'S INCLUDED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Features list
          ...SubscriptionPlan.free.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature.replaceAll('🔓 ', ''),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF374151),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Upgrade CTA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Upgrade to Premium for unlimited access',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton() {
    if (_selectedPlan == null) return const SizedBox.shrink();

    final isUltra = _selectedPlan!.tier == SubscriptionTier.ultra;
    final isPremium = _selectedPlan!.tier == SubscriptionTier.premium;
    final primaryColor = isUltra
        ? const Color(0xFFEC4899) // Pink for ultra
        : isPremium
        ? const Color(0xFF8B5CF6) // Purple for premium
        : const Color(0xFF3B82F6); // Blue for starter
    final originalPrice = _selectedPlan!.price;
    final period = _selectedPlan!.period == SubscriptionPeriod.yearly ? 'year' : 'month';

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _openPaymentSheet,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Subscribe - \$${originalPrice.toStringAsFixed(originalPrice == originalPrice.toInt() ? 0 : 2)}/$period',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPaymentSheet() async {
    if (_selectedPlan == null || _selectedPlan!.tier == SubscriptionTier.free) {
      return;
    }

    if (!PaystackService().isConfigured) {
      _showErrorFeedback(
        'Paystack is not configured. Add PAYSTACK_PUBLIC_KEY and PAYSTACK_SECRET_KEY to .env',
      );
      return;
    }

    HapticFeedback.heavyImpact();
    final selection = await showPaystackPaymentSheet(
      context: context,
      plan: _selectedPlan!,
    );
    if (selection == null || !mounted) return;

    await _handlePayment(
      context.read<SubscriptionProvider>(),
      selection,
    );
  }

  // ============================================
  // LOGIC: THE SECURE HANDSHAKE
  // ============================================

  Future<void> _handlePayment(
    SubscriptionProvider provider,
    PaystackCheckoutSelection selection,
  ) async {
    if (_selectedPlan == null) return;

    HapticFeedback.heavyImpact();
    _showLoadingDialog();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null || user!.email!.trim().isEmpty) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showErrorFeedback(
          'Add an email address to your account before subscribing.',
        );
        return;
      }

      final paystack = PaystackService();
      final quote = selection.quote;
      final description =
          'Wellor ${_selectedPlan!.displayName} Subscription';

      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;

      final paymentResult = await paystack.executeCheckoutFromQuote(
        context: context,
        quote: quote,
        customerEmail: user.email!,
        channel: selection.channel,
        description: description,
        planName: _selectedPlan!.displayName,
        metadata: {
          'user_id': user.uid,
          'plan': _selectedPlan!.displayName,
          'plan_id': _selectedPlan!.priceId,
          'country_code': selection.countryCode,
        },
      );

      if (paymentResult.success) {
        final upgraded = await provider.upgradeSubscription(
          plan: _selectedPlan!,
          paymentId:
              paymentResult.transactionId ?? paymentResult.ref ?? '',
          paymentMethod: 'paystack',
        );
        if (!upgraded) {
          _showErrorFeedback(
            provider.error ??
                'Payment completed but your plan could not be saved. Please contact support with your receipt.',
          );
          return;
        }

        debugPrint('✅ Payment Success:');
        debugPrint('   Reference: ${paymentResult.ref}');
        debugPrint('   Transaction ID: ${paymentResult.transactionId}');

        _showSuccessFeedback(paymentResult);
      } else {
        _showErrorFeedback(
          paymentResult.message ?? 'Payment was not completed',
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorFeedback(e.toString());
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00C3F7)),
                SizedBox(height: 16),
                Text(
                  'Preparing Paystack Checkout...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessFeedback(PaymentResult result) async {
    await showPaystackSuccessDialog(
      context,
      result: result,
      planName: _selectedPlan?.displayName ?? 'Your plan',
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _showErrorFeedback(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(error)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
