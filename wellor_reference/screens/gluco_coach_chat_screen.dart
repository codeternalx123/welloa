import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import 'package:provider/provider.dart';
import '../providers/glucose_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/gluco_coach_ai_service.dart';
import '../widgets/feature_restriction_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


/// UNICORN UX: The Metabolic Intelligence Hub.
/// Features: Glassmorphic Bubble Architecture, Neural Haptics, and Spatial Contextualization.
class GlucoCoachChatScreen extends StatefulWidget {
  const GlucoCoachChatScreen({super.key});

  @override
  State<GlucoCoachChatScreen> createState() => _GlucoCoachChatScreenState();
}

class _GlucoCoachChatScreenState extends State<GlucoCoachChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final GlucoCoachAIService _coachAi = GlucoCoachAIService();
  bool _isTyping = false;
  bool _hasText = false;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _initializeCoach();
  }

  void _initializeCoach() async {
    _fadeController.forward();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gluco_coach_messages')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) return;

    if (!mounted) return;
    final sub = context.read<SubscriptionProvider>();
    final profile = context.read<UserProfileProvider>().userProfile;
    final goals = profile?.healthGoals ?? const <String>[];
    final conditions = profile?.diseases ?? const <String>[];

    var intro =
        "Hi! I'm your Gluco-Coach. I personalize advice from your health goals and conditions";
    if (goals.isNotEmpty) {
      intro += ' (${goals.take(2).join(", ")}${goals.length > 2 ? "…" : ""})';
    }
    intro += '.\n\nAsk about meals, habits, or glucose-friendly choices. What would you like to know?';
    intro += '\n\nPowered by Claude Sonnet 3.5.';

    final quota = sub.glucoCoachQuotaLabel;
    if (quota != 'Unlimited') {
      intro += '\n\nChats remaining: $quota.';
    }

    if (conditions.isNotEmpty) {
      intro += '\n\nI\'ll keep your conditions in mind: ${conditions.join(", ")}.';
    }

    _addMessage(
      ChatMessage(
        text: intro,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildUnicornAppBar(),
      body: Stack(
        children: [
          // 1. DYNAMIC BACKGROUND: Biological Mesh
          _buildMetabolicBackground(),

          SafeArea(
            child: Column(
              children: [
                // 2. LIVE STATUS HEADER (Biometric Context)
                _buildLiveContextBar(),

                // 3. SPATIAL CHAT FEED
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .collection('gluco_coach_messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Failed to load history: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                      }
                      
                      _messages.clear();
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        _messages.add(ChatMessage(
                          text: data['text'] ?? '',
                          isUser: data['isUser'] ?? false,
                          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                        ));
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isTyping && index == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          return _buildUnicornMessage(_messages[index]);
                        },
                      );
                    },
                  ),
                ),

                // 4. NEURAL INPUT CONSOLE
                _buildNeuralInputConsole(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetabolicBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF022C22), Color(0xFF000000)],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildUnicornAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text('GLUCO COACH',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14, color: Colors.white70)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildLiveContextBar() {
    final glucose = context.watch<GlucoseProvider>().currentGlucose;
    final sub = context.watch<SubscriptionProvider>();
    final profile = context.watch<UserProfileProvider>().userProfile;
    final goals = profile?.healthGoals ?? const <String>[];
    final conditions = profile?.diseases ?? const <String>[];

    final contextLabel = sub.isFree
        ? (goals.isNotEmpty || conditions.isNotEmpty
            ? 'PROFILE: ${[...goals.take(1), ...conditions.take(1)].join(" · ")}'
            : 'PROFILE: add goals & conditions')
        : 'LIVE BIOMETRIC SYNC: ${glucose?.toStringAsFixed(0) ?? "--"} mg/dL';

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: Colors.white.withValues(alpha: 0.05),
          child: Row(
            children: [
              Icon(
                sub.isFree ? Icons.person_rounded : Icons.sensors_rounded,
                color: Colors.greenAccent,
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  contextLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (sub.remainingGlucoCoachChats >= 0)
                Text(
                  sub.glucoCoachQuotaLabel,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                _buildPulseIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnicornMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: _GlassBubble(
            isUser: message.isUser,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    height: 1.5,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeuralInputConsole() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.12),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: Colors.greenAccent,
                    onChanged: (value) {
                      setState(() {
                        _hasText = value.isNotEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Ask metabolic questions...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      suffixIcon: _hasText
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent.withValues(alpha: 0.6),
                                size: 20,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _sendMessage(_messageController.text);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.greenAccent, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // ============================================
  // LOGIC & UTILITIES
  // ============================================

  Future<void> _addMessage(ChatMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gluco_coach_messages')
        .add({
      'text': message.text,
      'isUser': message.isUser,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    if (!await recordGlucoCoachAccess(context)) {
      return;
    }
    
    final userMessage = ChatMessage(text: text, isUser: true, timestamp: DateTime.now());
    await _addMessage(userMessage);
    _messageController.clear();
    setState(() => _hasText = false);
    setState(() => _isTyping = true);

    try {
      // Gather actual user context for grounded responses
      final glucoseProvider = context.read<GlucoseProvider>();
      final userProfileProvider = context.read<UserProfileProvider>();
      final nutritionProvider = context.read<NutritionGoalsProvider>();
      
      final glucose = glucoseProvider.currentGlucose;
      final velocity = glucoseProvider.metabolicVelocity;
      final profile = userProfileProvider.userProfile;
      final tracker = nutritionProvider.todayTracker;
      final goals = nutritionProvider.userGoals;

      final sub = context.read<SubscriptionProvider>();
      final isFreeCoach = sub.isFree;

      // Build context-rich system prompt with real user data
      final contextParts = <String>[];

      if (profile != null) {
        if (profile.healthGoals.isNotEmpty) {
          contextParts.add('Health goals: ${profile.healthGoals.join(", ")}');
        }
        if (profile.diseases.isNotEmpty) {
          contextParts.add('Health conditions: ${profile.diseases.join(", ")}');
        }
        if (profile.glucotype != null && profile.glucotype!.isNotEmpty) {
          contextParts.add('Glucotype: ${profile.glucotype}');
        }
        if (profile.age != null) contextParts.add('Age: ${profile.age}');
        if (profile.gender != null) contextParts.add('Gender: ${profile.gender}');
        if (profile.weight != null) contextParts.add('Weight: ${profile.weight} kg');
        if (profile.height != null) contextParts.add('Height: ${profile.height} cm');
        if (profile.activityLevel != null) {
          contextParts.add('Activity level: ${profile.activityLevel}');
        }
        contextParts.add('Daily calorie target: ${profile.dailyCalorieTarget} kcal');
      } else {
        contextParts.add('Health profile: incomplete — encourage user to complete goals and conditions');
      }

      if (!isFreeCoach && glucose != null) {
        contextParts.add('Current glucose: ${glucose.toStringAsFixed(0)} mg/dL');
        if (velocity != 0) {
          contextParts.add(
            'Glucose trend: ${velocity > 0 ? "rising" : "falling"} at ${velocity.abs().toStringAsFixed(1)} mg/dL per minute',
          );
        }
      } else if (!isFreeCoach) {
        contextParts.add('Glucose monitor: not connected (no live reading available)');
      } else if (glucose != null) {
        contextParts.add(
          'Latest logged glucose (if any): ${glucose.toStringAsFixed(0)} mg/dL — free tier coaching prioritizes goals/conditions over live CGM',
        );
      }
      
      if (tracker != null && tracker.totalCalories > 0) {
        contextParts.add('Today\'s intake so far: ${tracker.totalCalories.toStringAsFixed(0)} kcal, '
            '${tracker.totalProtein.toStringAsFixed(0)}g protein, '
            '${tracker.totalCarbs.toStringAsFixed(0)}g carbs, '
            '${tracker.totalFat.toStringAsFixed(0)}g fat');
        contextParts.add('Meals logged today: ${tracker.mealsLogged}');
      } else {
        contextParts.add('No meals logged today yet');
      }
      
      if (goals != null) {
        contextParts.add('Daily goals: ${goals.dailyCalorieGoal.toStringAsFixed(0)} kcal, '
            '${goals.proteinGoalGrams.toStringAsFixed(0)}g protein, '
            '${goals.carbsGoalGrams.toStringAsFixed(0)}g carbs, '
            '${goals.fatGoalGrams.toStringAsFixed(0)}g fat');
      }

      final userContext = contextParts.join('\n');

      final systemPrompt = '''You are Gluco-Coach, a helpful nutrition and glucose management assistant inside the Wellor app.

RULES:
- Give concise, practical answers (2-4 paragraphs max).
- ${isFreeCoach ? "PRIORITIZE the user's health goals and conditions in every reply. Tie meal, habit, and lifestyle advice to those goals." : "Use the user's actual data below to personalize your response. Reference specific numbers when relevant."}
- If glucose data is not available, coach from goals and conditions — do NOT invent glucose values.
- If a health profile field is missing, acknowledge it naturally and suggest they update their profile.
- Never tell the user to "connect to the internet" or claim there are connection issues — if you're responding, the connection is working.
- Do not diagnose medical conditions. For medical concerns, recommend consulting a healthcare professional.
- Be warm, clear, and direct. Avoid jargon unless the user uses it first.
- Format responses with line breaks for readability. Use bullet points sparingly.

USER CONTEXT:
$userContext

CONVERSATION HISTORY (last few exchanges for context):
${_getRecentHistory()}''';

      if (!_coachAi.isAvailable) {
        throw Exception('ANTHROPIC_API_KEY not configured');
      }

      final response = await _coachAi.generateReply(
        systemPrompt: systemPrompt,
        userPrompt: text,
        temperature: 0.7,
        maxTokens: 768,
      );

      if (response.isEmpty) {
        throw Exception('Empty response from Claude');
      }
      
      await _addMessage(ChatMessage(text: response, isUser: false, timestamp: DateTime.now()));
    } catch (e) {
      debugPrint('GlucoCoach error: $e');
      final err = e.toString();
      final msg = err.contains('ANTHROPIC_API_KEY')
          ? 'Gluco Coach needs ANTHROPIC_API_KEY in your .env file. Add your Claude API key and restart the app.'
          : err.contains('not_found_error') || err.contains('model:')
              ? 'Gluco Coach model is unavailable. Set ANTHROPIC_MODEL=claude-sonnet-4-6 in .env and restart.'
              : err.contains('Claude API error')
                  ? err.replaceFirst('Exception: ', '')
                  : 'I couldn\'t reach Claude right now. Check your connection and try again.';
      await _addMessage(ChatMessage(
        text: msg,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  /// Build recent conversation history for context continuity
  String _getRecentHistory() {
    final recent = _messages.length > 6 ? _messages.sublist(_messages.length - 6) : _messages;
    return recent.map((m) => '${m.isUser ? "User" : "Coach"}: ${m.text}').join('\n');
  }

  String _formatTime(DateTime time) => "${time.hour}:${time.minute.toString().padLeft(2, '0')}";

  Widget _buildPulseIndicator() {
    return Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _GlassBubble(
          isUser: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.greenAccent.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Claude is thinking…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// ATOMIC UX WIDGETS
// ============================================

class _GlassBubble extends StatelessWidget {
  final Widget child;
  final bool isUser;
  const _GlassBubble({required this.child, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(24),
        topRight: const Radius.circular(24),
        bottomLeft: Radius.circular(isUser ? 24 : 4),
        bottomRight: Radius.circular(isUser ? 4 : 24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isUser ? Colors.greenAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: isUser ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(24),
              topRight: const Radius.circular(24),
              bottomLeft: Radius.circular(isUser ? 24 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 24),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  ChatMessage({required this.text, required this.isUser, required this.timestamp});
}
