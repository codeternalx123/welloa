import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// Providers & Models
import '../providers/subscription_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../config/app_theme.dart';

// Unicorn Core Services
import '../services/daily_balance_service.dart';
import '../services/offline_service.dart';

// High-Fidelity Widgets
import '../widgets/metabolic_daily_rings.dart';
import '../widgets/metabolic_insight_modal.dart';
import '../widgets/feature_restriction_widgets.dart';

// Responsive Design
import '../utils/responsive_utils.dart';
import '../widgets/health_disclaimer_widget.dart';

// Screens for Navigation
// Channels and Communities screens disabled - Coming Soon
// import 'channels_screen.dart';
// import 'communities_screen.dart';
import 'health_agent_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToScan;
  final VoidCallback? onNavigateToPlanner;

  const HomeScreen({super.key, this.onNavigateToScan, this.onNavigateToPlanner});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  final _balanceService = DailyBalanceService();
  final _offlineService = OfflineService();
  bool _isOnline = true;
  int _pendingMealsCount = 0;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    
    _initializeOffline();
    
    // Listen for subscription errors after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSubscriptionStatus();
    });
  }
  
  void _checkSubscriptionStatus() {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    // Only show subscribe prompt for expired paid subscriptions, not for free tier users
    if (subscriptionProvider.shouldShowSubscribePrompt && !subscriptionProvider.isFree) {
      FeatureRestrictionDialog.showSubscriptionPrompt(context);
      subscriptionProvider.clearError();
    } else if (subscriptionProvider.shouldShowSubscribePrompt) {
      // Free tier users should just have the error cleared silently
      subscriptionProvider.clearError();
    }
  }
  
  Future<void> _initializeOffline() async {
    await _offlineService.initialize();
    _isOnline = _offlineService.isOnline;
    _pendingMealsCount = await _offlineService.getPendingMealsCount();
    
    _connectivitySubscription = _offlineService.connectivityStream.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) _checkPendingMeals();
      }
    });
    
    if (mounted) setState(() {});
  }
  
  Future<void> _checkPendingMeals() async {
    final count = await _offlineService.getPendingMealsCount();
    if (mounted) setState(() => _pendingMealsCount = count);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  Widget _buildOfflineBanner() {
    return OfflineStatusBanner(
      isOnline: _isOnline,
      pendingCount: _pendingMealsCount,
      onSyncTap: () async {
        await _offlineService.syncPendingData();
        await _checkPendingMeals();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Consumer3<UserProfileProvider, NutritionGoalsProvider, SubscriptionProvider>(
          builder: (context, profile, nutrition, subscription, child) {
            // Debug: Log tracker state
            debugPrint('🏠 HomeScreen rebuild - Tracker: ${nutrition.todayTracker?.totalCalories ?? 'null'} cal, Meals: ${nutrition.todayMeals.length}');
            
            final reportFuture = _balanceService.computeFromProviders(
              nutritionGoalsProvider: nutrition,
              profile: profile,
              useAiReasoning: subscription.hasHybridMealIntelligence,
            );

            // Use a key based on tracker data to force FutureBuilder to rebuild
            final trackerKey = '${nutrition.todayTracker?.totalCalories ?? 0}_${nutrition.todayTracker?.mealsLogged ?? 0}_${nutrition.todayMeals.length}';
            debugPrint('🏠 HomeScreen trackerKey: $trackerKey');

            return FutureBuilder<DailyBalanceReport>(
              key: ValueKey(trackerKey),
              future: reportFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading your health data', style: AppTextStyles.bodySmall));
                }

                // Use data if available, otherwise show zero-state immediately (no spinner)
                final report = snapshot.data ?? DailyBalanceReport.empty();
                final hasNoData = !snapshot.hasData || 
                    (report.calories.current == 0 && report.protein.current == 0);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildUnicornAppBar(profile),
                    // Offline Banner
                    if (!_isOnline || _pendingMealsCount > 0)
                      SliverToBoxAdapter(
                        child: _buildOfflineBanner(),
                      ),
                    SliverToBoxAdapter(
                      child: ResponsivePadding(
                        left: ResponsiveUtils.isCompactView(context) ? 16 : 20,
                        right: ResponsiveUtils.isCompactView(context) ? 16 : 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            _buildMetabolicHero(report),
                            if (hasNoData) ...[
                              SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),
                              _buildScanToUpdateCard(),
                            ],
                            SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),
                            _buildQuickActionsGrid(context),
                            SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),
                            _buildPremiumGuard(context),
                            SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),
                            const HealthDisclaimerBanner(),
                            SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 40)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================
  // UNICORN COMPONENT: METABOLIC HERO
  // ============================================
  Widget _buildMetabolicHero(DailyBalanceReport report) {
    return Builder(
      builder: (context) {
        final containerPadding = ResponsiveUtils.getResponsivePadding(context);
        final isCompact = ResponsiveUtils.isCompactView(context);
        final spacing = ResponsiveUtils.getResponsiveHeight(context, 20);

        return GestureDetector(
          onTap: () => MetabolicInsightModal.show(context, report),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.45),
                  AppColors.primary.withValues(alpha: 0.35),
                  const Color(0xFF10B981).withValues(alpha: 0.4),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                  spreadRadius: -6,
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.5),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : containerPadding.left * 0.75,
                vertical: isCompact ? 20 : 28,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF312E81), Color(0xFF10B981)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF312E81).withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.hub_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Neural link',
                              style: AppTextStyles.h3.copyWith(
                                fontSize: isCompact ? 20 : 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rings sync calories, carbs, and protein to your targets. Tap for the full brief.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing * 0.65),
                  Center(child: MetabolicDailyRings(report: report)),
                  SizedBox(height: spacing),
                  // Remaining nutrients summary
                  _buildRemainingNutrientsSummary(report),
                  SizedBox(height: spacing),
                  Text(
                    report.metabolicInsight,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: spacing),
                  // Wellness Action Pill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveWidth(context, 20),
                      vertical: ResponsiveUtils.getResponsiveHeight(context, 12),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - (isCompact ? 48 : 80),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'VIEW DAILY HEALTH INSIGHTS',
                              style: AppTextStyles.caption.copyWith(
                                letterSpacing: 1.1,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveWidth(context, 8)),
                          const Icon(Icons.monitor_heart_outlined, size: 16, color: AppColors.primaryDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // COMPONENT: REMAINING NUTRIENTS SUMMARY
  // ============================================
  Widget _buildRemainingNutrientsSummary(DailyBalanceReport report) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            'REMAINING TODAY',
            style: AppTextStyles.label.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRemainingItem(
                'Calories',
                report.calories.remaining.toInt(),
                'kcal',
                report.calories.isOverLimit ? Colors.red : AppColors.primary,
              ),
              _buildRemainingItem(
                'Protein',
                report.protein.remaining.toInt(),
                'g',
                report.protein.isOverLimit ? Colors.red : const Color(0xFF9C27B0),
              ),
              _buildRemainingItem(
                'Carbs',
                report.carbs.remaining.toInt(),
                'g',
                report.carbs.isOverLimit ? Colors.red : const Color(0xFF2196F3),
              ),
              _buildRemainingItem(
                'Fat',
                report.fat.remaining.toInt(),
                'g',
                report.fat.isOverLimit ? Colors.red : const Color(0xFFFF9800),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRemainingItem(String label, int value, String unit, Color color) {
    final isNegative = value < 0;
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isNegative ? '+${value.abs()}' : '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isNegative ? Colors.red : color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isNegative ? Colors.red.withOpacity(0.7) : color.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
        if (isNegative)
          Text(
            'over',
            style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  // ============================================
  // COMPONENT: SCAN TO UPDATE PROMPT
  // ============================================
  Widget _buildScanToUpdateCard() {
    return GestureDetector(
      onTap: () => widget.onNavigateToScan?.call(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.primary.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan to update today\'s values',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Take a photo of your meal to start tracking',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  // ============================================
  // UNICORN COMPONENT: APP BAR
  // ============================================
  Widget _buildUnicornAppBar(UserProfileProvider profile) {
    final subscription = context.watch<SubscriptionProvider>();
    final isFree = subscription.isFree;
    final tierLabel = isFree ? 'FREEMIUM' : (subscription.isPremium ? 'PREMIUM' : 'FREE');
    final tierColor = isFree ? const Color(0xFF64748B) : const Color(0xFF10B981);

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      floating: true,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.bolt, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text('Wellor', style: AppTextStyles.h3.copyWith(color: AppColors.primaryDark)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tierColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                tierLabel,
                style: TextStyle(
                  color: tierColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.account_circle_outlined, color: profile.userProfile != null ? AppColors.primary : Colors.grey),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
      ],
    );
  }

  // ============================================
  // UNICORN COMPONENT: QUICK ACTIONS GRID
  // ============================================
  Widget _buildQuickActionsGrid(BuildContext context) {
    final isMobile = ResponsiveUtils.isCompactView(context);
    final spacing = isMobile ? 12.0 : 16.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('QUICK ACTIONS', style: AppTextStyles.label.copyWith(letterSpacing: 1.2)),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),
        // Primary Action Row - Responsive
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan Meal',
                color: const Color(0xFF6C63FF), // Unicorn Purple
                onTap: () {
                   HapticFeedback.selectionClick();
                   widget.onNavigateToScan?.call();
                },
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.restaurant_menu_rounded,
                label: 'Plan Meals',
                color: const Color(0xFFFF6584), // Coral Pink
                onTap: () {
                   HapticFeedback.selectionClick();
                   widget.onNavigateToPlanner?.call();
                },
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        // Health Agent Row
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.smart_toy_rounded,
                label: 'Health Agent',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthAgentScreen()));
                },
              ),
            ),
            SizedBox(width: spacing),
            const Expanded(child: SizedBox()),
          ],
        ),
        SizedBox(height: spacing),
        // Social & Content Row - DISABLED (Coming Soon)
        /*Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.group_work_rounded,
                label: 'Communities',
                color: const Color(0xFF00BFA6), // Teal
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunitiesScreen()));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.play_circle_fill_rounded,
                label: 'Channels',
                color: const Color(0xFFFFA502), // Amber
                onTap: () {
                  HapticFeedback.selectionClick();
                  // TODO: ChannelsScreen requires missing dependencies (channels_provider, channel models)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Channels feature coming soon!')),
                  );
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => const ChannelsScreen()));
                },
              ),
            ),
          ],
        ),*/
      ],
    );
  }

  // ============================================
  // UNICORN COMPONENT: PREMIUM GUARD
  // ============================================
  Widget _buildPremiumGuard(BuildContext context) {
    final subscription = context.watch<SubscriptionProvider>();
    if (subscription.isPremium) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unlock Premium', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Get unlimited scans & AI insights', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/subscription'),
            child: const Text('UPGRADE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                label, 
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w800, 
                  color: color
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offline Status Banner Widget
class OfflineStatusBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final VoidCallback? onSyncTap;

  const OfflineStatusBanner({
    super.key,
    required this.isOnline,
    required this.pendingCount,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOnline ? Colors.orange.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.orange.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
            color: isOnline ? Colors.orange : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOnline ? 'Sync Pending' : 'Offline Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isOnline ? Colors.orange.shade900 : Colors.red.shade900,
                  ),
                ),
                if (pendingCount > 0)
                  Text(
                    '$pendingCount meal${pendingCount > 1 ? 's' : ''} waiting to sync',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOnline ? Colors.orange.shade700 : Colors.red.shade700,
                    ),
                  ),
                if (!isOnline)
                  Text(
                    'Your data will sync when you\'re back online',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          if (isOnline && pendingCount > 0 && onSyncTap != null)
            TextButton(
              onPressed: onSyncTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'SYNC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Profile onboarding nudge widget
class ProfileOnboardingNudge extends StatelessWidget {
  const ProfileOnboardingNudge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.amber, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Complete Your Profile', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                Text('Get personalized AI recommendations', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            child: const Text('SET UP'),
          ),
        ],
      ),
    );
  }
}
