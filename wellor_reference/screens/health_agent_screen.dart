// lib/screens/health_agent_screen.dart
// In-app dashboard for the autonomous Health Agent.
// Shows intervention history, GlucoCoach opt-in, device connection, and agent status.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/health_agent_service.dart';
import '../services/gluco_coach_ai_service.dart';
import '../services/claude_agent_pipeline.dart';
import '../services/gemini_agent_pipeline.dart';
import '../services/multi_agent_system.dart';
import '../services/wearable_data_service.dart';
import '../services/autonomous_procurement_engine.dart';
import '../services/craving_interception_agent.dart';
import '../services/intervention_escalation_service.dart';
import '../services/deterministic_safety_engine.dart';
import '../services/twilio_voice_service.dart';
import '../models/glucose_context.dart';
import '../providers/subscription_provider.dart';
import '../providers/health_profile_provider.dart';
import 'gluco_coach_chat_screen.dart';
import '../models/subscription_tier.dart';
import '../widgets/feature_restriction_widgets.dart';
import 'subscription_screen.dart';
import 'cgm_settings_screen.dart';

class HealthAgentScreen extends StatefulWidget {
  const HealthAgentScreen({super.key});

  @override
  State<HealthAgentScreen> createState() => _HealthAgentScreenState();
}

class _HealthAgentScreenState extends State<HealthAgentScreen> {
  final _agent = HealthAgentService();
  final _glucoCoach = GlucoCoachAIService();
  final _pipeline = ClaudeAgentPipeline();
  final _geminiPipeline = GeminiAgentPipeline();
  final _mas = MultiAgentSystem.instance;
  final _wearable = WearableDataService();
  final _procurement = AutonomousProcurementEngine();
  final _cravingAgent = CravingInterceptionAgent();
  final _interventionService = InterventionEscalationService();
  // Removed edge computing - using cloud-based AI only
  final _safetyEngine = DeterministicSafetyEngine();
  final _phoneController = TextEditingController();
  final _testGlucoseController = TextEditingController(text: '120');

  List<AgentIntervention> _interventions = [];
  bool _loading = true;
  bool _glucoCoachOptedIn = false;
  bool _registering = false;
  bool _testingPipeline = false;
  Map<String, dynamic>? _pipelineTestResult;
  DateTime? _pipelineStartTime;
  AgentIntervention? _liveIntervention;
  bool _deviceConnected = false;
  bool _connectingDevice = false;
  bool _masInitialized = false;
  List<ResolvedAction> _agentActions = []; // Latest MAS actions
  String? _welcomeMessage; // Welcome message sent on GlucoCoach connect
  Map<String, dynamic> _latestBiometrics = {}; // Latest wearable data
  // Feature flags for smart features
  bool _procurementEnabled = false;
  int _cravingInterceptions = 0;
  int _safetyInterventions = 0;

  SubscriptionProvider? _subscriptionProvider;
  bool _subscriptionListening = false;

  // —— Unicorn surface system (Health Agent) ——
  static const double _haRadius = 24;
  static const double _haRadiusSm = 16;
  static const Color _haBg0 = Color(0xFFF8FAFC);
  static const Color _haBg1 = Color(0xFFEEF2FF);
  static const Color _haBg2 = Color(0xFFE0E7FF);
  static const Color _haInk = Color(0xFF0F172A);
  static const Color _haMuted = Color(0xFF64748B);
  static const Color _haLine = Color(0xFFE2E8F0);
  static const Color _haIndigo = Color(0xFF6366F1);
  static const Color _haViolet = Color(0xFF8B5CF6);
  static const Color _haMint = Color(0xFF10B981);
  static const Color _haMintDeep = Color(0xFF047857);

