import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/ai_trial_provider.dart';
import '../../../../core/providers/health_provider.dart';
import '../../../../core/di/injection_container.dart';

class HealthAgentChatScreen extends ConsumerStatefulWidget {
  final dynamic initialAlertData;
  final String? initialAlert;

  const HealthAgentChatScreen({
    super.key,
    this.initialAlertData,
    this.initialAlert,
  });

  @override
  ConsumerState<HealthAgentChatScreen> createState() => _HealthAgentChatScreenState();
}

class _HealthAgentChatScreenState extends ConsumerState<HealthAgentChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isGenerating = false;
  int _variationCounter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _initializeChat() async {
    final health = ref.read(healthDataProvider).valueOrNull ?? HealthData();
    final sleepHours = health.sleepMinutes / 60;

    String? alertTitle;
    String? alertSubtitle;
    String? alertType;
    String? alertId;

    if (widget.initialAlertData is Map<String, dynamic>) {
      final map = widget.initialAlertData as Map<String, dynamic>;
      alertTitle = map['title'] as String?;
      alertSubtitle = map['subtitle'] as String?;
      alertType = map['type'] as String?;
      alertId = map['id'] as String?;
    } else if (widget.initialAlertData is String && widget.initialAlertData.toString().isNotEmpty) {
      alertTitle = widget.initialAlertData.toString();
    } else if (widget.initialAlert != null && widget.initialAlert!.isNotEmpty) {
      alertTitle = widget.initialAlert;
    }

    if (alertTitle != null && alertTitle.isNotEmpty) {
      final displayHeader = alertSubtitle != null && alertSubtitle.isNotEmpty
          ? '$alertTitle\n$alertSubtitle'
          : alertTitle;

      setState(() {
        _messages.add({
          'isUser': false,
          'text': 'Hello! I am your Welloa Health Bot.\n\nI noticed your alert:\n"$displayHeader"\n\nChecking your live numbers right now...',
        });
        _isGenerating = true;
      });
      _scrollToBottom();

      // Generate distinct real-data response without medical jargon
      final advice = await _generateAlertAdvice(
        alertId: alertId ?? 'custom_alert',
        alertType: alertType ?? 'general',
        alertTitle: alertTitle,
        alertSubtitle: alertSubtitle ?? '',
        health: health,
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _messages.add({
            'isUser': false,
            'text': advice,
          });
        });
        _scrollToBottom();
      }
    } else {
      setState(() {
        _messages.add({
          'isUser': false,
          'text': 'Hello! I am your Welloa Health Bot, your personal everyday health guide.\n\nBased on your live tracking today, you have walked ${health.steps} steps and logged ${sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)} hours of sleep' : 'ready for tonight\'s sleep'}.\n\nHow can I help you feel energized and healthy today?',
        });
      });
      _scrollToBottom();
    }
  }

  Future<String> _generateAlertAdvice({
    required String alertId,
    required String alertType,
    required String alertTitle,
    required String alertSubtitle,
    required HealthData health,
  }) async {
    _variationCounter++;
    final sleepHours = (health.sleepMinutes / 60).toStringAsFixed(1);
    final steps = health.steps;
    final calories = health.activeEnergy.toInt();

    final customPrompt = '''
You are the Welloa Health Bot, a friendly, encouraging personal health companion.
The user just tapped on this specific notification alert:
- Alert: "$alertTitle"
- Details: "$alertSubtitle"
- Type: $alertType

THE USER'S REAL HEALTH DATA TODAY:
- Daily Steps: $steps steps
- Sleep Logged: $sleepHours hours
- Active Energy Burned: $calories calories
- Health Tracker Status: ${health.isAuthorized ? 'Connected' : 'Needs Permission'}

CRITICAL INSTRUCTIONS:
1. USE SIMPLE, EVERYDAY WORDS ONLY.
   - ZERO medical jargon. NEVER use words like cortisol, circadian rhythm, methylation, latency, heart rate variability, SDNN, RMSSD, VO2 max, biomarkers, mitochondrial, or adrenal.
   - Use warm, friendly everyday words like "rest", "energy", "a short walk", "taking the stairs", "fresh water", "greens", "deep breaths".
2. MAKE YOUR RESPONSE COMPLETELY UNIQUE TO THIS SPECIFIC ALERT:
   - Provide a distinct, fresh tip that addresses this exact alert and the user's real numbers.
   - Do NOT give generic repetitive advice.
3. Keep it concise (2-3 short, clear sentences).
4. Give 1 or 2 easy, realistic things they can do right now.
''';

    try {
      final claudeService = ref.read(claudeServiceProvider);
      final response = await claudeService.chatWithAgent(
        history: [
          {
            'role': 'user',
            'content': 'Give me easy everyday advice for this alert: $alertTitle ($alertSubtitle). My live numbers: $steps steps, $sleepHours hours sleep, $calories cal burned.',
          }
        ],
        customSystemPrompt: customPrompt,
      );
      if (response.trim().isNotEmpty) {
        return response.trim();
      }
    } catch (_) {
      // Fallback to local intelligent dynamic generator using real data and zero jargon
    }

    return _generateDynamicLocalResponse(
      alertId: alertId,
      alertType: alertType,
      alertTitle: alertTitle,
      health: health,
      variation: _variationCounter,
    );
  }

  String _generateDynamicLocalResponse({
    required String alertId,
    required String alertType,
    required String alertTitle,
    required HealthData health,
    required int variation,
  }) {
    final sleepHours = health.sleepMinutes / 60;
    final steps = health.steps;
    final calories = health.activeEnergy.toInt();
    final lowerTitle = alertTitle.toLowerCase();

    // 1. SLEEP ALERTS
    if (alertType == 'sleep' || lowerTitle.contains('sleep') || lowerTitle.contains('rest')) {
      if (sleepHours > 0 && sleepHours < 6.0) {
        final options = [
          'Because you got ${sleepHours.toStringAsFixed(1)} hours of rest last night, your energy is a bit lower today. Try dimming your room lights 30 minutes before bed tonight and sipping warm herbal tea to help your body fall asleep easily.',
          'Operating on ${sleepHours.toStringAsFixed(1)} hours of sleep means your body needs extra care today. Drink plenty of fresh water, take a quick 10-minute afternoon pause, and plan on getting under the covers a little earlier tonight.',
          'Your ${sleepHours.toStringAsFixed(1)} hours of rest was on the lighter side. Putting away glowing phone screens 20 minutes before bedtime tonight will help your eyes relax and give you deeper, more refreshing sleep.',
        ];
        return options[variation % options.length];
      } else if (sleepHours >= 7.5) {
        final options = [
          'You got a wonderful ${sleepHours.toStringAsFixed(1)} hours of sleep last night! Your body had plenty of time to recharge and refresh. Use this high morning focus to tackle your biggest tasks early today.',
          'Fantastic rest last night with ${sleepHours.toStringAsFixed(1)} hours of sleep! Quality rest like that keeps your mood bright and your energy steady throughout the whole day.',
        ];
        return options[variation % options.length];
      } else if (sleepHours > 0) {
        final options = [
          'You logged a solid ${sleepHours.toStringAsFixed(1)} hours of rest last night. You are doing well! A gentle 5-minute morning stretch will help shake off any lingering stiffness and get you moving.',
          'With ${sleepHours.toStringAsFixed(1)} hours of sleep, your body is in a steady groove. Turning down bright overhead lights an hour before bed will help you drift off even faster tonight.',
        ];
        return options[variation % options.length];
      } else {
        return 'We don\'t have sleep logged for last night yet. Wearing your tracker or keeping your sleep app on tonight will let us show your exact sleep hours tomorrow morning!';
      }
    }

    // 2. STEPS & WALKING ALERTS
    if (alertType == 'steps' || lowerTitle.contains('step') || lowerTitle.contains('walk') || lowerTitle.contains('mov')) {
      if (steps == 0) {
        final options = [
          'You are at 0 steps so far today. Put on comfortable shoes and take a quick 5-minute stroll around your living space or outside to kickstart your day!',
          'A healthy day starts with the first few steps! Stepping outside for 5 minutes of fresh air will wake you up and start your counter.',
        ];
        return options[variation % options.length];
      } else if (steps < 4000) {
        final options = [
          'You have walked $steps steps today. You don\'t need a heavy workout—just a relaxed 10-minute stroll after your next meal will boost your energy and easily add 1,000 steps!',
          'You\'re at $steps steps so far. Taking the stairs instead of the elevator or pacing while taking a phone call is an effortless way to get moving.',
          'At $steps steps, your legs are ready for a quick refresh! A brisk 10-minute walk outside will blow away any tiredness and lift your mood.',
        ];
        return options[variation % options.length];
      } else if (steps >= 8000) {
        final options = [
          'Woohoo! You have already reached $steps steps today! That is fantastic for your heart and joints. Drink a nice glass of water to keep your muscles happy and relaxed.',
          'Outstanding effort reaching $steps steps! You have crushed your movement target for the day. Take a moment to sit back and relax—you\'ve earned it!',
        ];
        return options[variation % options.length];
      } else {
        final options = [
          'You\'re at $steps steps today, which is steady, great progress! A brief evening stroll around the block will easily push you past your 8,000 goal.',
          'Great movement with $steps steps so far. A quick walk after dinner will help your food digest smoothly and get you closer to your milestone.',
        ];
        return options[variation % options.length];
      }
    }

    // 3. ACTIVE ENERGY ALERTS
    if (alertType == 'energy' || lowerTitle.contains('energy') || lowerTitle.contains('calorie') || lowerTitle.contains('stretch')) {
      if (calories == 0) {
        return 'No active calories burned yet today. Stand up right now, roll your shoulders back 5 times, and stretch your arms up high toward the ceiling to wake up your body!';
      } else if (calories < 250) {
        final options = [
          'You\'ve burned $calories active calories through movement today. Standing up and stretching for just 3 minutes will wake up your body and clear any afternoon fatigue.',
          'At $calories active calories burned, your body is ready for a quick stretch break. Try 10 gentle body squats or a brisk walk down the hallway to get your energy buzzing!',
        ];
        return options[variation % options.length];
      } else {
        final options = [
          'You\'ve burned $calories active calories through movement today! That kind of daily activity keeps your body strong and your stamina high. Keep up the awesome rhythm!',
          'High energy day! Burning $calories calories through movement means your body is staying active. Drink plenty of fresh water to replenish yourself.',
        ];
        return options[variation % options.length];
      }
    }

    // 4. HYDRATION & NOURISHMENT ALERTS
    if (alertType == 'hydration' || lowerTitle.contains('water') || lowerTitle.contains('hydrat') || lowerTitle.contains('fuel') || lowerTitle.contains('nourish')) {
      final hour = DateTime.now().hour;
      if (hour < 12) {
        return 'Drinking a tall glass of cool water right now will sharpen your concentration, wake up your stomach, and help your body digest breakfast smoothly.';
      } else if (hour < 17) {
        return 'Midday recharge: Drink a glass of water and enjoy a fresh snack like an apple, berries, or a handful of nuts to beat the afternoon slump without any crash.';
      } else {
        return 'For your evening meal, aim for fresh vegetables and a warm herbal tea or water. It will help your body settle down so you sleep peacefully tonight.';
      }
    }

    // 5. SYNC ALERT
    if (alertType == 'sync' || lowerTitle.contains('sync') || lowerTitle.contains('tracker')) {
      return 'Connecting your health tracker lets Welloa read your live steps and sleep straight from your phone so every alert gives you exact real-time advice.';
    }

    // 6. DEFAULT DISTINCT CONVERSATIONAL RESPONSE
    return 'Based on your real numbers today ($steps steps and ${sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)} hours of rest' : 'ready for tonight\'s sleep'}), small daily habits like a brisk 10-minute walk, drinking water, and an early bedtime make the biggest difference!';
  }

  void _sendMessage([String? textToSend]) async {
    final query = textToSend ?? _controller.text.trim();
    if (query.isEmpty) return;

    final canUse = await ref.read(aiTrialProvider).canUseAIFeature(context, featureKey: 'ai_chat');
    if (!canUse) return;

    if (textToSend == null) {
      _controller.clear();
    }

    setState(() {
      _messages.add({'isUser': true, 'text': query});
      _isGenerating = true;
    });
    _scrollToBottom();

    final health = ref.read(healthDataProvider).valueOrNull ?? HealthData();
    final sleepHours = (health.sleepMinutes / 60).toStringAsFixed(1);

    final customPrompt = '''
You are the Welloa Health Bot, a warm, caring personal health companion.
The user is chatting with you.

USER'S REAL HEALTH NUMBERS TODAY:
- Daily Steps: ${health.steps}
- Sleep Logged: $sleepHours hours
- Active Energy: ${health.activeEnergy.toInt()} kcal

STRICT RULES:
1. USE SIMPLE, EVERYDAY WORDS ONLY.
   - Strictly NO medical jargon (no cortisol, methylation, circadian, latency, heart rate variability, SDNN, VO2 max, biomarkers).
   - Use friendly everyday words like "rest", "energy", "walk", "fresh food", "water", "deep breaths".
2. Directly answer the user's question using their real numbers where helpful.
3. Keep it brief and easy to understand (2-3 short sentences).
4. Be supportive, friendly, and practical.
''';

    try {
      final claudeService = ref.read(claudeServiceProvider);
      final history = _messages.map((m) {
        return {
          'role': m['isUser'] == true ? 'user' : 'assistant',
          'content': m['text'] as String,
        };
      }).toList();

      final response = await claudeService.chatWithAgent(
        history: history,
        customSystemPrompt: customPrompt,
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _messages.add({'isUser': false, 'text': response.trim()});
        });
        _scrollToBottom();
      }
      return;
    } catch (_) {
      // Fallback
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      final reply = _generateTailoredUserReply(query, health);
      setState(() {
        _isGenerating = false;
        _messages.add({'isUser': false, 'text': reply});
      });
      _scrollToBottom();
    }
  }

  String _generateTailoredUserReply(String query, HealthData health) {
    final lower = query.toLowerCase();
    final sleepHours = health.sleepMinutes / 60;

    if (lower.contains('sleep') || lower.contains('tired') || lower.contains('bed') || lower.contains('insomnia')) {
      return "To sleep better tonight, dim your room lights 30 minutes before bed and avoid bright phone screens. Since you logged ${sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)} hours of' : 'ready for'} rest, turning in 20 minutes earlier will help you wake up feeling completely refreshed.";
    }

    if (lower.contains('step') || lower.contains('walk') || lower.contains('exercise') || lower.contains('run')) {
      return "You are currently at ${health.steps} steps today. A great simple tip is to take a relaxed 10-minute walk after lunch or dinner. It helps digest your food smoothly and feels completely effortless!";
    }

    if (lower.contains('food') || lower.contains('eat') || lower.contains('snack') || lower.contains('diet')) {
      return "Keep it simple and colorful! Fill your plate with fresh greens, vegetables, and good proteins like eggs, beans, or fish, and drink plenty of water. You will feel full of natural energy all afternoon.";
    }

    if (lower.contains('stress') || lower.contains('anxious') || lower.contains('calm') || lower.contains('relax')) {
      return "When you feel stressed, take three slow deep breaths: breathe in through your nose for 4 seconds, and blow gently out through your mouth for 6 seconds. Doing that immediately quiets your body and clears your mind.";
    }

    if (lower.contains('water') || lower.contains('drink') || lower.contains('hydrate') || lower.contains('thirst')) {
      return "Staying hydrated gives you clear skin and keeps your brain sharp. Try drinking a glass of water right now and taking a sip every 20 minutes while you work.";
    }

    return "Based on your real numbers (${health.steps} steps and ${sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)} hours of rest' : 'ready for tonight'}), focusing on a brisk walk, fresh greens, and good hydration will give you the fastest boost. What would you like to explore next?";
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(healthDataProvider).valueOrNull ?? HealthData();
    final sleepHours = (health.sleepMinutes / 60).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.purpleAccent,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welloa Health Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(
                  '${health.steps} steps • ${sleepHours}h sleep',
                  style: const TextStyle(fontSize: 11, color: Colors.cyanAccent),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          // Live stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF162032),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(Icons.directions_walk, '${health.steps}', 'Steps', Colors.orangeAccent),
                _buildMiniStat(Icons.bedtime, '${sleepHours}h', 'Sleep', Colors.cyanAccent),
                _buildMiniStat(Icons.local_fire_department, '${health.activeEnergy.toInt()}', 'Calories', Colors.tealAccent),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isGenerating ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isGenerating) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Welloa Bot is thinking...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.cyanAccent.withValues(alpha: 0.18) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                      ),
                      border: Border.all(
                        color: isUser ? Colors.cyanAccent.withValues(alpha: 0.8) : Colors.purpleAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      msg['text'] as String,
                      style: TextStyle(
                        color: isUser ? Colors.cyanAccent : Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Suggested prompt chips
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildQuickChip('🌙 Improve my sleep'),
                _buildQuickChip('🚶 How to reach my steps'),
                _buildQuickChip('🥗 Easy healthy foods'),
                _buildQuickChip('⚡ Quick energy boost'),
              ],
            ),
          ),
          // Text input bar
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ask in everyday words...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.purpleAccent,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: TextStyle(color: Colors.grey[300], fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Colors.white12),
        label: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        onPressed: () => _sendMessage(text),
      ),
    );
  }
}
