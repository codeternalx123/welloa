import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/health_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/claude_service.dart';

class GamifiedAICoachWidget extends ConsumerStatefulWidget {
  final String domainContext;

  const GamifiedAICoachWidget({
    Key? key,
    required this.domainContext,
  }) : super(key: key);

  @override
  ConsumerState<GamifiedAICoachWidget> createState() => _GamifiedAICoachWidgetState();
}

class _GamifiedAICoachWidgetState extends ConsumerState<GamifiedAICoachWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content': 'Welcome to the ${widget.domainContext} module! I am your AI Habit Coach. How can we optimize your longevity today?',
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Fetch Health Data Context
    final healthState = ref.read(healthDataProvider);
    String healthContext = '';
    healthState.whenData((data) {
      if (data.isAuthorized) {
        healthContext = 'User Health Connect Data:\\nSteps: ${data.steps}\\nActive Energy: ${data.activeEnergy.toStringAsFixed(0)} kcal\\nSleep: ${(data.sleepMinutes / 60).toStringAsFixed(1)} hours.';
      } else {
        healthContext = 'User Health Connect Data: Not authorized or unavailable.';
      }
    });

    final promptContext = '''
You are a gamified, dopamine-architect AI health coach in the Welloa app. 
You are currently helping the user in the "${widget.domainContext}" module.
$healthContext
Keep your responses short, punchy, and gamified. Frame health as an exciting mission.
''';

    try {
      final response = await ClaudeService.generateResponse(
        prompt: '$promptContext\\nUser says: $text',
      );
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Oops, I encountered a glitch in the matrix: $e'});
        _isLoading = false;
      });
      _scrollToBottom();
    }
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

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final isLocked = profile.tier == SubscriptionTier.freemium;

    return Container(
      height: 400,
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: isLocked ? Colors.amberAccent.withOpacity(0.05) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isLocked ? Colors.amberAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
      ),
      child: isLocked 
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.amberAccent),
              const SizedBox(height: 16),
              const Text('AI Coach Locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('Upgrade your Biological Blueprint to Premium or Ultra on the Home screen to unlock real-time hormetic optimization.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              ),
            ],
          )
        : Column(
            children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.cyanAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Habit Coach (${widget.domainContext})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.pinkAccent.withOpacity(0.2) : Colors.cyanAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser ? Colors.pinkAccent.withOpacity(0.5) : Colors.cyanAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(
                        color: isUser ? Colors.pinkAccent : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Colors.cyanAccent),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask your coach...',
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