  LinearGradient get _haAmbientGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_haBg0, _haBg1, _haBg2],
        stops: [0.0, 0.5, 1.0],
      );

  BoxDecoration _haGlassCard({Color? borderTint}) {
    final borderColor =
        borderTint != null ? borderTint.withValues(alpha: 0.22) : _haLine;
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(_haRadius),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: _haIndigo.withValues(alpha: 0.08),
          blurRadius: 36,
          offset: const Offset(0, 16),
          spreadRadius: -10,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _agent.addInterventionListener(_onLiveIntervention);
    // Listen for MAS resolved actions
    _mas.actionStream.listen(_onAgentAction);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscriptionProvider ??= context.read<SubscriptionProvider>();
    if (!_subscriptionListening) {
      _subscriptionListening = true;
      _subscriptionProvider!.addListener(_onSubscriptionChanged);
    }
    _onSubscriptionChanged();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    final sub = _subscriptionProvider!;
    if (!sub.hasAIHealthTeam) {
      if (_masInitialized || _agentActions.isNotEmpty) {
        setState(() {
          _masInitialized = false;
          _agentActions.clear();
        });
      }
      return;
    }
    if (!_masInitialized && !_loading) {
      _initializeMultiAgentSystem();
    }
  }

  @override
  void dispose() {
    if (_subscriptionListening) {
      _subscriptionProvider?.removeListener(_onSubscriptionChanged);
    }
    _agent.removeInterventionListener(_onLiveIntervention);
    _phoneController.dispose();
    _testGlucoseController.dispose();
    super.dispose();
  }

  void _onLiveIntervention(AgentIntervention intervention) {
    if (!mounted) return;
    setState(() => _liveIntervention = intervention);
    // Auto-dismiss after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _liveIntervention?.id == intervention.id) {
        setState(() => _liveIntervention = null);
      }
    });
  }

  /// Initialize the Multi-Agent System with user's health profile and wearable data
  Future<void> _initializeMultiAgentSystem() async {
    if (!context.read<SubscriptionProvider>().hasAIHealthTeam) {
      return;
    }
    try {
      final healthProvider = context.read<HealthProfileProvider>();
      await healthProvider.loadProfile();
      final profile = healthProvider.profile;

      // Check wearable permissions and read biometric data
      Map<String, dynamic> biometrics = {};
      final hasPerms = await _wearable.hasPermissions();
      if (hasPerms) {
        biometrics = await _wearable.readAllBiometrics();
        // Sync to Firestore for background agents
        await _wearable.syncToFirestore();
      }

      final state = AgentState(
        odId: 'current_user',
        healthProfile: profile,
        currentGlucose: (biometrics['glucose'] as num?)?.toDouble(),
        heartRate: (biometrics['heartRate'] as num?)?.toDouble(),
        restingHeartRate: (biometrics['restingHeartRate'] as num?)?.toDouble(),
        heartRateVariability: (biometrics['heartRateVariability'] as num?)?.toDouble(),
        stepsToday: biometrics['stepsToday'] as int?,
        sleepHours: (biometrics['sleepHours'] as num?)?.toDouble(),
        sleepQualityScore: biometrics['sleepQuality'] as int?,
        hydrationLiters: (biometrics['hydrationLiters'] as num?)?.toDouble(),
        caloriesBurnedToday: (biometrics['caloriesBurned'] as num?)?.toDouble(),
        bloodOxygen: (biometrics['bloodOxygen'] as num?)?.toDouble(),
        bodyTemperature: (biometrics['bodyTemperature'] as num?)?.toDouble(),
        bloodPressureSystolic: (biometrics['bloodPressureSystolic'] as num?)?.toDouble(),
        bloodPressureDiastolic: (biometrics['bloodPressureDiastolic'] as num?)?.toDouble(),
        workoutMinutesToday: biometrics['workoutMinutesToday'] as int?,
        glucoseMonitorConnected: hasPerms && biometrics['glucose'] != null,
        wearableConnected: hasPerms,
        glucoCoachNumber: profile.glucoCoachNumber,
        glucoseHistory: List<Map<String, dynamic>>.from(biometrics['glucoseHistory'] ?? []),
        heartRateHistory: List<Map<String, dynamic>>.from(biometrics['heartRateHistory'] ?? []),
      );

      await _mas.initialize(state);
      if (mounted) {
        setState(() {
          _masInitialized = true;
          _deviceConnected = hasPerms;
          _latestBiometrics = biometrics;
        });
      }
    } catch (e) {
      debugPrint('[HealthAgentScreen] MAS init error: $e');
    }
  }

  /// Connect wearable device via Health Connect / HealthKit
  Future<void> _connectDevice() async {
    if (!checkWearableAccess(context)) return;
    setState(() => _connectingDevice = true);
    try {
      final authorized = await _wearable.requestAuthorization();
      if (authorized) {
        final biometrics = await _wearable.readAllBiometrics();
        await _wearable.syncToFirestore();

        // Update health profile with device status
        final healthProvider = context.read<HealthProfileProvider>();
        await healthProvider.updateDeviceStatus(
          glucoseMonitor: biometrics['glucose'] != null,
          wearable: true,
          deviceName: biometrics['sourcePlatform'] as String?,
        );

        // Update MAS state with new data
        _mas.updateDeviceStatus(
          glucoseMonitor: biometrics['glucose'] != null,
          wearable: true,
          deviceName: biometrics['sourcePlatform'] as String?,
        );

        if (mounted) {
          setState(() {
            _deviceConnected = true;
            _latestBiometrics = biometrics;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device connected! Reading ${biometrics.keys.where((k) => biometrics[k] != null).length} health metrics.'),
              backgroundColor: Colors.green,
            ),
          );

          // Re-initialize MAS with fresh biometric data
          await _initializeMultiAgentSystem();
        }
      } else {
        if (mounted) {
          _showPermissionSettingsDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device connection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingDevice = false);
    }
  }

  /// Show a dialog letting the user grant Health permissions from within the app.
  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Health Access Required',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wellor needs Health Connect access to read glucose, heart rate, sleep, and activity data.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Open Health Connect and enable all permissions for Wellor.',
                        style: TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Permissions needed:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blue.shade800)),
                    const SizedBox(height: 6),
                    _permissionRow(Icons.bloodtype_rounded, 'Blood glucose'),
                    _permissionRow(Icons.favorite_rounded, 'Heart rate & HRV'),
                    _permissionRow(Icons.bedtime_rounded, 'Sleep data'),
                    _permissionRow(Icons.directions_walk_rounded, 'Steps & activity'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _wearable.openHealthSettings();
                },
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Health Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _connectDevice();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _permissionRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  /// Handle resolved actions from the Multi-Agent System
  void _onAgentAction(ResolvedAction action) {
    if (!mounted) return;
    if (!context.read<SubscriptionProvider>().hasAIHealthTeam) return;
    setState(() {
      _agentActions.insert(0, action);
      if (_agentActions.length > 20) _agentActions.removeLast();
    });

    // Show snackbar for high-priority actions
    if (action.priority >= 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action.message, maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: action.priority >= 9 ? Colors.red : Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _agent.getInterventionHistory(limit: 30),
        _glucoCoach.isOptedIn(),
        _loadAgentSettings(),
      ]);
      if (mounted) {
        setState(() {
          _interventions = results[0] as List<AgentIntervention>;
          _glucoCoachOptedIn = results[1] as bool;
        });
      }
      if (mounted && context.read<SubscriptionProvider>().hasAIHealthTeam) {
        await _initializeMultiAgentSystem();
      }
    } catch (e) {
      debugPrint('HealthAgentScreen: Load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAgentSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('agent_data')
          .doc('settings')
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _procurementEnabled = data['procurementEnabled'] == true;
        _cravingInterceptions =
            (data['cravingInterceptions'] as num?)?.toInt() ?? 0;
        _safetyInterventions =
            (data['safetyInterventions'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      debugPrint('[HealthAgentScreen] settings load: $e');
    }
  }

  Future<void> _setProcurementEnabled(bool enabled) async {
    setState(() => _procurementEnabled = enabled);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('agent_data')
          .doc('settings')
          .set({'procurementEnabled': enabled}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HealthAgentScreen] settings save: $e');
    }
  }

  Future<void> _recordAgentStat({
    int cravingDelta = 0,
    int safetyDelta = 0,
  }) async {
    if (cravingDelta == 0 && safetyDelta == 0) return;
    if (!mounted) return;
    setState(() {
      _cravingInterceptions += cravingDelta;
      _safetyInterventions += safetyDelta;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('agent_data')
          .doc('settings')
          .set({
        'cravingInterceptions': _cravingInterceptions,
        'safetyInterventions': _safetyInterventions,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HealthAgentScreen] stat save: $e');
    }
  }

  SafetyEvaluation _evaluateGlucoseSafety(double glucose) {
    final velocity = glucose > 160 ? 1.5 : (glucose < 80 ? -1.2 : 0.3);
    return DeterministicSafetyEngine.evaluateSafety(
      GlucoseContext(
        currentValue: glucose,
        velocity: velocity,
        acceleration: 0,
        predicted20min: glucose + velocity * 20,
        predicted45min: glucose + velocity * 45,
        predicted90min: glucose + velocity * 90,
        history: const [],
        timestamp: DateTime.now(),
        source: 'manual',
      ),
    );
  }

  Future<void> _registerGlucoCoach() async {
    if (!checkFeatureAccess(
      context,
      featureName: 'GlucoCoach',
      featureDescription:
          'Premium and Ultra can connect GlucoCoach for blood sugar alerts, meal tips, and coaching messages.',
      accessCheck: (p) => p.hasGlucoCoach,
      icon: Icons.chat_rounded,
    )) {
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your GlucoCoach number'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    // Validate phone format
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use international format: +1 1234567890'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    setState(() => _registering = true);
    try {
      final success = await _glucoCoach.registerGlucoCoach(phone);
      if (mounted) {
        if (success) {
          setState(() => _glucoCoachOptedIn = true);
          _phoneController.clear();

          // Save GlucoCoach number to health profile
          final healthProvider = context.read<HealthProfileProvider>();
          await healthProvider.updateGlucoCoachNumber(phone);

          // Make sure MAS is initialized before sending personalized welcome
          if (!_masInitialized) {
            await _initializeMultiAgentSystem();
          }

          // Send personalized welcome message + health briefing via MAS
          await _sendWelcomeMessage(phone);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GlucoCoach connected! Check your messages.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid number. Use format: +254712345678'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[HealthAgentScreen] GlucoCoach registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  /// Send welcome message on GlucoCoach via Multi-Agent System
  Future<void> _sendWelcomeMessage(String phone) async {
    debugPrint('[HealthAgentScreen] Sending welcome message to $phone');
    
    // Check if GlucoCoach service is configured
    if (!_glucoCoach.isConfigured) {
      debugPrint('[HealthAgentScreen] GlucoCoach not configured - missing Twilio credentials');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GlucoCoach messaging not configured. Contact support.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
      return;
    }
    
    try {
      // 1. Generate personalized welcome message
      String message;
      if (_masInitialized) {
        message = await _mas.sendWelcomeMessage(phone);
      } else {
        message = '👋 Welcome to Wellor Health Agent!\n\n'
            'I\'m your AI 24/7 health companion. I\'ll help you:\n'
            '• Monitor glucose & stay in range\n'
            '• Get personalized meal advice\n'
            '• Track hydration & sleep\n'
            '• Stay active with smart nudges\n\n'
            'Reply anytime to chat! 💚';
      }
      
      // 2. Actually send the message via Twilio GlucoCoach API
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      await _glucoCoach.sendProactiveMessage(
        userId: uid,
        message: message,
      );
      debugPrint('[HealthAgentScreen] Welcome message sent');
      
      // 3. Only show in UI if actually sent
      if (mounted) {
        setState(() => _welcomeMessage = message);
      }

      // 4. Run all 4 mini-agents to generate an initial health briefing
      if (_masInitialized) {
        debugPrint('[HealthAgentScreen] Running mini-agents for health briefing...');
        final actions = await _mas.processEventDirect(
          trigger: AgentTriggerType.dailyPlanning,
        );

        if (actions.isNotEmpty) {
          final briefing = StringBuffer('📋 *Your Initial Health Briefing*\n\n');

          for (final action in actions) {
            final agentLabel = switch (action.resolvedBy) {
              'sleep'     => '😴 Sleep',
              'hydration' => '💧 Hydration',
              'exercise'  => '🏃 Exercise',
              'snack'     => '🍎 Nutrition',
              _           => '🤖 ${action.resolvedBy}',
            };
            briefing.writeln('$agentLabel:\n${action.message}\n');
          }

          briefing.write('Reply anytime to chat with your health agent! 💚');

          await _glucoCoach.sendProactiveMessage(
            userId: uid,
            message: briefing.toString(),
          );
          debugPrint('[HealthAgentScreen] Health briefing sent');
        } else {
          debugPrint('[HealthAgentScreen] No actions returned from mini-agents');
        }
      }
    } catch (e) {
      debugPrint('[HealthAgentScreen] Welcome message error: $e');
      rethrow; // Re-throw so caller knows it failed
    }
  }

  Future<void> _optOut() async {
    try {
      await _glucoCoach.optOut();
      final healthProvider = context.read<HealthProfileProvider>();
      await healthProvider.updateGlucoCoachNumber(null);

      if (mounted) {
        _phoneController.clear();
        setState(() => _glucoCoachOptedIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GlucoCoach disconnected'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not disconnect GlucoCoach: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Test the AI Health Analysis pipeline with a glucose reading
  Future<void> _testPipeline() async {
    final glucoseText = _testGlucoseController.text.trim();
    final glucose = double.tryParse(glucoseText);
    if (glucose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid glucose number'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!await recordAiInteractionAccess(context)) {
      return;
    }

    setState(() {
      _testingPipeline = true;
      _pipelineTestResult = null;
      _pipelineStartTime = DateTime.now();
    });

    try {
      final sub = context.read<SubscriptionProvider>();
      final safety = _evaluateGlucoseSafety(glucose);
      if (!safety.isSafe) {
        await _recordAgentStat(safetyDelta: 1);
      }

      // Use Multi-Agent System if initialized (Ultra AI Health Team)
      if (_masInitialized && sub.hasAIHealthTeam) {
        final actions = await _mas.onGlucoseReading(glucose);
        final elapsed = DateTime.now().difference(_pipelineStartTime!);

        final isAlert = !safety.isSafe || glucose > 160 || glucose < 70;
        final agentSources = actions.map((a) => a.resolvedBy).toSet().join(', ');
        final combinedMessage = actions.isNotEmpty
            ? actions.map((a) => a.message).join('\n\n')
            : safety.reasoning;
        final cravingHits =
            actions.where((a) => a.resolvedBy == 'snack').length;
        if (cravingHits > 0) {
          await _recordAgentStat(cravingDelta: cravingHits);
        }

        setState(() {
          _pipelineTestResult = {
            'glucoseLevel': glucose,
            'analysisType': isAlert
                ? (glucose > 160 ? 'High blood sugar' : glucose < 70 ? 'Low blood sugar' : safety.state.name)
                : 'In a healthy range',
            'status': isAlert ? 'Needs attention' : 'Looks good',
            'recommendation': combinedMessage,
            'safetyNote': safety.reasoning,
            'elapsedMs': elapsed.inMilliseconds,
            'dataSource': _deviceConnected ? 'Connected device' : 'Manual entry',
            'confidence': _deviceConnected ? 'High' : 'Standard',
            'isAlert': isAlert,
            'agentSources': agentSources,
            'agentCount': actions.length,
          };
          _agentActions = [...actions, ..._agentActions];
        });
      } else {
        // Free: Gemini pipeline; Starter+: Claude Sonnet pipeline
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user';
        final testState = PatientState(
          patientId: userId,
          phoneNumber: null,
          glucoseLevel: glucose,
          glucoseVelocity: glucose > 160 ? 1.5 : (glucose < 80 ? -1.2 : 0.3),
          patientProfile: 'General wellness goals: stable blood sugar and healthy habits.',
        );

        final PatientState result;
        if (sub.isFree) {
          result = await _geminiPipeline.invoke(testState);
        } else {
          result = await _pipeline.invoke(testState);
        }
        final elapsed = DateTime.now().difference(_pipelineStartTime!);
        final isAlert = !safety.isSafe || result.anomalyDetected;

        setState(() {
          _pipelineTestResult = {
            'glucoseLevel': glucose,
            'analysisType': result.anomalyDetected
                ? _formatAnomalyType(result.anomalyType)
                : (safety.isSafe ? 'In a healthy range' : safety.state.name),
            'status': isAlert ? 'Needs attention' : 'Looks good',
            'recommendation': result.interventionPlan ?? safety.reasoning,
            'safetyNote': safety.reasoning,
            'elapsedMs': elapsed.inMilliseconds,
            'dataSource': _deviceConnected ? 'Connected device' : 'Manual entry',
            'confidence': result.anomalyDetected ? 'High' : 'Standard',
            'isAlert': isAlert,
          };
        });
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(_pipelineStartTime!);
      setState(() {
        _pipelineTestResult = {
          'status': 'Error',
          'recommendation': 'Analysis failed: $e',
          'elapsedMs': elapsed.inMilliseconds,
          'isAlert': false,
        };
      });
    } finally {
      setState(() => _testingPipeline = false);
    }
  }

  String _formatAnomalyType(String? type) {
    switch (type) {
      case 'HYPOGLYCEMIA': return 'Low blood sugar';
      case 'HYPERGLYCEMIA': return 'High blood sugar';
      case 'ACTIVE_SPIKE': return 'Blood sugar spike';
      case 'IMPENDING_SPIKE': return 'Blood sugar rising';
      case 'RAPID_DROP': return 'Blood sugar dropping fast';
      default: return type ?? 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _haBg0,
      body: Container(
        decoration: BoxDecoration(gradient: _haAmbientGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_liveIntervention != null) _buildLiveAlert(_liveIntervention!),
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                color: _haIndigo,
                                strokeWidth: 3,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Loading your health data…',
                              style: TextStyle(
                                color: _haMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: _haIndigo,
                        backgroundColor: Colors.white,
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          children: [
                            Consumer<SubscriptionProvider>(
                              builder: (context, sub, _) {
                                if (!sub.isUltra) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildUltraCommandDeck(context),
                                );
                              },
                            ),
                            _buildUpgradeBanner(),
                            _buildAgentStatusCard(),
                            const SizedBox(height: 16),
                            if (context.watch<SubscriptionProvider>().hasAIHealthTeam) ...[
                              _buildMultiAgentOverview(),
                              const SizedBox(height: 16),
                            ],
                            _buildAdvancedAgentFeaturesCard(),
                            const SizedBox(height: 16),
                            _buildDeviceConnectionCard(),
                            const SizedBox(height: 16),
                            _buildGlucoCoachAccessCard(context),
                            const SizedBox(height: 16),
                            if (context.watch<SubscriptionProvider>().hasAIHealthTeam &&
                                _agentActions.isNotEmpty) ...[
                              _buildAgentActionsCard(),
                              const SizedBox(height: 16),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUltraCommandDeck(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.22),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment(-1.2, -1),
              end: Alignment(1.1, 1.2),
              colors: [
                Color(0xFF1E1B4B),
                Color(0xFF5B21B6),
                Color(0xFFDB2777),
                Color(0xFFF97316),
              ],
              stops: [0.0, 0.35, 0.72, 1.0],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -24,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 128,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              Positioned(
                left: -40,
                bottom: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: const Text(
                            'ULTRA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Icon(Icons.bolt_rounded,
                              color: Colors.amber.shade100, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ultra plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unlimited scans, glucose monitor support, daily health reports, and optional phone alerts.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final voiceConfigured = TwilioVoiceService().isConfigured;
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                voiceConfigured
                                    ? Icons.phone_in_talk_rounded
                                    : Icons.phone_disabled_rounded,
                                color: Colors.white.withValues(alpha: 0.85),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  voiceConfigured
                                      ? 'Phone alerts are ready if you turn them on for urgent issues.'
                                      : 'Phone alerts need server setup before they can call you.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 11,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _UltraChip(label: 'Glucose'),
                        _UltraChip(label: 'Sleep'),
                        _UltraChip(label: 'Training'),
                        _UltraChip(label: 'Macros'),
                        _UltraChip(label: 'Stress'),
                        _UltraChip(label: 'Meds'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeBanner() {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        if (subscriptionProvider.isUltra) {
          return const SizedBox.shrink();
        }
        final currentTier = subscriptionProvider.subscription?.tier ?? SubscriptionTier.free;
        final isFree = currentTier == SubscriptionTier.free;

        if (isFree) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_haRadius),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: _haViolet.withValues(alpha: 0.38),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(
                      Icons.electric_bolt_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upgrade your plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'More scans, meal plans, and coaching on Premium',
                          style: TextStyle(
                            color: Color(0xFFE0E7FF),
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(_haRadius),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFFFACC15),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upgrade Plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFACC15).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${currentTier.name.toUpperCase()} PLAN',
                            style: const TextStyle(
                              color: Color(0xFFFACC15),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildGlucoCoachAccessCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B21B6).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (!checkGlucoCoachQuota(context)) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GlucoCoachChatScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GlucoCoach AI Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to chat with your intelligent metabolic assistant.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _haGlassCard(
        borderTint: _deviceConnected ? _haMint : _haIndigo,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _deviceConnected ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.watch,
                  color: _deviceConnected ? Colors.green : Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Glucose & fitness tracker',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _haInk,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _deviceConnected
                          ? 'Connected · syncing your data'
                          : 'Link your fitness tracker or glucose monitor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _deviceConnected ? _haMintDeep : _haMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_deviceConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _deviceConnected ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _deviceConnected ? Icons.check_circle : Icons.info_outline,
                  color: _deviceConnected ? Colors.green.shade700 : Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _deviceConnected
                        ? 'Tracking ${_latestBiometrics.keys.where((k) => _latestBiometrics[k] != null && k != 'lastSyncTime' && k != 'sourcePlatform' && k != 'updatedAt').length} health stats. Alerts can go to GlucoCoach when something looks off.'
                        : 'Connect a Libre sensor, Apple Watch, Fitbit, or other tracker so your AI team can give better advice.',
                    style: TextStyle(fontSize: 12, color: _deviceConnected ? Colors.green.shade800 : Colors.blue.shade800, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          if (_deviceConnected && _latestBiometrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBiometricsSummary(),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connectingDevice ? null : _connectDevice,
                  icon: _connectingDevice
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_deviceConnected ? Icons.sync : Icons.bluetooth, size: 18),
                  label: Text(_connectingDevice 
                      ? 'Connecting...' 
                      : _deviceConnected ? 'Sync Now' : 'Connect Device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _haIndigo,
                    side: const BorderSide(color: _haIndigo, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to health profile
                    Navigator.pushNamed(context, '/health-profile');
                  },
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Health Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _haViolet,
                    side: const BorderSide(color: _haViolet, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          Consumer<SubscriptionProvider>(
            builder: (context, sub, _) {
              if (!sub.canAccessCGMIntegration) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CgmSettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Connect glucose monitor (Libre)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _haMintDeep,
                      side: BorderSide(color: _haMintDeep.withValues(alpha: 0.85), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Supported: Freestyle Libre 2/3, Apple Watch, Fitbit, Garmin, Samsung Health',
            style: TextStyle(
              fontSize: 11,
              color: _haMuted,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Show a compact summary of latest biometric readings from the wearable
  Widget _buildBiometricsSummary() {
    final items = <_BiometricItem>[];
    
    if (_latestBiometrics['heartRate'] != null) {
      items.add(_BiometricItem('💓', 'Heart Rate', '${(_latestBiometrics['heartRate'] as num).toStringAsFixed(0)} bpm'));
    }
    if (_latestBiometrics['glucose'] != null) {
      items.add(_BiometricItem('🩸', 'Glucose', '${(_latestBiometrics['glucose'] as num).toStringAsFixed(0)} mg/dL'));
    }
    if (_latestBiometrics['bloodOxygen'] != null) {
      items.add(_BiometricItem('🫁', 'SpO2', '${(_latestBiometrics['bloodOxygen'] as num).toStringAsFixed(0)}%'));
    }
    if (_latestBiometrics['stepsToday'] != null) {
      items.add(_BiometricItem('👟', 'Steps', '${_latestBiometrics['stepsToday']}'));
    }
    if (_latestBiometrics['sleepHours'] != null) {
      items.add(_BiometricItem('😴', 'Sleep', '${(_latestBiometrics['sleepHours'] as num).toStringAsFixed(1)}h'));
    }
    if (_latestBiometrics['hydrationLiters'] != null) {
      items.add(_BiometricItem('💧', 'Water', '${(_latestBiometrics['hydrationLiters'] as num).toStringAsFixed(1)}L'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _haBg0,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _haLine),
          boxShadow: [
            BoxShadow(
              color: _haIndigo.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              item.value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _haInk,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.88),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: _haInk.withValues(alpha: 0.85)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_haMint, _haMint.withValues(alpha: 0.75)],
              ),
              borderRadius: BorderRadius.circular(_haRadiusSm),
              boxShadow: [
                BoxShadow(
                  color: _haMint.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR HEALTH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    color: _haMuted,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'AI Health Agent',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _haInk,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Blood sugar, fitness tracker, and daily tips',
                  style: TextStyle(
                    fontSize: 12,
                    color: _haMuted.withValues(alpha: 0.95),
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _haMint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _haMint.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _haMint,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _haMint.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _haMintDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAlert(AgentIntervention intervention) {
    final color = intervention.urgency == InterventionUrgency.critical
        ? Colors.red
        : intervention.urgency == InterventionUrgency.high
            ? Colors.orange
            : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: color, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        intervention.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 20, color: _haMuted),
                      onPressed: () {
                        _agent.dismissIntervention(intervention.id);
                        setState(() => _liveIntervention = null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  intervention.message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _haInk.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (intervention.exerciseAction != null) ...[
                  const SizedBox(height: 8),
                  _buildActionChip(
                      '🏃', intervention.exerciseAction!, Colors.green),
                ],
                if (intervention.mealAction != null)
                  _buildActionChip(
                      '🍎', intervention.mealAction!, Colors.orange),
                if (intervention.avoidAction != null)
                  _buildActionChip(
                      '🚫', intervention.avoidAction!, Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(String emoji, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Color.lerp(color, Colors.black, 0.3), fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentStatusCard() {
    final sub = context.watch<SubscriptionProvider>();
    final masStatus = !sub.hasAIHealthTeam
        ? 'Ultra plan'
        : _masInitialized
            ? '4 helpers active'
            : 'Starting…';
    final masColor = !sub.hasAIHealthTeam
        ? Colors.grey
        : _masInitialized
            ? Colors.deepPurple
            : Colors.orange;
    final analysisStatus =
        sub.isFree ? 'Basic' : (sub.hasAIHealthTeam ? 'Full team' : 'Standard');
    final alertsStatus = sub.isFree
        ? '${sub.remainingAiInteractions}/${SubscriptionQuotas.freeAiInteractionsPerDay} AI/day'
        : 'On';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _haGlassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_haIndigo, _haViolet],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: _haMuted,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _masInitialized
                      ? _haMint.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _masInitialized
                        ? _haMint.withValues(alpha: 0.28)
                        : Colors.orange.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: sub.hasAIHealthTeam && _masInitialized
                              ? _haMint
                              : Colors.orange,
                          shape: BoxShape.circle,
                        )),
                    const SizedBox(width: 8),
                    Text(
                      sub.hasAIHealthTeam && _masInitialized
                          ? 'Ready'
                          : 'Getting ready…',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sub.hasAIHealthTeam && _masInitialized
                            ? _haMintDeep
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'What\'s running',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _haInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusRow(Icons.monitor_heart, 'Blood sugar tracking',
              _deviceConnected ? 'Live data' : 'Manual entry',
              _deviceConnected ? Colors.green : Colors.orange),
          const SizedBox(height: 12),
          _buildStatusRow(Icons.hub, 'AI health team', masStatus, masColor),
          const SizedBox(height: 12),
          _buildStatusRow(Icons.psychology, 'Health analysis', analysisStatus,
              sub.isFree ? Colors.orange : Colors.deepPurple),
          const SizedBox(height: 12),
          _buildStatusRow(Icons.notifications_active, 'Smart alerts',
              alertsStatus, sub.isFree ? Colors.grey : Colors.blue),
          const SizedBox(height: 12),
          _buildStatusRow(
            Icons.chat,
            'GlucoCoach',
            _glucoCoachOptedIn ? 'Connected' : 'Not connected',
            _glucoCoachOptedIn ? Colors.green : Colors.grey,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(Icons.sync, 'Health profile', 'Saved', Colors.teal),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String status, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _haInk,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Test card for the LangGraph Claude Sonnet pipeline
  Widget _buildPipelineTestCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science, color: Colors.deepPurple, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LangGraph Pipeline Test',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Sentinel → Reasoning → Execution',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Test the 3-node Claude Sonnet agent pipeline with a simulated glucose reading. No GlucoCoach message will be sent.',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testGlucoseController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g., 185',
                    labelText: 'Glucose (mg/dL)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _testingPipeline ? null : _testPipeline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _testingPipeline
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Run'),
              ),
            ],
          ),
          if (_pipelineTestResult != null) ...[
            const SizedBox(height: 16),
            _buildAnalysisResults(_pipelineTestResult!),
          ],
        ],
      ),
    );
  }

  /// Health Analysis card with user-friendly labels


  Widget _buildAnalysisResults(Map<String, dynamic> result) {
    final isAlert = result['isAlert'] == true;
    final bgColor = result['status'] == 'Error' 
        ? Colors.red.shade50 
        : isAlert ? Colors.orange.shade50 : Colors.green.shade50;
    final borderColor = result['status'] == 'Error'
        ? Colors.red.shade200
        : isAlert ? Colors.orange.shade200 : Colors.green.shade200;
    final statusColor = result['status'] == 'Error'
        ? Colors.red
        : isAlert ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            children: [
              Icon(
                result['status'] == 'Error' 
                    ? Icons.error_outline 
                    : isAlert ? Icons.warning_amber_rounded : Icons.check_circle,
                color: statusColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result['status'] ?? 'Analysis Complete',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: statusColor),
                    ),
                    if (result['analysisType'] != null)
                      Text(result['analysisType'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${result['elapsedMs']}ms',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Analysis metrics
          Row(
            children: [
              Expanded(child: _buildMetricTile('Reading', '${(result['glucoseLevel'] ?? 0).toStringAsFixed(0)} mg/dL', Icons.water_drop)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile('Source', result['dataSource'] ?? 'Manual', Icons.device_hub)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile('Confidence', result['confidence'] ?? 'N/A', Icons.verified)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Recommendation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    const Text('What to do next',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result['recommendation'] ?? 'No recommendation available.',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                if (result['safetyNote'] != null &&
                    (result['safetyNote'] as String).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Safety check: ${result['safetyNote']}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          if (!_deviceConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connect a glucose monitor for automatic tracking and better tips',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
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

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple.shade300),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }


  Widget _buildGlucoCoachFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF25D366)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.3))),
        ],
      ),
    );
  }

  /// Multi-Agent System overview card showing all 4 specialist agents
  Widget _buildMultiAgentOverview() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _haGlassCard(borderTint: _haIndigo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade400, Colors.indigo.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Health Team',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Four helpers working together',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _masInitialized ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _masInitialized ? 'Active' : 'Starting...',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: _masInitialized ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Supervisor
          _buildAgentRow(
            Icons.medical_services,
            'Main health coach',
            'Coordinates your team',
            'Picks the best advice for you',
            Colors.deepPurple,
          ),
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(child: _buildMiniAgentTile(
                Icons.bedtime, 'Sleep', 'Daily morning check', Colors.indigo,
              )),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniAgentTile(
                Icons.local_drink, 'Hydration', 'Regular reminders', Colors.cyan,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMiniAgentTile(
                Icons.directions_run, 'Exercise', 'When you need a nudge', Colors.green,
              )),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniAgentTile(
                Icons.restaurant, 'Meals', 'When you need food ideas', Colors.orange,
              )),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield, color: Colors.deepPurple.shade400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'If two helpers disagree, the main coach combines your health profile into one safe suggestion.',
                    style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRow(IconData icon, String name, String model, String role, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                Text(model, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Flexible(
            child: Text(role,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAgentTile(IconData icon, String name, String trigger, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                Text(trigger, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card showing recent resolved actions from the Multi-Agent System
  Widget _buildAgentActionsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _haGlassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Agent activity',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _haInk,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Text(
                '${_agentActions.length} action${_agentActions.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _haMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _agentActions.length > 5 ? 5 : _agentActions.length,
            (i) {
              final action = _agentActions[i];
              final actionColor = action.priority >= 8
                  ? Colors.red
                  : action.priority >= 5
                      ? Colors.orange
                      : Colors.blue;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      action.type == 'glucocoach_message' ? Icons.chat : Icons.notifications,
                      size: 16,
                      color: actionColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action.message,
                              style: const TextStyle(fontSize: 12, height: 1.3),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('via ${action.resolvedBy}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Card showcasing advanced AI features — Ultra ([hasAIHealthTeam]) only.
  Widget _buildAdvancedAgentFeaturesCard() {
    return Consumer<SubscriptionProvider>(
      builder: (context, sub, _) {
        if (!sub.hasAIHealthTeam) {
          return _buildUltraOnlyFeatureCard(
            title: 'AI Health Team',
            body:
                'Ultra unlocks your full AI health team, smart meal help, craving support, and phone alerts. Upgrade to turn these on.',
          );
        }
        return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF), // Pure white
            Color(0xFFF8FAFC), // Light background
          ],
        ),
        borderRadius: BorderRadius.circular(32), // Squircle geometry
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.15), // Vitality border
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Header with Vitality Accent
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI HEALTH TEAM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 2.0,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Always-on health help',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              // Premium Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Medical Disclaimer - Light theme
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF64748B).withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI tips only — not medical advice. Talk to your doctor for care decisions.',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Premium Feature Tiles
          _buildAdvancedFeatureTile(
            icon: Icons.restaurant_menu,
            title: 'Smart meal planning',
            subtitle: 'Meals matched to your goals',
            description: 'AI suggests meal plans based on your blood sugar patterns and food preferences',
            status: _procurementEnabled ? 'On' : 'Off',
            statusColor: _procurementEnabled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            iconColor: const Color(0xFF10B981),
            enabled: _procurementEnabled,
            onToggle: _setProcurementEnabled,
          ),
          const SizedBox(height: 14),
          
          _buildAdvancedFeatureTile(
            icon: Icons.psychology,
            title: 'Craving support',
            subtitle: '$_cravingInterceptions tips sent',
            description: 'AI watches for patterns and sends helpful food suggestions before cravings hit',
            status: _cravingInterceptions > 0 ? 'Active' : 'Learning',
            statusColor: const Color(0xFF8B5CF6),
            iconColor: const Color(0xFF8B5CF6),
            showToggle: false,
          ),
          const SizedBox(height: 14),
          
          _buildAdvancedFeatureTile(
            icon: Icons.health_and_safety,
            title: 'Health alerts',
            subtitle: 'App, GlucoCoach, and phone',
            description: 'Important alerts start in the app, then GlucoCoach, and can call you for urgent issues if you opt in',
            status: _glucoCoachOptedIn ? 'GlucoCoach on' : 'Connect GlucoCoach',
            statusColor: _glucoCoachOptedIn ? const Color(0xFF10B981) : const Color(0xFF64748B),
            iconColor: const Color(0xFFEF4444),
            showToggle: false,
          ),
          const SizedBox(height: 14),
          
          _buildAdvancedFeatureTile(
            icon: Icons.shield_moon,
            title: 'Safety checks',
            subtitle: 'Extra review on every tip',
            description: 'Built-in rules double-check AI advice so suggestions stay within safe ranges',
            status: _safetyInterventions > 0
                ? '$_safetyInterventions checks run'
                : 'Always on',
            statusColor: const Color(0xFF10B981),
            iconColor: const Color(0xFFFACC15),
            showToggle: false,
          ),
          const SizedBox(height: 24),
          
          // Value Proposition Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.08),
                  const Color(0xFF34D399).withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_graph,
                      color: const Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'How your AI team helps',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your AI team watches blood sugar trends, sends helpful tips, and steps in when something looks off — even while you sleep.',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(
                      icon: Icons.bolt,
                      label: 'Live updates',
                      color: const Color(0xFFFACC15),
                    ),
                    _buildMetricChip(
                      icon: Icons.psychology,
                      label: 'Smart tips',
                      color: const Color(0xFF8B5CF6),
                    ),
                    _buildMetricChip(
                      icon: Icons.verified,
                      label: 'Safety checked',
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildUltraOnlyFeatureCard({
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _haGlassCard(borderTint: _haViolet),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_person_rounded, color: _haViolet, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _haInk,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _haViolet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ULTRA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: _haViolet,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: _haMuted,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _haViolet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'View Ultra plans',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required String status,
    required Color statusColor,
    required Color iconColor,
    bool showToggle = true,
    bool enabled = false,
    Function(bool)? onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF64748B).withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.25),
                      iconColor.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (showToggle && onToggle != null)
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: enabled,
                    onChanged: onToggle,
                    activeColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInterventionTile(AgentIntervention intervention) {
    final color = intervention.urgency == InterventionUrgency.critical
        ? Colors.red
        : intervention.urgency == InterventionUrgency.high
            ? Colors.orange
            : intervention.urgency == InterventionUrgency.medium
                ? Colors.blue
                : Colors.grey;

    final timeAgo = _formatTimeAgo(intervention.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _haLine),
        boxShadow: [
          BoxShadow(
            color: _haIndigo.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(intervention.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Text(timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(intervention.message,
              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3)),
          if (intervention.exerciseAction != null || intervention.mealAction != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (intervention.exerciseAction != null)
                  _buildMiniChip('🏃 ${intervention.exerciseAction}', Colors.green),
                if (intervention.mealAction != null)
                  _buildMiniChip('🍎 ${intervention.mealAction}', Colors.orange),
                if (intervention.avoidAction != null)
                  _buildMiniChip('🚫 ${intervention.avoidAction}', Colors.red),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                intervention.channel == InterventionChannel.glucoCoach ||
                        intervention.channel == InterventionChannel.both
                    ? Icons.chat
                    : Icons.phone_android,
                size: 12,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                intervention.delivered ? 'Delivered' : 'In-app only',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: Color.lerp(color, Colors.black, 0.3))),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}';
  }
}

class _UltraChip extends StatelessWidget {
  final String label;
  const _UltraChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BiometricItem {
  final String emoji;
  final String label;
  final String value;
  _BiometricItem(this.emoji, this.label, this.value);
}
