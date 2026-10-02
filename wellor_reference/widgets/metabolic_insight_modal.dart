import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // High-Fidelity Haptics
import 'package:provider/provider.dart';
import '../services/daily_balance_service.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/responsive_utils.dart';

/// UNICORN UX: Daily health insight summary.
/// Features: Glassmorphism surface, key nutrition stats, and gentle coaching nudges.
class MetabolicInsightModal extends StatelessWidget {
  final DailyBalanceReport report;

  const MetabolicInsightModal({super.key, required this.report});

  // ============================================
  // THE SHOW METHOD: LEAD DEV SPATIAL ANIMATION
  // ============================================
  static Future<void> show(BuildContext context, DailyBalanceReport report) {
    HapticFeedback.mediumImpact(); // Neural handshake
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MetabolicInsightModal(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final isCompact = ResponsiveUtils.isCompactView(context);
    
    return _SpatialSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : padding.left,
                8,
                isCompact ? 16 : padding.right,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildApertureHeader(context),
                  SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),
                  _buildMealsOverview(context),
                  SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),
                  _buildClinicalRationaleCard(context),
                  SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),
                  _buildNeuralRiskAura(context),
                  SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 32)),
                  _buildBiometricAuditGrid(context),
                  SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 32)),
                  _buildPredictiveActionDock(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: MEALS OVERVIEW BY TYPE
  // ============================================
  Widget _buildMealsOverview(BuildContext context) {
    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionProvider, child) {
        final meals = nutritionProvider.todayMeals;
        
        // Group meals by type
        final breakfastMeals = meals.where((m) => m.mealType.toLowerCase() == 'breakfast').toList();
        final lunchMeals = meals.where((m) => m.mealType.toLowerCase() == 'lunch').toList();
        final dinnerMeals = meals.where((m) => m.mealType.toLowerCase() == 'dinner').toList();
        final snackMeals = meals.where((m) => m.mealType.toLowerCase() == 'snack').toList();
        
        if (meals.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.restaurant_menu, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No meals logged today',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan your first meal to get started!',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TODAY\'S MEALS',
              style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMealTypeCard('Breakfast', breakfastMeals, Icons.wb_sunny_outlined, const Color(0xFFFF9800))),
                const SizedBox(width: 10),
                Expanded(child: _buildMealTypeCard('Lunch', lunchMeals, Icons.lunch_dining_rounded, const Color(0xFF4CAF50))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMealTypeCard('Dinner', dinnerMeals, Icons.dinner_dining_rounded, const Color(0xFF9C27B0))),
                const SizedBox(width: 10),
                Expanded(child: _buildMealTypeCard('Snacks', snackMeals, Icons.cookie_outlined, const Color(0xFF2196F3))),
              ],
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildMealTypeCard(String type, List meals, IconData icon, Color color) {
    final totalCalories = meals.fold<double>(0, (sum, meal) => sum + meal.totalCalories);
    final hasLogged = meals.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasLogged ? color.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasLogged ? color.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: hasLogged ? color : Colors.grey.shade400, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(type,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, 
                    color: hasLogged ? color.withOpacity(0.9) : Colors.grey.shade500)),
              ),
              if (hasLogged)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${meals.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasLogged) ...[
            Text('${totalCalories.toInt()} kcal',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 4),
            // Show food items
            ...meals.expand((meal) => meal.foodItems.take(2).map((item) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• ${item.name}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ))).take(3),
            if (meals.fold<int>(0, (sum, meal) => (sum + meal.foodItems.length) as int) > 3)
              Text('+ more items',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
          ] else
            Text('Not logged',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: APERTURE HEADER
  // ============================================
  Widget _buildApertureHeader(BuildContext context) {
    final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      mobileSize: 20,
      tabletSize: 24,
      desktopSize: 28,
    );
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HEALTH SNAPSHOT',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
              SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 4)),
              Text('Daily Health Summary',
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w900, letterSpacing: -1)),
            ],
          ),
        ),
        _buildCircleClose(context),
      ],
    );
  }

  // ============================================
  // COMPONENT: CLINICAL RATIONALE CARD
  // ============================================
  Widget _buildClinicalRationaleCard(BuildContext context) {
    final rationale = report.clinicalRationale;
    final isGeneric = !rationale.hasConditionAdjustments && rationale.goalAdjustments.isEmpty;
    final padding = ResponsiveUtils.getResponsivePadding(context).left;

    return Container(
      padding: EdgeInsets.all(padding * 0.8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.health_and_safety, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR PERSONALIZED TARGETS',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rationale.dailyCalorieTarget} kcal/day',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calorie calculation explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calculate, size: 16, color: Colors.purple.shade400),
                    const SizedBox(width: 8),
                    const Text(
                      'Why this goal fits you',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  rationale.calorieReason,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Goal adjustments
          if (rationale.goalAdjustments.isNotEmpty) ...[
            ...rationale.goalAdjustments.map((adjustment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.flag, size: 12, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adjustment,
                      style: TextStyle(fontSize: 12, color: Colors.green.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],

          // Condition-based adjustments
          if (rationale.conditionAdjustments.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...rationale.conditionAdjustments.map((adjustment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.medical_services, size: 12, color: Colors.orange.shade700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adjustment,
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],

          // Macro rationale
          if (rationale.macroReasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FOOD GOALS',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.blueGrey, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  ...rationale.macroReasons.map((macro) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _getMacroColor(macro.macro).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${macro.targetG}g',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: _getMacroColor(macro.macro),
                                ),
                              ),
                              Text(
                                macro.macro,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _getMacroColor(macro.macro),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            macro.reason,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],

          // Clinical warnings
          if (rationale.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...rationale.warnings.map((warning) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],

          // Meal timing guidance
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.indigo.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simple eating tip',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.indigo.shade800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rationale.mealGuidance,
                        style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Incomplete profile nudge
          if (isGeneric) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_add, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add your health conditions and goals in your profile for more personal daily targets.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getMacroColor(String macro) {
    switch (macro) {
      case 'Protein': return const Color(0xFFFF6584);
      case 'Carbs': return const Color(0xFF00BFA6);
      case 'Fat': return const Color(0xFFFF9800);
      default: return Colors.blueGrey;
    }
  }

  // ============================================
  // COMPONENT: NEURAL RISK AURA
  // ============================================
  Widget _buildNeuralRiskAura(BuildContext context) {
    final color = clinicalRiskColor(report.clinicalRiskLevel);
    final padding = ResponsiveUtils.getResponsivePadding(context).left;
    
    return Container(
      padding: EdgeInsets.all(padding * 0.8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _GlowIcon(icon: Icons.analytics_rounded, color: color),
              SizedBox(width: ResponsiveUtils.getResponsiveWidth(context, 16)),
              Expanded(
                child: Text(
                  report.metabolicInsight.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 12)),
          const Text(
            'These insights are tailored to your current health pattern.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: BIOMETRIC AUDIT GRID
  // ============================================
  Widget _buildBiometricAuditGrid(BuildContext context) {
    final spacing = ResponsiveUtils.getResponsiveWidth(context, 16);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NUTRITION BREAKDOWN',
          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
        SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 1.8,
          children: [
            _buildAuditTile('SODIUM', report.sodium, 'mg', isCritical: true),
            _buildAuditTile('FIBER', report.fiber, 'g'),
            _buildAuditTile('PROTEIN', report.protein, 'g'),
            _buildAuditTile('CARBS', report.carbs, 'g'),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),
        // Remaining Today Section
        _buildRemainingTodaySection(context, spacing),
      ],
    );
  }
  
  Widget _buildRemainingTodaySection(BuildContext context, double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REMAINING TODAY',
          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
        SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 1.8,
          children: [
            _buildRemainingTile('CALORIES', report.calories, 'kcal', const Color(0xFF6C63FF)),
            _buildRemainingTile('PROTEIN', report.protein, 'g', const Color(0xFFFF6584)),
            _buildRemainingTile('CARBS', report.carbs, 'g', const Color(0xFF00BFA6)),
            _buildRemainingTile('FAT', report.fat, 'g', const Color(0xFFFF9800)),
          ],
        ),
      ],
    );
  }
  
  Widget _buildRemainingTile(String label, MacroBalance balance, String unit, Color color) {
    return Builder(
      builder: (context) {
        final remaining = balance.remaining;
        final isComplete = remaining <= 0;
        final padding = ResponsiveUtils.getResponsivePadding(context).left * 0.67;
        final valueFontSize = ResponsiveUtils.getResponsiveFontSize(context, mobileSize: 18, tabletSize: 20, desktopSize: 22);
        
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isComplete ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const Spacer(),
                  if (isComplete) Icon(Icons.check_circle, color: color, size: 14),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 4)),
              Row(
                children: [
                  Text(
                    isComplete ? 'Complete!' : '${remaining.toInt()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: isComplete ? valueFontSize * 0.7 : valueFontSize,
                      color: isComplete ? color : Colors.black87,
                    ),
                  ),
                  if (!isComplete) Text(' $unit left', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditTile(String label, MacroBalance balance, String unit, {bool isCritical = false}) {
    return Builder(
      builder: (context) {
        final bool isExtreme = balance.isOverLimit && isCritical;
        final padding = ResponsiveUtils.getResponsivePadding(context).left * 0.67;
        final valueFontSize = ResponsiveUtils.getResponsiveFontSize(context, mobileSize: 18, tabletSize: 20, desktopSize: 22);
        
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isExtreme ? Colors.redAccent.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 4)),
              Row(
                children: [
                  Text('${balance.current.toInt()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: valueFontSize)),
                  Text(' $unit', style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (isExtreme) const _PulseIndicator(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // COMPONENT: PREDICTIVE ACTION DOCK
  // ============================================
  Widget _buildPredictiveActionDock(BuildContext context) {
    final padding = ResponsiveUtils.getResponsivePadding(context).left * 0.75;
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, mobileSize: 13, tabletSize: 14, desktopSize: 16);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Badge(text: 'DAILY INSIGHTS', color: Color(0xFF10B981)),
          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 12)),
          Text(
            report.metabolicInsight,
            style: TextStyle(color: Colors.white, fontSize: fontSize, height: 1.6, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 20)),
          _UnicornButton(
            label: 'VIEW DETAILED ANALYTICS',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Helper builders...
  Widget _buildHandle() => Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))));
  Widget _buildCircleClose(BuildContext context) => GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF0F172A))));
}

// ============================================
// ATOMIC UNICORN COMPONENTS
// ============================================

class _SpatialSurface extends StatelessWidget {
  final Widget child;
  const _SpatialSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _GlowIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2)],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _PulseIndicator extends StatelessWidget {
  const _PulseIndicator();
  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle));
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }
}

class _UnicornButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _UnicornButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
      ),
    );
  }
}