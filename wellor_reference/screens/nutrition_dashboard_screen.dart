import 'dart:ui';
import 'package:flutter/material.dart';
// For High-Fidelity Haptics
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/nutrition_goals_provider.dart';
import '../main.dart';

/// UNICORN UX: The Metabolic Intelligence Dashboard.
/// Features: Real-time Firestore Sync, Glassmorphic 3D Progress Rings, 
/// and Neural Bio-Score Algorithm.
class NutritionDashboardScreen extends StatefulWidget {
  const NutritionDashboardScreen({super.key});

  @override
  State<NutritionDashboardScreen> createState() => _NutritionDashboardScreenState();
}

class _NutritionDashboardScreenState extends State<NutritionDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _staggerController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<NutritionGoalsProvider>();
    await provider.loadUserGoals();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. BIOLOGICAL MESH BACKGROUND
          _buildMetabolicBackground(),

          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildUnicornSliverHeader(),
              ],
              body: Column(
                children: [
                  _buildUnicornTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTodayTab(),
                        _buildRealTimeScannedTab(),
                        _buildHistoryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================

  Widget _buildMetabolicBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF022C22), Color(0xFF000000)],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.black.withValues(alpha: 0.2)),
      ),
    );
  }

  Widget _buildUnicornSliverHeader() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('BIO-SCORE', 
                style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 8),
              _buildLargeBioRing(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeBioRing() {
    // Lead UX Move: A 3D-feeling pulsing ring that aggregates overall alignment
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return FutureBuilder<DocumentSnapshot>(
      future: _db.collection('daily_nutrition').doc(uid).collection('days').doc(_getTodayDateKey()).get(),
      builder: (context, snapshot) {
        // Show zero-state immediately instead of a spinner
        final dayData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final bioScore = _calculateBioScore(dayData);
        final hasData = snapshot.hasData && dayData.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 10)
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: bioScore / 100,
                    strokeWidth: 10,
                    color: Colors.greenAccent,
                    backgroundColor: Colors.white10,
                  ),
                  Text('${bioScore.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            if (!hasData) ...[
              const SizedBox(height: 8),
              Text(
                'Scan a meal to get your score',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        );
      },
    );
  }

  double _calculateBioScore(Map<String, dynamic> dayData) {
    // Bio-score based on meeting nutritional targets
    final totalCalories = (dayData['totalCalories'] ?? 0).toDouble();
    final totalProtein = (dayData['totalProtein'] ?? 0).toDouble();
    final totalCarbs = (dayData['totalCarbs'] ?? 0).toDouble();
    final totalFat = (dayData['totalFat'] ?? 0).toDouble();

    if (totalCalories == 0) return 0;

    // Simple scoring: alignment to typical daily targets
    double score = 50; // Base score
    
    // Calorie alignment (2000-2500 is good)
    if (totalCalories >= 1800 && totalCalories <= 2800) score += 25;
    else if (totalCalories > 2800) score -= 10;
    
    // Protein adequacy (50-150g is good)
    if (totalProtein >= 50 && totalProtein <= 150) score += 15;
    
    // Carbs and Fat balance
    if (totalCarbs > 0 && totalFat > 0) score += 10;

    return score.clamp(0, 100);
  }

  String _getTodayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================
  // REAL-WORLD DATA: FIRESTORE SYNC
  // ============================================

  Widget _buildRealTimeScannedTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      return const Center(child: Text('Please log in to view meals', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('daily_nutrition')
          .doc(uid)
          .collection('days')
          .doc(_getTodayDateKey())
          .collection('meals')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood_rounded, size: 64, color: Colors.greenAccent.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('No meals scanned today', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
          );
        }

        final meals = snapshot.data!.docs;
        
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: meals.length,
          itemBuilder: (context, index) {
            final mealData = meals[index].data() as Map<String, dynamic>;
            return _buildGlassMealCard(mealData, index);
          },
        );
      },
    );
  }

  Widget _buildGlassMealCard(Map<String, dynamic> meal, int index) {
    // Lead Dev Logic: Staggered animation for list entry
    final animValue = Curves.easeOutQuart.transform(
      (_staggerController.value - (index * 0.1)).clamp(0.0, 1.0),
    );

    final totalCalories = (meal['totalCalories'] ?? 0).toStringAsFixed(0);
    final totalProtein = (meal['totalProtein'] ?? 0).toStringAsFixed(0);
    final totalCarbs = (meal['totalCarbs'] ?? 0).toStringAsFixed(0);
    final totalFat = (meal['totalFat'] ?? 0).toStringAsFixed(0);
    final mealType = meal['mealType'] ?? 'Meal';
    final foodItems = meal['foodItems'] as List<dynamic>? ?? [];

    // Grade based on macros
    String grade = _gradeFromMacros(
      double.parse(totalCalories),
      double.parse(totalProtein),
      double.parse(totalCarbs),
      double.parse(totalFat),
    );

    return Opacity(
      opacity: animValue,
      child: Transform.translate(
        offset: Offset(0, 50 * (1 - animValue)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mealType,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('${foodItems.length} item(s) • $totalCalories kcal',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                          ],
                        ),
                        _buildGradeBadge(grade),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroDisplay('Protein', totalProtein, 'g'),
                        _buildMacroDisplay('Carbs', totalCarbs, 'g'),
                        _buildMacroDisplay('Fat', totalFat, 'g'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroDisplay(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
        const SizedBox(height: 4),
        Text('$value$unit', style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }

  String _gradeFromMacros(double calories, double protein, double carbs, double fat) {
    if (calories == 0) return 'N/A';
    
    double score = 0;
    if (calories >= 1500 && calories <= 2500) score += 30;
    if (protein >= 25) score += 25;
    if (carbs >= 150 && carbs <= 300) score += 25;
    if (fat >= 40 && fat <= 80) score += 20;

    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B+';
    if (score >= 60) return 'B';
    if (score >= 50) return 'C';
    return 'D';
  }

  Widget _buildGradeBadge(String? grade) {
    final color = _getGradeColor(grade ?? 'C');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(grade ?? 'B', 
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }

  // ============================================
  // REMAINING UI LOGIC (PLACEHOLDERS)
  // ============================================

  Widget _buildUnicornTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(12)),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
        tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'REAL-TIME'), Tab(text: 'LOGS')],
      ),
    );
  }

  Widget _buildTodayTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      return const Center(child: Text('Please log in', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('daily_nutrition')
          .doc(uid)
          .collection('days')
          .doc(_getTodayDateKey())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          // Brief initial load — show zero-state instead of spinner
          return _buildTodayEmptyState();
        }

        final dayData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        
        if (dayData.isEmpty) {
          return _buildTodayEmptyState();
        }

        final totalCalories = (dayData['totalCalories'] ?? 0).toDouble();
        final totalProtein = (dayData['totalProtein'] ?? 0).toDouble();
        final totalCarbs = (dayData['totalCarbs'] ?? 0).toDouble();
        final totalFat = (dayData['totalFat'] ?? 0).toDouble();
        final totalFiber = (dayData['totalFiber'] ?? 0).toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calorie Ring
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (totalCalories / 2500).clamp(0, 1),
                        strokeWidth: 12,
                        color: Colors.blue,
                        backgroundColor: Colors.white10,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(totalCalories.toStringAsFixed(0), 
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                          const Text('kcal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Macro Cards Grid
              Text('MACRONUTRIENTS', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMacroCard('PROTEIN', totalProtein, 'g', Colors.pink),
                  _buildMacroCard('CARBS', totalCarbs, 'g', Colors.amber),
                  _buildMacroCard('FAT', totalFat, 'g', Colors.orange),
                  _buildMacroCard('FIBER', totalFiber, 'g', Colors.green),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroCard(String label, double value, String unit, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.toStringAsFixed(1),
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 4),
              Text(unit, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // EMPTY STATE WIDGETS: SCAN TO UPDATE
  // ============================================

  void _navigateToScanner() {
    // Navigate to scanner tab (index 1) via the MainScreen global key
    MainScreen.globalKey.currentState?.navigateToTab(1);
  }

  Widget _buildTodayEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withValues(alpha: 0.08),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.camera_alt_rounded, size: 48, color: Colors.greenAccent.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No meals logged today',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your food to update today\'s nutrition overview',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _navigateToScanner,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan a Meal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.greenAccent,
                side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withValues(alpha: 0.08),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.timeline_rounded, size: 40, color: Colors.greenAccent.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No history yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Start scanning meals to build your nutrition history',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _navigateToScanner,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Scan Your First Meal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.greenAccent,
                side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      return const Center(child: Text('Please log in', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('daily_nutrition')
          .doc(uid)
          .collection('days')
          .orderBy('date', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          // Show empty state immediately instead of spinner
          return _buildHistoryEmptyState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildHistoryEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final dayDoc = snapshot.data!.docs[index];
            final dayData = dayDoc.data() as Map<String, dynamic>;
            final date = dayData['date'] as Timestamp?;
            
            return _buildHistoryDayCard(dayData, date);
          },
        );
      },
    );
  }

  Widget _buildHistoryDayCard(Map<String, dynamic> dayData, Timestamp? date) {
    final dateStr = date != null 
        ? _formatDate(date.toDate())
        : 'Unknown';
    
    final totalCalories = (dayData['totalCalories'] ?? 0).toStringAsFixed(0);
    final totalProtein = (dayData['totalProtein'] ?? 0).toStringAsFixed(1);
    final totalCarbs = (dayData['totalCarbs'] ?? 0).toStringAsFixed(1);
    final totalFat = (dayData['totalFat'] ?? 0).toStringAsFixed(1);
    final totalFiber = (dayData['totalFiber'] ?? 0).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$totalCalories kcal',
                          style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    runAlignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildHistoryMacroLabel('P: $totalProtein', Colors.pink),
                      _buildHistoryMacroLabel('C: $totalCarbs', Colors.amber),
                      _buildHistoryMacroLabel('F: $totalFat', Colors.orange),
                      _buildHistoryMacroLabel('Fi: $totalFiber', Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryMacroLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
  }

  Color _getGradeColor(String grade) {
    if (grade.contains('A')) return const Color(0xFF34D399);
    if (grade.contains('B')) return const Color(0xFF60A5FA);
    if (grade.contains('C')) return const Color(0xFFFBBF24);
    return Colors.redAccent;
  }
}

class _MetabolicGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent.withValues(alpha: 0.05)..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}