import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../shared/widgets/gamified_ai_coach_widget.dart';
import '../../../../shared/widgets/unicorn_glass_card.dart';
import '../../../../shared/widgets/animated_glow_border.dart';
import '../../../../shared/widgets/mesh_background.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../coach/presentation/providers/coach_provider.dart';
import '../../../../shared/widgets/claude_thinking_indicator.dart';
import '../../../../core/providers/health_provider.dart';
import '../../../../core/providers/health_alerts_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../widgets/smartwatch_hub_modal.dart';
import '../widgets/upgrade_modal_bottom_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDisclaimer();
      final profile = ref.read(profileProvider);
      ref.read(coachNotifierProvider.notifier).getAdvice(profile.age, profile.weight);
    });
  }

  Future<void> _checkDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAccepted = prefs.getBool('has_accepted_disclaimer') ?? false;
    
    if (!hasAccepted && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Disclaimer', style: TextStyle(color: Colors.amberAccent)),
            ],
          ),
          content: const Text(
            'This app is for informational purposes only and does not constitute medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
              onPressed: () async {
                await prefs.setBool('has_accepted_disclaimer', true);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('I Understand', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _showManualLogDialog() {
    final stepsController = TextEditingController();
    final sleepHoursController = TextEditingController();
    final sleepMinutesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Manual Health Log', style: TextStyle(color: Colors.cyanAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stepsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Daily Steps',
                labelStyle: const TextStyle(color: Colors.white70),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5))),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sleepHoursController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Sleep (Hours)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5))),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: sleepMinutesController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Sleep (Minutes)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              final steps = int.tryParse(stepsController.text) ?? 5000;
              final sleepHours = double.tryParse(sleepHoursController.text) ?? 7;
              final sleepMins = double.tryParse(sleepMinutesController.text) ?? 0;
              final totalSleepMinutes = (sleepHours * 60) + sleepMins;
              
              ref.read(healthDataProvider.notifier).manuallyUpdateHealthData(steps, totalSleepMinutes, 0.0);
              
              final profile = ref.read(profileProvider);
              ref.read(coachNotifierProvider.notifier).getAdvice(profile.age, profile.weight);
              
              Navigator.pop(context);
            },
            child: const Text('Save Data', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String title, String initialValue, Function(String) onSave) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text('Edit $title', style: const TextStyle(color: Colors.cyanAccent)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UpgradeModalBottomSheet(),
    );
  }

  Widget _buildTierOption(String title, String subtitle, Color color, SubscriptionTier tier) {
    return InkWell(
      onTap: () {
        ref.read(profileProvider.notifier).updateTier(tier);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upgraded to $title!')));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(Icons.star, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final coachState = ref.watch(coachNotifierProvider);
    final healthState = ref.watch(healthDataProvider);
    final healthAlerts = ref.watch(healthAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welloa Hub', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purpleAccent, width: 2),
                boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.5), blurRadius: 8)],
              ),
              child: const Icon(Icons.power_settings_new, color: Colors.purpleAccent, size: 20),
            ),
            tooltip: 'Log Out',
            onPressed: () async {
              await ref.read(authServiceProvider).logOut();
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => context.push('/notifications'),
              ),
              if (healthAlerts.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${healthAlerts.length}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        tier: profile.tier,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGlobalLongevityScore(),
                _buildProfileCard(profile),
                _buildHealthConnectSync(healthState),
                const SizedBox(height: 32),
                _buildLongevityGraph(profile, healthState),
                const SizedBox(height: 32),
                const Text('Longevity Features', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                _buildFeatureGrid(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalLongevityScore() {
    return UnicornGlassCard(
      glowColor: Colors.purpleAccent,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          const Text('GLOBAL LONGEVITY SCORE', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('+4.2', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(width: 8),
              Text('Years', style: TextStyle(fontSize: 24, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Based on your active movement and sleep patterns, you are currently aging slower than 84% of your peers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[300], height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/chat'),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Chat with Welloa AI to Optimize'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent.withOpacity(0.2),
              foregroundColor: Colors.purpleAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.purpleAccent),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showSmartwatchHubModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SmartwatchHubModal(),
    );
  }

  Widget _buildHealthConnectSync(AsyncValue<HealthData> healthState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.indigoAccent.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.indigoAccent.withOpacity(0.5)),
            ),
          ),
          onPressed: _showSmartwatchHubModal,
          icon: const Icon(Icons.watch, color: Colors.indigoAccent),
          label: healthState.when(
            loading: () => const Text('Syncing Health Connect...', style: TextStyle(color: Colors.indigoAccent)),
            error: (err, stack) => const Text('Sync Failed - Tap to Retry', style: TextStyle(color: Colors.redAccent)),
            data: (data) => Text(
              data.isAuthorized ? 'Health Connect Synced' : 'Connect Smart Watch',
              style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (healthState.valueOrNull?.isAuthorized == false || healthState.hasError) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showManualLogDialog,
            icon: const Icon(Icons.edit, color: Colors.amberAccent),
            label: const Text('No Smartwatch? Manual Log', style: TextStyle(color: Colors.amberAccent, decoration: TextDecoration.underline)),
          ),
        ]
      ],
    );
  }

  Widget _buildProfileCard(UserProfile profile) {
    return UnicornGlassCard(
      glowColor: Colors.cyanAccent,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.cyanAccent,
                child: Icon(Icons.person, size: 40, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Biological Blueprint',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showUpgradeDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTierColor(profile.tier).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getTierColor(profile.tier)),
                        ),
                        child: Text(
                          profile.tier.name.toUpperCase(),
                          style: TextStyle(color: _getTierColor(profile.tier), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProfileStat('Age', '${profile.age}', Icons.cake, () {
                _showEditDialog('Age', '${profile.age}', (val) {
                  final newAge = int.tryParse(val);
                  if (newAge != null) {
                    ref.read(profileProvider.notifier).updateAge(newAge);
                    ref.read(coachNotifierProvider.notifier).getAdvice(newAge, profile.weight);
                  }
                });
              }),
              _buildProfileStat('Weight', '${profile.weight}kg', Icons.monitor_weight, () {
                _showEditDialog('Weight', '${profile.weight}', (val) {
                  final newWeight = double.tryParse(val);
                  if (newWeight != null) {
                    ref.read(profileProvider.notifier).updateWeight(newWeight);
                    ref.read(coachNotifierProvider.notifier).getAdvice(profile.age, newWeight);
                  }
                });
              }),
              _buildProfileStat('Pacing', '0.8x', Icons.speed, null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(String label, String value, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              if (onTap != null) const Icon(Icons.edit, size: 12, color: Colors.cyanAccent),
            ],
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getTierColor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.ultra:
        return Colors.purpleAccent;
      case SubscriptionTier.premium:
        return Colors.amberAccent;
      case SubscriptionTier.freemium:
      default:
        return Colors.grey;
    }
  }

  Widget _buildLongevityGraph(UserProfile profile, AsyncValue<HealthData> healthState) {
    // Determine aging rate based on health connect data
    double agingRate = 1.0;
    if (healthState.hasValue && healthState.value!.isAuthorized) {
      final health = healthState.value!;
      if (health.steps > 8000 && health.sleepMinutes > 420) {
        agingRate = 0.7; // Slower aging
      } else if (health.steps < 3000) {
        agingRate = 1.2; // Faster aging
      } else {
        agingRate = 0.9; // Slightly better than 1.0 if using app
      }
    }

    final double baseAge = profile.age.toDouble();
    List<FlSpot> realAgeSpots = [];
    List<FlSpot> expectedAgingSpots = [];

    for (int i = 0; i <= 6; i++) {
      realAgeSpots.add(FlSpot(i.toDouble(), baseAge + i));
      expectedAgingSpots.add(FlSpot(i.toDouble(), baseAge + (i * agingRate)));
    }

    final double minY = baseAge - 1;
    final double maxY = baseAge + 7;

    return UnicornGlassCard(
      glowColor: Colors.cyanAccent,
      padding: const EdgeInsets.all(24),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Longevity Projection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Real Age vs Expected Biological Aging', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 2,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.white10, strokeWidth: 1);
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(color: Colors.white10, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.white70, fontSize: 12);
                        Widget text;
                        switch (value.toInt()) {
                          case 0: text = const Text('Now', style: style); break;
                          case 2: text = const Text('+2Y', style: style); break;
                          case 4: text = const Text('+4Y', style: style); break;
                          case 6: text = const Text('+6Y', style: style); break;
                          default: text = const Text('', style: style); break;
                        }
                        return SideTitleWidget(axisSide: meta.axisSide, child: text);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}y', style: const TextStyle(color: Colors.white70, fontSize: 12));
                      },
                      reservedSize: 32,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24, width: 1)),
                minX: 0,
                maxX: 6,
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final textStyle = TextStyle(
                          color: touchedSpot.barIndex == 0 ? Colors.cyanAccent : Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        );
                        final prefix = touchedSpot.barIndex == 0 ? 'Chronological: ' : 'Biological: ';
                        final gain = touchedSpot.x - (touchedSpot.y - baseAge);
                        final gainText = gain > 0 ? '+${gain.toStringAsFixed(1)} yr gain' : '${gain.toStringAsFixed(1)} yr lost';
                        return LineTooltipItem('$prefix${touchedSpot.y.toStringAsFixed(1)}y\n$gainText', textStyle);
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                lineBarsData: [
                  // User's Real Age Curve
                  LineChartBarData(
                    spots: realAgeSpots,
                    isCurved: true,
                    color: Colors.cyanAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.cyanAccent.withOpacity(0.1),
                    ),
                  ),
                  // Expected Biological Aging from Health Connect
                  LineChartBarData(
                    spots: expectedAgingSpots,
                    isCurved: true,
                    color: Colors.purpleAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.purpleAccent.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: Colors.cyanAccent, size: 12),
              SizedBox(width: 4),
              Text('Real Age', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, color: Colors.purpleAccent, size: 12),
              SizedBox(width: 4),
              Text('Health Connect', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(String title, String content, IconData icon, Color color) {
    return AnimatedGlowBorder(
      glowColor: color,
      child: UnicornGlassCard(
        padding: const EdgeInsets.all(20),
        margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
        ],
      ),
    ));
  }

  Widget _buildFeatureGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildFeatureCard(context, 'Nutrition', Icons.camera_alt, Colors.greenAccent, '/nutrition'),
        _buildFeatureCard(context, 'Sleep', Icons.bedtime, Colors.indigoAccent, '/sleep'),
        _buildFeatureCard(context, 'Activity', Icons.directions_run, Colors.orangeAccent, '/activity'),
        _buildFeatureCard(context, 'Discover', Icons.explore, Colors.pinkAccent, '/discover'),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon, Color color, String route) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: UnicornGlassCard(
        glowColor: color,
        margin: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
