import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription_tier.dart';
import '../screens/subscription_screen.dart';

/// UNICORN UX: The Spatial Feature Gateway.
/// Features: Backdrop Blurring, Kinetic Benefit Staggering, and Neural Haptics.
class FeatureRestrictionDialog extends StatelessWidget {
  final String featureName;
  final String featureDescription;
  final IconData icon;

  const FeatureRestrictionDialog({
    super.key,
    required this.featureName,
    required this.featureDescription,
    this.icon = Icons.hub_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.05)],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              _buildApertureIcon(),
              const SizedBox(height: 20),
              Text(
                featureName.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Text(
                featureDescription,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.8), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              _buildProIntelligenceBanner(subscriptionProvider),
              const SizedBox(height: 24),
              ...[
                'Higher scan & meal-plan quotas on paid tiers',
                'Premium: coach, Glucose Nexus, wearables, family hub',
                'Ultra: unlimited scans, CGM linking, AI Health Team',
              ].map(_buildBenefitNode),
              const SizedBox(height: 32),
              _buildActionDock(context),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildApertureIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: const Color(0xFF10B981), size: 32),
    );
  }

  Widget _buildProIntelligenceBanner(SubscriptionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.getUpgradeMessage(featureName),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitNode(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionDock(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('UNLOCK CLINICAL SUITE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('KEEP BASIC ACCESS', style: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ],
    );
  }

  static void show(BuildContext context, {required String featureName, required String featureDescription, IconData icon = Icons.lock_person_rounded}) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => FeatureRestrictionDialog(featureName: featureName, featureDescription: featureDescription, icon: icon),
      transitionBuilder: (context, anim1, anim2, child) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12 * anim1.value, sigmaY: 12 * anim1.value),
        child: FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1.drive(CurveTween(curve: Curves.easeOut)), child: child)),
      ),
    );
  }

  /// Show subscription expired/404 prompt
  static void showSubscriptionPrompt(BuildContext context) {
    show(
      context,
      featureName: 'Subscription Required',
      featureDescription: 'Your subscription has expired or is not active. Upgrade to Premium to unlock all features!',
      icon: Icons.workspace_premium_rounded,
    );
  }
}

// ============================================
// COMPONENT: LIQUID SCAN LIMIT BANNER
// ============================================

class ScanLimitBanner extends StatelessWidget {
  const ScanLimitBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    if (!subscriptionProvider.isFree) return const SizedBox.shrink();

    final remaining = subscriptionProvider.remainingScans;
    final double progress = (remaining / SubscriptionQuotas.freeScansPerDay).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.sensors_rounded, color: Color(0xFF0F172A), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('$remaining NEURAL SCANS REMAINING', 
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                    ),
                    _UnicornUpgradeChip(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLiquidProgressBar(progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidProgressBar(double progress) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)],
          ),
        ),
      ),
    );
  }
}

class _UnicornUpgradeChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
        child: const Text('UPGRADE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
}

// ============================================
// ATOMIC UNICORN COMPONENTS
// ============================================

class PremiumBadge extends StatelessWidget {
  final String label;
  const PremiumBadge({super.key, this.label = 'PRO'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 10),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class UpgradeButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const UpgradeButton({super.key, this.text = 'INITIALIZE PRO SYNC', this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed ?? () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())),
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(text.toUpperCase()),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12),
          elevation: 0,
        ),
      ),
    );
  }
}

// Core Access Logic
bool checkFeatureAccess(BuildContext context, {required String featureName, required String featureDescription, required bool Function(SubscriptionProvider) accessCheck, IconData icon = Icons.lock_person_rounded}) {
  final subscriptionProvider = context.read<SubscriptionProvider>();
  if (accessCheck(subscriptionProvider)) return true;
  FeatureRestrictionDialog.show(context, featureName: featureName, featureDescription: featureDescription, icon: icon);
  return false;
}

/// Check if user can access meal planning
bool checkMealPlanningAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'AI Meal Planning',
    featureDescription: 'Unlock personalized AI-powered meal plans tailored to your health goals and dietary preferences.',
    accessCheck: (provider) => provider.canAccessAIMealPlanning,
    icon: Icons.restaurant_menu_rounded,
  );
}

