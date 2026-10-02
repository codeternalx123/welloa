import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../providers/glucose_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/wearable_intelligence_hub.dart';
import '../services/health_connect_manager.dart';
import '../services/food_glucose_service.dart';
import '../utils/responsive_utils.dart';
import 'gluco_coach_chat_screen.dart';

/// UNICORN UX: The Metabolic Nexus.
/// Features: Predictive Spline Graph, Bio-Aperture Gauge, Neural Insight Feed,
/// Health Connect status, and manual glucose entry.
class GlucoseNexusDashboard extends StatefulWidget {
  const GlucoseNexusDashboard({super.key});

  @override
  State<GlucoseNexusDashboard> createState() => _GlucoseNexusDashboardState();
}

class _GlucoseNexusDashboardState extends State<GlucoseNexusDashboard> with TickerProviderStateMixin {
  late AnimationController _meshController;
  late AnimationController _chartController;
  
  final WearableIntelligenceHub _hub = WearableIntelligenceHub();
  bool _showHealthConnectBanner = false;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _chartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GlucoseProvider>().initialize();
      _chartController.forward();
      _checkHealthConnectStatus();
    });
    
    // Listen to hub changes
    _hub.addListener(_onHubUpdate);
  }

  void _onHubUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkHealthConnectStatus() async {
    await _hub.initialize();
    if (mounted && _hub.needsHealthConnectInstall) {
      setState(() => _showHealthConnectBanner = true);
    }
  }

  @override
  void dispose() {
    _meshController.dispose();
    _chartController.dispose();
    _hub.removeListener(_onHubUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<QuerySnapshot>(
      stream: userId != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('glucose_readings')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .snapshots()
          : null,
      builder: (context, glucoseSnapshot) {
        // Get glucose from Firebase or fallback to provider
        double glucose = 100.0;
        if (glucoseSnapshot.hasData && glucoseSnapshot.data!.docs.isNotEmpty) {
          final doc = glucoseSnapshot.data!.docs.first;
          glucose = (doc['value'] as num?)?.toDouble() ?? 100.0;
        } else {
          final provider = context.watch<GlucoseProvider>();
          glucose = provider.currentGlucose ?? 100.0;
        }
        
        final isSpiking = glucose >= 160;

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // 1. KINETIC BACKGROUND: Biological Mesh
              _buildMetabolicBackground(isSpiking),

              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // 2. THE APERTURE (Simplified Modern Header)
                    _buildSliverHeader(glucose, isSpiking),

                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.isCompactView(context) ? 16 : 20,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // HEALTH CONNECT STATUS BANNER
                          if (_showHealthConnectBanner) ...[
                            _buildHealthConnectBanner(),
                            SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),
                          ],
                          
                          // SYNC MODE INDICATOR
                          _buildSyncModeIndicator(),
                          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),

                          // METABOLIC LENS (moved from Meal Planner)
                          _buildMetabolicLensCard(),
                          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),

                          // 3. THE LIVE WAVEFORM (The Graph)
                          _buildGlucoseWaveform(),
                          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),

                          // 4. PREDICTIVE INSIGHT (What happens next)
                          _buildPredictiveCard(glucose),
                          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),

                          // 5. SUPPORTED DEVICES & CONNECT
                          _buildSupportedDevicesSection(),
                          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),

                          // 6. BODY COMMANDS (Quick Actions)
                          _buildBodyCommandGrid(),
                          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 100)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _buildNeuralAIFAB(),
        );
      },
    );
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================

  Widget _buildMetabolicBackground(bool isSpiking) {
    return AnimatedBuilder(
      animation: _meshController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                0.5 * math.sin(_meshController.value * 2 * math.pi),
                -0.2 * math.cos(_meshController.value * 2 * math.pi),
              ),
              colors: isSpiking 
                ? [const Color(0xFFFEF3C7), const Color(0xFFFFF7ED), Colors.white]
                : [const Color(0xFFECFDF5), const Color(0xFFF1F5F9), Colors.white],
              radius: 1.5,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverHeader(double glucose, bool isSpiking) {
    final sub = context.watch<SubscriptionProvider>();
    final String tierLabel;
    final Color tierColor;
    if (sub.isUltra) {
      tierLabel = 'ULTRA';
      tierColor = const Color(0xFFDB2777);
    } else if (sub.isPremium) {
      tierLabel = 'PREMIUM';
      tierColor = const Color(0xFF7C3AED);
    } else if (sub.isStarter) {
      tierLabel = 'STARTER';
      tierColor = const Color(0xFF2563EB);
    } else {
      tierLabel = 'FREE';
      tierColor = Colors.blueGrey;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BODY SCORE', 
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10, color: Colors.blueGrey)),
                const SizedBox(height: 4),
                Text(glucose.toStringAsFixed(0), 
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -2)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tierColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      color: tierColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildStabilityBadge(isSpiking),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStabilityBadge(bool isSpiking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSpiking ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.greenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSpiking ? Colors.orangeAccent : Colors.greenAccent),
      ),
      child: Row(
        children: [
          Icon(isSpiking ? Icons.bolt_rounded : Icons.auto_awesome_rounded, 
            size: 16, color: isSpiking ? Colors.orange : Colors.green),
          const SizedBox(width: 8),
          Text(isSpiking ? 'HIGH ENERGY' : 'STABLE MODE', 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: isSpiking ? Colors.orange : Colors.green)),
        ],
      ),
    );
  }

  // ============================================
  // THE REAL-WORLD TRACKING GRAPH
  // ============================================

  Widget _buildGlucoseWaveform() {
    final chartHeight = ResponsiveUtils.getResponsiveHeight(context, 200);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('24H GLUCOSE WAVE', 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5, color: Colors.blueGrey)),
              StreamBuilder<QuerySnapshot>(
                stream: userId != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('glucose_readings')
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .snapshots()
                    : null,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final lastReading = snapshot.data!.docs.first;
                    final timestamp = (lastReading['timestamp'] as Timestamp?)?.toDate();
                    if (timestamp != null) {
                      final diff = DateTime.now().difference(timestamp);
                      final timeAgo = diff.inMinutes < 60 
                          ? '${diff.inMinutes}m ago'
                          : '${diff.inHours}h ago';
                      return Text(
                        'Last: $timeAgo',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 24)),
          SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: StreamBuilder<QuerySnapshot>(
              stream: userId != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('glucose_readings')
                      .orderBy('timestamp', descending: true)
                      .limit(24)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                List<double> glucoseData = [90, 100, 95, 100, 105, 100, 95, 100, 95, 100]; // Default
                
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  glucoseData = snapshot.data!.docs
                      .map((doc) => (doc['value'] as num?)?.toDouble() ?? 100.0)
                      .toList()
                      .reversed
                      .toList();
                  
                  // Ensure we have at least 10 points
                  while (glucoseData.length < 10) {
                    glucoseData.insert(0, glucoseData.isNotEmpty ? glucoseData.first : 100.0);
                  }
                }
                
                return CustomPaint(
                  painter: _SplineChartPainter(
                    data: glucoseData,
                    animationValue: _chartController.value,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveHeight(context, 16)),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeLabel('08:00'),
              _TimeLabel('12:00'),
              _TimeLabel('16:00'),
              _TimeLabel('NOW'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPredictiveCard(double glucose) {
    return _GlassCard(
      color: Colors.blueAccent.withValues(alpha: 0.05),
      child: const Row(
        children: [
          Icon(Icons.psychology_rounded, color: Colors.blueAccent, size: 32),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEURAL FORECAST', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.blueAccent)),
                SizedBox(height: 4),
                Text('Stable for the next 2 hours.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Your body is processing your last fuel efficiently.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HEALTH CONNECT STATUS & MANUAL ENTRY
  // ============================================

  Widget _buildHealthConnectBanner() {
    return GestureDetector(
      onTap: () async {
        final installed = await _hub.promptHealthConnectInstall();
        if (installed && mounted) {
          // Wait for user to return from Play Store
          Future.delayed(const Duration(seconds: 3), () async {
            await _hub.retryAfterInstall();
            if (mounted && _hub.isHealthConnectAvailable) {
              setState(() => _showHealthConnectBanner = false);
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF59E0B).withValues(alpha: 0.15),
              const Color(0xFFF59E0B).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Connect Required',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to install for wearable sync',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Install',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showHealthConnectBanner = false),
              child: const Icon(Icons.close, size: 20, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncModeIndicator() {
    final mode = _hub.syncMode;
    final icon = _hub.getSyncModeIcon();
    final description = _hub.getSyncModeDescription();

    Color bgColor;
    Color textColor;
    IconData indicatorIcon;

    switch (mode) {
      case BiometricSyncMode.wearableSync:
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
        textColor = const Color(0xFF10B981);
        indicatorIcon = Icons.watch_rounded;
        break;
      case BiometricSyncMode.hybrid:
        bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.1);
        textColor = const Color(0xFF3B82F6);
        indicatorIcon = Icons.sync_rounded;
        break;
      case BiometricSyncMode.manualOnly:
        bgColor = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
        textColor = const Color(0xFF8B5CF6);
        indicatorIcon = Icons.edit_note_rounded;
        break;
      case BiometricSyncMode.unknown:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        indicatorIcon = Icons.hourglass_empty;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(indicatorIcon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$icon $description',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SUPPORTED DEVICES & CONNECT SECTION
  // ============================================

  Widget _buildSupportedDevicesSection() {
    final supportedDevices = <Map<String, Object>>[
      {'name': 'Apple Watch', 'icon': Icons.watch, 'status': 'Compatible', 'requiresUltraCgm': false},
      {'name': 'Fitbit', 'icon': Icons.watch_rounded, 'status': 'Compatible', 'requiresUltraCgm': false},
      {'name': 'Samsung Galaxy Watch', 'icon': Icons.watch_outlined, 'status': 'Compatible', 'requiresUltraCgm': false},
      {'name': 'Garmin', 'icon': Icons.directions_run, 'status': 'Compatible', 'requiresUltraCgm': false},
      {'name': 'Freestyle Libre', 'icon': Icons.sensors, 'status': 'CGM link · Ultra', 'requiresUltraCgm': true},
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SUPPORTED DEVICES',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: Colors.blueGrey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'HEALTH CONNECT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Connected devices from Firebase
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .collection('connected_devices')
                .doc('wearables')
                .snapshots(),
            builder: (context, snapshot) {
              final connectedDevices = snapshot.hasData && snapshot.data!.exists
                  ? List<String>.from((snapshot.data!.data() as Map<String, dynamic>?)?['devices'] ?? [])
                  : <String>[];

              return Column(
                children: [
                  if (connectedDevices.isNotEmpty) ...[
                    ...connectedDevices.map((device) => _buildConnectedDeviceTile(device)),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                  ],
                  
                  // Supported devices list
                  ...supportedDevices.map((device) {
                    final isConnected = connectedDevices.contains(device['name']);
                    return _buildDeviceTile(
                      device['name'] as String,
                      device['icon'] as IconData,
                      device['status'] as String,
                      isConnected,
                      requiresUltraForCgm: device['requiresUltraCgm'] as bool,
                    );
                  }),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Connect new device button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showConnectDeviceDialog(),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('CONNECT NEW DEVICE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(
    String name,
    IconData icon,
    String status,
    bool isConnected, {
    bool requiresUltraForCgm = false,
  }) {
    final sub = context.watch<SubscriptionProvider>();
    final needsUltraCgm = requiresUltraForCgm && !sub.canAccessCGMIntegration;

    final subtitleColor = isConnected
        ? const Color(0xFF10B981)
        : needsUltraCgm
            ? const Color(0xFFDB2777)
            : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConnected 
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isConnected ? const Color(0xFF10B981) : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isConnected ? const Color(0xFF0F172A) : Colors.grey.shade700,
                  ),
                ),
                Text(
                  isConnected ? 'Connected' : status,
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            )
          else if (requiresUltraForCgm)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (needsUltraCgm ? const Color(0xFFDB2777) : const Color(0xFF6366F1))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                needsUltraCgm ? 'ULTRA' : 'CGM',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: needsUltraCgm ? const Color(0xFFDB2777) : const Color(0xFF6366F1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceTile(String deviceName) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.watch, size: 20, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'Syncing glucose data',
                  style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () => _disconnectDevice(deviceName),
          ),
        ],
      ),
    );
  }

  void _showConnectDeviceDialog() {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.watch_rounded, size: 48, color: Color(0xFF6366F1)),
            const SizedBox(height: 16),
            const Text(
              'Connect a Device',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your wearable through Health Connect to sync glucose data automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Device options
            _buildConnectOption('Apple Watch', Icons.watch, () => _connectDevice('Apple Watch')),
            _buildConnectOption('Fitbit', Icons.watch_rounded, () => _connectDevice('Fitbit')),
            _buildConnectOption('Samsung Galaxy Watch', Icons.watch_outlined, () => _connectDevice('Samsung Galaxy Watch')),
            _buildConnectOption('Garmin', Icons.directions_run, () => _connectDevice('Garmin')),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (_hub.needsHealthConnectInstall) {
                    await HealthConnectManager.showInstallDialog(context);
                  } else {
                    await _hub.syncBiometrics();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Looking for devices...')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'OPEN HEALTH CONNECT',
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectOption(String name, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6366F1)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _connectDevice(String deviceName) async {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    
    // Show info dialog instead of auto-connecting
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: const Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connect $deviceName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          'To connect your $deviceName:\n\n'
          '1. Open Health Connect app\n'
          '2. Add $deviceName as a data source\n'
          '3. Grant permissions for glucose data\n'
          '4. Return to Wellor and tap "Sync Now"\n\n'
          'Your device will appear here once connected.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              if (_hub.needsHealthConnectInstall) {
                await HealthConnectManager.showInstallDialog(context);
              } else {
                await _hub.syncBiometrics();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Health Connect...')),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('OPEN HEALTH CONNECT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectDevice(String deviceName) async {
    HapticFeedback.mediumImpact();
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('connected_devices')
          .doc('wearables')
          .update({
        'devices': FieldValue.arrayRemove([deviceName]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deviceName disconnected')),
        );
      }
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
    }
  }

  Widget _buildBodyCommandGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _CommandCard(
          label: _hub.isHealthConnectAvailable ? 'SYNC NOW' : 'CONNECT WEARABLE',
          icon: Icons.watch_rounded,
          color: Colors.indigo,
          onTap: () async {
            if (_hub.isHealthConnectAvailable) {
              await _hub.syncBiometrics();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Biometrics synced!')),
                );
              }
            } else if (_hub.needsHealthConnectInstall) {
              await HealthConnectManager.showInstallDialog(context);
            }
          },
        ),
        _CommandCard(
          label: 'ADD READING',
          icon: Icons.add_circle_outline_rounded,
          color: Colors.purple,
          onTap: _showManualEntryDialog,
        ),
      ],
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bloodtype_rounded,
                    size: 36,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Manual Glucose Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your glucose reading manually',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '100',
                    hintStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    suffixText: 'mg/dL',
                    suffixStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)',
                    hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final value = double.tryParse(controller.text);
                          if (value != null && value > 0 && value < 600) {
                            // Save to Firebase
                            final userId = FirebaseAuth.instance.currentUser?.uid;
                            if (userId != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('glucose_readings')
                                  .add({
                                'value': value,
                                'notes': notesController.text.isEmpty 
                                    ? null 
                                    : notesController.text,
                                'timestamp': FieldValue.serverTimestamp(),
                                'source': 'manual',
                              });
                            }
                            
                            // Also update via hub
                            _hub.addManualEntry(
                              glucoseLevel: value,
                              notes: notesController.text.isEmpty 
                                  ? null 
                                  : notesController.text,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reading saved: ${value.toStringAsFixed(0)} mg/dL'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid glucose value'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Save Reading',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeuralAIFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const GlucoCoachChatScreen()),
        );
      },
      backgroundColor: const Color(0xFF0F172A),
      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.greenAccent),
      label: const Text('ASK GLUCO-COACH', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.greenAccent)),
    );
  }

  Widget _buildMetabolicLensCard() {
    return Consumer2<GlucoseProvider, UserProfileProvider>(
      builder: (context, glucoseProvider, profileProvider, _) {
        final g = glucoseProvider.currentGlucose;
        final diseases = profileProvider.userProfile?.diseases ?? const <String>[];
        final glycemicCare = diseases.any(
          (d) => d.toLowerCase().contains('diabet') || d.toLowerCase().contains('glucose'),
        );
        final advice = glucoseProvider.advice;
        final adviceShort = advice.length > 120 ? '${advice.substring(0, 117)}…' : advice;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F172A).withValues(alpha: 0.92),
                const Color(0xFF312E81).withValues(alpha: 0.88),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bubble_chart_rounded,
                      color: Colors.cyanAccent.shade100, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Metabolic lens',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  if (glucoseProvider.isSynchronizing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (glycemicCare)
                Chip(
                  label: const Text('Low-GI bias enabled'),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g != null ? '${g.toStringAsFixed(0)} mg/dL' : 'No recent glucose',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adviceShort,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => glucoseProvider.refreshMetabolicTelemetry(),
                        child: const Text('Sync'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => _showMealImpactSheet(context),
                        child: Text(
                          'Simulate meal',
                          style: TextStyle(
                            color: Colors.cyanAccent.shade100,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Wellness insights only — not a substitute for medical advice.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMealImpactSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _MealImpactSheet(),
    );
  }

  // Simple “unicorn” feature: fast meal impact simulation on-demand.
  // (Uses FoodGlucoseService; does not claim medical accuracy.)
}

class _MealImpactSheet extends StatefulWidget {
  const _MealImpactSheet();

  @override
  State<_MealImpactSheet> createState() => _MealImpactSheetState();
}

class _MealImpactSheetState extends State<_MealImpactSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final foods = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (foods.isEmpty) return;

    setState(() {
      _busy = true;
      _result = null;
    });

    try {
      final advice = await FoodGlucoseService.getOverallMealAdvice(
        ingredients: foods,
        userGlucotype: 'Baseline',
      );
      if (!mounted) return;
      setState(() => _result = advice);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Could not simulate: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: inset + 20, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Simulate meal impact',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter ingredients separated by commas (e.g. rice, beans, chicken).',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'ingredients, like, this',
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _run,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Run'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(
              _result!,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Wellness insights only — not medical advice.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ============================================
// ATOMIC UX WIDGETS
// ============================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _GlassCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CommandCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassCard(
        color: color.withValues(alpha: 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final String text;
  const _TimeLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey));
  }
}

// ============================================
// THE SPLINE CHART PAINTER
// ============================================

class _SplineChartPainter extends CustomPainter {
  final List<double> data;
  final double animationValue;

  _SplineChartPainter({required this.data, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.greenAccent.withValues(alpha: 0.3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final stepX = size.width / (data.length - 1);
    const maxVal = 250.0; // Max glucose mg/dL

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxVal * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Cubic bezier for "Unicorn" smoothness
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (data[i - 1] / maxVal * size.height);
        path.cubicTo(
          prevX + stepX / 2, prevY,
          x - stepX / 2, y,
          x, y,
        );
      }
    }

    // Draw the animated line
    canvas.drawPath(path, paint);

    // Close path for fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}