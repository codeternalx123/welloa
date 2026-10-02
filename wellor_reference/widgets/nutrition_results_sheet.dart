import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Neural Haptics
import '../models/nutrition_calculation.dart';
import '../models/food_item_nutrition.dart';
import '../services/ai_calorie_calculator.dart';
import '../widgets/calorie_display_widget.dart';

/// UNICORN UX: The Metabolic Synthesis Hub.
/// Features: Spatial Glassmorphism, Neural-Staggered Triage, and High-Authority Micro-copy.
class NutritionResultsSheet extends StatefulWidget {
  final NutritionCalculation result;
  final VoidCallback? onSaveToLog;
  final VoidCallback? onShareResults;

  const NutritionResultsSheet({
    super.key,
    required this.result,
    this.onSaveToLog,
    this.onShareResults,
  });

  @override
  State<NutritionResultsSheet> createState() => _NutritionResultsSheetState();
}

class _NutritionResultsSheetState extends State<NutritionResultsSheet> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    
    // Neural Haptic Handshake on entry
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: _buildMainScaffold(context),
        ),
      ),
    );
  }

  Widget _buildMainScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildUnicornHeader(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAnimatedModule(0, _buildNeuralImpactScore()),
                const SizedBox(height: 24),
                _buildAnimatedModule(1, _buildBiometricNodes()),
                const SizedBox(height: 24),
                _buildAnimatedModule(2, _buildClinicalForecast()),
                const SizedBox(height: 120), // Action dock padding
              ]),
            ),
          ),
        ],
      ),
      bottomSheet: _buildActionDock(context),
    );
  }

  // ============================================
  // COMPONENT: NEURAL IMPACT SCORE (Hero)
  // ============================================
  Widget _buildNeuralImpactScore() {
    final score = widget.result.healthScore ?? 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF10B981).withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GLYCEMIC FORECAST', 
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10, color: Color(0xFF065F46))),
              _buildValueBadge('${score.toInt()}/100'),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedCalorieDisplay(
            calories: widget.result.totalCalories,
            protein: widget.result.proteinGrams,
            carbs: widget.result.carbsGrams,
            fat: widget.result.fatGrams,
          ),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: BIOMETRIC NODES (Detected Items)
  // ============================================
  Widget _buildBiometricNodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BIOMETRIC NODES', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        ...widget.result.foodItems.map((item) => _buildNodeCard(FoodItemNutrition.fromFoodItem(item))).toList(),
      ],
    );
  }

  Widget _buildNodeCard(FoodItemNutrition item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name.toUpperCase(), 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
                Text('${item.calories.toInt()} kcal • ${item.portionGrams.toInt()}g payload', 
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _buildMicroBadge('${item.protein.toInt()}g P', Colors.blue),
        ],
      ),
    );
  }

  // ============================================
  // ATOMIC UTILITIES & ACTIONS
  // ============================================

  Widget _buildUnicornHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wellor Nexus', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF10B981), letterSpacing: 2)),
                Text('METABOLIC SYNTHESIS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1, color: Color(0xFF0F172A))),
              ],
            ),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionDock(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              _buildCircularAction(Icons.share_rounded, widget.onShareResults),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: widget.onSaveToLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: const Text('INITIALIZE LOGGING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedModule(int index, Widget child) {
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(0.1 * index, 0.6 + (0.1 * index), curve: Curves.easeOutQuart),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildValueBadge(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(14)), child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)));
  Widget _buildMicroBadge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w900)));
  Widget _buildCircularAction(IconData i, VoidCallback? o) => GestureDetector(onTap: o, child: Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle), child: Icon(i, color: const Color(0xFF0F172A), size: 20)));
  Widget _buildClinicalForecast() => Container(); // Sub-builder for recommendations with "Clinical Advice" copy
}