/// Check if user can post in communities
// TODO: Community features not implemented
// bool checkCommunityPostAccess(BuildContext context) {
//   return checkFeatureAccess(
//     context,
//     featureName: 'Community Posting',
//     featureDescription: 'Share your journey, post updates, and engage with the community. Upgrade to participate!',
//     accessCheck: (provider) => provider.canPostInGroups,
//     icon: Icons.groups_rounded,
//   );
// }

/// Check if user can access CGM integration (Ultra; LibreView linking in-app).
bool checkCGMAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'CGM Integration',
    featureDescription:
        'Ultra tier: link LibreView — glucose appears in your command center.',
    accessCheck: (provider) => provider.canAccessCGMIntegration,
    icon: Icons.monitor_heart_rounded,
  );
}

/// Check if user can access wearable sync
bool checkWearableAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Wearable Sync',
    featureDescription: 'Sync data from Apple Watch, Fitbit, Garmin and other health devices.',
    accessCheck: (provider) => provider.canAccessWearableSync,
    icon: Icons.watch_rounded,
  );
}

/// Check if user can access family features
bool checkFamilyAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Family Features',
    featureDescription:
        'Premium: up to 7 family members. Ultra: up to 10. Shared meal planning and health dashboards.',
    accessCheck: (provider) => provider.canAccessFamilyProfiles,
    icon: Icons.family_restroom_rounded,
  );
}

/// Premium+: GlucoCoach health coach (Twilio + Claude Sonnet replies).
bool checkGlucoCoachCoachAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'GlucoCoach',
    featureDescription:
        'Premium and Ultra unlock 24/7 GlucoCoaching, check-ins, and health reminders.',
    accessCheck: (provider) => provider.hasGlucoCoach,
    icon: Icons.chat_rounded,
  );
}

/// Premium+: track multiple health goals (6 on Premium, unlimited on Ultra).
bool checkHealthGoalsAccess(BuildContext context, {required int desiredCount}) {
  final provider = context.read<SubscriptionProvider>();
  final max = provider.maxHealthGoals;
  if (max < 0 || desiredCount <= max) return true;
  FeatureRestrictionDialog.show(
    context,
    featureName: 'Health goals',
    featureDescription:
        'Premium tracks up to 6 goals. Ultra is unlimited. Upgrade to add more.',
    icon: Icons.flag_rounded,
  );
  return false;
}

/// Check if user can access advanced analytics
bool checkAdvancedAnalyticsAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Advanced Analytics',
    featureDescription: 'Access 30-day insights, detailed nutrition trends, and personalized recommendations.',
    accessCheck: (provider) => provider.canAccessAdvancedAnalytics,
    icon: Icons.analytics_rounded,
  );
}

/// Check if user can initiate a scan (scan limit check)
bool checkScanLimitAccess(BuildContext context) {
  final provider = context.read<SubscriptionProvider>();
  if (provider.canInitiateScan) return true;
  
  FeatureRestrictionDialog.show(
    context,
    featureName: 'Scan limit reached',
    featureDescription:
        'You\'ve used today\'s scans for your plan. Starter and Premium have higher limits; Ultra includes unlimited scans.',
    icon: Icons.qr_code_scanner_rounded,
  );
  return false;
}

/// Records a Gluco Coach chat message (free: 1/day; paid: tiered).
bool checkGlucoCoachQuota(BuildContext context) {
  final provider = context.read<SubscriptionProvider>();
  if (provider.subscription == null || provider.subscription!.glucoCoachQuotaAllows()) {
    return true;
  }

  FeatureRestrictionDialog.show(
    context,
    featureName: 'Gluco Coach limit reached',
    featureDescription:
        'Free plan includes ${SubscriptionQuotas.freeGlucoCoachChats} Gluco Coach chats per day '
        '(Claude Sonnet), personalized to your health goals and conditions. '
        'Starter adds ${SubscriptionQuotas.starterGlucoCoachChatsPerDay}/day; '
        'Premium ${SubscriptionQuotas.premiumGlucoCoachChatsPerDay}/day; Ultra is unlimited.',
    icon: Icons.chat_bubble_rounded,
  );
  return false;
}

