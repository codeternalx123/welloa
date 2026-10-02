import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../providers/user_profile_provider.dart';
import '../screens/gluco_coach_chat_screen.dart';
import '../screens/glucose_unicorn_dashboard.dart';
import '../screens/subscription_screen.dart';

/// Premium+ users get the full Glucose Nexus; free/starter users get Gluco Coach access.
class GlucoseNexusGate extends StatelessWidget {
  const GlucoseNexusGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, sub, _) {
        if (sub.hasGlucoseNexusPro) {
          return const GlucoseNexusDashboard();
        }
        return const _GlucoseNexusFreeView();
      },
    );
  }
}

/// Free/starter glucose tab: Gluco Coach + upgrade path to full Nexus.
class _GlucoseNexusFreeView extends StatelessWidget {
  const _GlucoseNexusFreeView();

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final profile = context.watch<UserProfileProvider>().userProfile;
    final goals = profile?.healthGoals ?? const <String>[];
    final conditions = profile?.diseases ?? const <String>[];
    final remaining = sub.remainingGlucoCoachChats;
    final quotaLabel = sub.glucoCoachQuotaLabel;
    final chatLimit = sub.maxGlucoCoachChats;

    return Scaffold(
      backgroundColor: const Color(0xFF022C22),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sub.canSendGlucoCoachMessage
            ? () => _openCoach(context)
            : () => _showUpgrade(context),
        backgroundColor: const Color(0xFF0F172A),
        icon: Icon(
          sub.canSendGlucoCoachMessage
              ? Icons.chat_bubble_rounded
              : Icons.lock_rounded,
          color: Colors.greenAccent,
        ),
        label: Text(
          sub.canSendGlucoCoachMessage
              ? 'ASK GLUCO-COACH'
              : 'UPGRADE FOR MORE',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Colors.greenAccent,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Icon(
                    Icons.monitor_heart_rounded,
                    size: 56,
                    color: Colors.greenAccent.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Glucose',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chat with Gluco Coach about your health goals and conditions. '
                    'Premium unlocks live CGM sync, metabolic lens, and predictive insights.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _CoachQuotaCard(
                    isFree: sub.isFree,
                    remaining: remaining,
                    limit: chatLimit,
                    quotaLabel: quotaLabel,
                  ),
                  const SizedBox(height: 16),
                  _ProfileContextCard(goals: goals, conditions: conditions),
                  const SizedBox(height: 16),
                  _LockedFeaturesCard(onUpgrade: () => _showUpgrade(context)),
                  const SizedBox(height: 24),
                  if (sub.canSendGlucoCoachMessage)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openCoach(context),
                        icon: const Icon(Icons.psychology_rounded),
                        label: const Text('Start Gluco Coach chat'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade400,
                          foregroundColor: const Color(0xFF022C22),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCoach(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const GlucoCoachChatScreen()),
    );
  }

  void _showUpgrade(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
    );
  }
}

class _CoachQuotaCard extends StatelessWidget {
  final bool isFree;
  final int remaining;
  final int limit;
  final String quotaLabel;

  const _CoachQuotaCard({
    required this.isFree,
    required this.remaining,
    required this.limit,
    required this.quotaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = limit < 0
        ? 'Unlimited Gluco Coach (Claude Sonnet)'
        : isFree
            ? (limit == 1
                ? '$quotaLabel Gluco Coach chat (Claude Sonnet)'
                : '$quotaLabel Gluco Coach chats (Claude Sonnet)')
            : '$quotaLabel Gluco Coach chats today';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.greenAccent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gluco Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
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
}

class _ProfileContextCard extends StatelessWidget {
  final List<String> goals;
  final List<String> conditions;

  const _ProfileContextCard({
    required this.goals,
    required this.conditions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your coaching context',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          _contextRow(
            'Health goals',
            goals.isEmpty ? 'Add goals in your profile' : goals.join(', '),
            Icons.flag_rounded,
          ),
          const SizedBox(height: 10),
          _contextRow(
            'Conditions',
            conditions.isEmpty ? 'Add conditions in your profile' : conditions.join(', '),
            Icons.health_and_safety_rounded,
          ),
          if (goals.isEmpty && conditions.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Update your health profile so Gluco Coach can personalize advice.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade200,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contextRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LockedFeaturesCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _LockedFeaturesCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF312E81).withValues(alpha: 0.55),
            const Color(0xFF0F172A).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium Glucose Nexus',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Live CGM sync, metabolic lens, predictive insights, and unlimited coaching.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onUpgrade,
            child: const Text(
              'View Premium plans',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
