import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import '../models/nutrition_calculation.dart';
import '../services/ai_calorie_calculator.dart';

/// UNICORN UX: The Biometric Repository Nexus.
/// Features: Spatial Glassmorphism, Neural-Staggered Triage, and Kinetic Quantity Adjustment.
class FoodSearchDialog extends StatefulWidget {
  final Function(NutritionCalculation) onFoodSelected;

  const FoodSearchDialog({
    super.key,
    required this.onFoodSelected,
  });

  @override
  State<FoodSearchDialog> createState() => _FoodSearchDialogState();

  static Future<NutritionCalculation?> show(BuildContext context) async {
    HapticFeedback.mediumImpact(); // Neural Handshake
    return showModalBottomSheet<NutritionCalculation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodSearchDialog(
        onFoodSelected: (result) => Navigator.of(context).pop(result),
      ),
    );
  }
}

class _FoodSearchDialogState extends State<FoodSearchDialog> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _staggerController;
  
  List<Map<String, dynamic>> _filteredFoods = [];
  List<Map<String, dynamic>> _allFoods = [];
  Map<String, dynamic>? _selectedFood;
  int _quantity = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    final foods = await AICalorieCalculator.getAvailableFoods();
    if (mounted) {
      setState(() {
        _allFoods = foods;
        _filteredFoods = foods.take(20).toList();
        _isLoading = false;
      });
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterFoods(String query) {
    HapticFeedback.lightImpact(); // Micro-feedback for typing
    setState(() {
      _selectedFood = null; // Clear selection on new search
      if (query.isEmpty) {
        _filteredFoods = _allFoods.take(20).toList();
      } else {
        _filteredFoods = _allFoods
            .where((food) => (food['name'] as String? ?? '').toLowerCase().contains(query.toLowerCase()))
            .take(30)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              _buildHandle(),
              _buildHighAuthorityHeader(),
              _buildSearchAperture(),
              
              // 1. NEURAL PREVIEW AREA
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
                child: _selectedFood != null 
                    ? _buildSynthesisCard() 
                    : const SizedBox.shrink(),
              ),

              // 2. STAGGERED LIST AREA
              Expanded(
                child: _filteredFoods.isEmpty 
                    ? _buildEmptyState() 
                    : _buildKineticList(),
              ),

              // 3. ACTION DOCK
              if (_selectedFood != null) _buildActionDock(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================

  Widget _buildHighAuthorityHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BIOMETRIC REPOSITORY', 
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
              SizedBox(height: 4),
              Text('Manual Node Entry', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1.2, color: Color(0xFF0F172A))),
            ],
          ),
          const Spacer(),
          _buildCircleClose(),
        ],
      ),
    );
  }

  Widget _buildSearchAperture() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterFoods,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Interrogate Clinical Database...',
            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF10B981)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildSynthesisCard() {
    if (_selectedFood == null) return const SizedBox.shrink();
    final data = _selectedFood!;
    final name = data['name'] as String? ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(_getFoodEmoji(name), style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                    const Text('SYNTHESIZING PAYLOAD...', 
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 2)),
                  ],
                ),
              ),
              _buildQuantitySelector(),
            ],
          ),
          const SizedBox(height: 20),
          _buildMacroTelemetry(data),
        ],
      ),
    );
  }

  Widget _buildMacroTelemetry(Map<String, dynamic> data) {
    final calories = (data['calories'] as num?)?.toDouble() ?? 0.0;
    final protein = (data['protein'] as num?)?.toDouble() ?? 0.0;
    final carbs = (data['carbs'] as num?)?.toDouble() ?? 0.0;
    final fat = (data['fat'] as num?)?.toDouble() ?? 0.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTeleChip('🔥', '${(calories * _quantity).toInt()}', 'KCAL'),
        _buildTeleChip('💪', '${(protein * _quantity).toStringAsFixed(1)}', 'PRO'),
        _buildTeleChip('🌾', '${(carbs * _quantity).toStringAsFixed(1)}', 'CARB'),
        _buildTeleChip('🧈', '${(fat * _quantity).toStringAsFixed(1)}', 'FAT'),
      ],
    );
  }

  Widget _buildKineticList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: _filteredFoods.length,
      itemBuilder: (context, index) {
        final food = _filteredFoods[index];
        final isSelected = _selectedFood != null && food['name'] == _selectedFood!['name'];
        final foodName = food['name'] as String? ?? 'Unknown';

        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final double animValue = Curves.easeOutQuart.transform(
              (_staggerController.value - (index * 0.04)).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: animValue,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - animValue)),
                child: child,
              ),
            );
          },
          child: _buildFoodNode(food, foodName, isSelected),
        );
      },
    );
  }

  Widget _buildFoodNode(Map<String, dynamic> food, String foodName, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFood = food;
          _quantity = 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(_getFoodEmoji(foodName), style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                foodName.toUpperCase(),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  color: isSelected ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                ),
              ),
            ),
            Icon(isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, 
              color: isSelected ? const Color(0xFF10B981) : Colors.black12),
          ],
        ),
      ),
    );
  }

  // ============================================
  // ATOMIC UTILITIES
  // ============================================

  Widget _buildActionDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: _selectedFood == null ? null : () async {
            HapticFeedback.heavyImpact();
            // Adjust values by quantity
            final adjustedData = Map<String, dynamic>.from(_selectedFood!);
            adjustedData['calories'] = ((adjustedData['calories'] as num?) ?? 0) * _quantity;
            adjustedData['protein'] = ((adjustedData['protein'] as num?) ?? 0) * _quantity;
            adjustedData['carbs'] = ((adjustedData['carbs'] as num?) ?? 0) * _quantity;
            adjustedData['fat'] = ((adjustedData['fat'] as num?) ?? 0) * _quantity;
            final result = await AICalorieCalculator.createFromUSDA(adjustedData);
            widget.onFoodSelected(result);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: const Text('INITIALIZE LOGGING', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        _buildQtyBtn(Icons.remove_rounded, () => setState(() => _quantity = math.max(1, _quantity - 1))),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text('$_quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        _buildQtyBtn(Icons.add_rounded, () => setState(() => _quantity++)),
      ],
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: const Color(0xFF10B981), size: 20),
    ),
  );

  Widget _buildTeleChip(String em, String val, String lab) => Column(
    children: [
      Text(em, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
      Text(lab, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1)),
    ],
  );

  Widget _buildHandle() => Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))));
  Widget _buildCircleClose() => GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 20)));
  Widget _buildEmptyState() => const Center(child: Text('NO NODES DETECTED', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)));

  String _getFoodEmoji(String food) {
    final lower = food.toLowerCase();
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('chicken')) return '🍗';
    if (lower.contains('rice')) return '🍚';
    if (lower.contains('bread')) return '🍞';
    return '🍽️';
  }
}