Future<bool> recordGlucoCoachAccess(BuildContext context) async {
  final provider = context.read<SubscriptionProvider>();
  final allowed = await provider.recordGlucoCoachChat();
  if (allowed || !context.mounted) return allowed;

  FeatureRestrictionDialog.show(
    context,
    featureName: 'Gluco Coach limit reached',
    featureDescription:
        'Free plan includes ${SubscriptionQuotas.freeGlucoCoachChats} Gluco Coach chats per day '
        '(Claude Sonnet), personalized to your health goals and conditions. '
        'Starter adds ${SubscriptionQuotas.starterGlucoCoachChatsPerDay}/day; '
        'Premium ${SubscriptionQuotas.premiumGlucoCoachChatsPerDay}/day; Ultra is unlimited.',
    icon: Icons.chat_bubble_rounded,
  );
  return false;
}

/// Records an AI interaction against the user's plan quota before an LLM call.
Future<bool> recordAiInteractionAccess(BuildContext context) async {
  final provider = context.read<SubscriptionProvider>();
  final allowed = await provider.recordAiInteraction();
  if (allowed || !context.mounted) return allowed;

  FeatureRestrictionDialog.show(
    context,
    featureName: 'Daily AI limit reached',
    featureDescription:
        'Free plan includes ${SubscriptionQuotas.freeAiInteractionsPerDay} AI chat messages per day '
        '(chat, health analysis, and search). Upgrade for unlimited access.',
    icon: Icons.psychology_rounded,
  );
  return false;
}

/// Check if user can access multi-angle AI scanning
bool checkMultiAngleAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Multi-Angle AI Scanner',
    featureDescription: 'Get more accurate calorie estimates with AI-powered multi-angle food scanning.',
    accessCheck: (provider) => provider.hasAdFreeExperience, // Available to all paid tiers
    icon: Icons.view_in_ar_rounded,
  );
}

/// Glucose Nexus (Premium+). Use before navigating to [GlucoseNexusDashboard].
bool checkGlucoseNexusAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Glucose Nexus',
    featureDescription:
        'Premium and Ultra unlock the full Glucose Nexus: metabolic lens, predictive insights, and pro device views.',
    accessCheck: (provider) => provider.hasGlucoseNexusPro,
    icon: Icons.monitor_heart_rounded,
  );
}

// --- Ultra entitlements (background services + future UI should match these) ---

bool checkGoalOptimizerAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Goal Optimizer',
    featureDescription:
        'Ultra unlocks AI milestone decomposition, difficulty tuning, and success prediction for structured goals.',
    accessCheck: (p) => p.hasGoalOptimizer,
    icon: Icons.flag_rounded,
  );
}

bool checkMedicationTrackingAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Medication intelligence',
    featureDescription:
        'Ultra includes scheduled adherence checks, meal-time interaction awareness, and escalation-aware coaching.',
    accessCheck: (p) => p.hasMedicationTracking,
    icon: Icons.medication_rounded,
  );
}

bool checkVoiceEscalationAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Voice escalation',
    featureDescription:
        'Ultra can trigger outbound voice calls for critical events when Twilio is configured.',
    accessCheck: (p) => p.hasVoiceEscalation,
    icon: Icons.phone_in_talk_rounded,
  );
}

bool checkPersonalityAdaptationAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Personality adaptation',
    featureDescription:
        'Ultra adapts coaching tone, notification style, and routine-aware messaging to your psychology profile.',
    accessCheck: (p) => p.hasPersonalityAdaptation,
    icon: Icons.psychology_rounded,
  );
}

bool checkActivityRecommendationsAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Smart activity picks',
    featureDescription:
        'Ultra enables context-aware activity recommendations aligned to goals, energy, and wearables.',
    accessCheck: (p) => p.hasActivityRecommendations,
    icon: Icons.directions_run_rounded,
  );
}

bool checkAgenticModeAccess(BuildContext context) {
  return checkFeatureAccess(
    context,
    featureName: 'Agentic metabolic twin',
    featureDescription:
        'Ultra runs the closed-loop supervisor: CGM safety math, engagement agent, and tiered interventions.',
    accessCheck: (p) => p.hasAgenticMode,
    icon: Icons.hub_rounded,
  );
}