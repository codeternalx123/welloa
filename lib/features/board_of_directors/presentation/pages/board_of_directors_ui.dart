import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/models/agent_persona.dart';

// Riverpod Provider for the Debate Engine
final debateEngineProvider = Provider((ref) {
  return ref.watch(aiDebateEngineProvider); // Need to add to injection_container
});

class BoardOfDirectorsPage extends ConsumerStatefulWidget {
  const BoardOfDirectorsPage({super.key});

  @override
  ConsumerState<BoardOfDirectorsPage> createState() => _BoardOfDirectorsPageState();
}

class _BoardOfDirectorsPageState extends ConsumerState<BoardOfDirectorsPage> {
  final List<DebateMessage> _messages = [];
  bool _isDebating = false;
  DailyVerdict? _finalVerdict;

  void _startDebate() async {
    setState(() {
      _messages.clear();
      _isDebating = true;
      _finalVerdict = null;
    });

    final engine = ref.read(debateEngineProvider);
    
    // Mock telemetry for the debate prompt
    final mockTelemetry = 'HRV: 45ms (Low), Sleep: 5 hours (Poor), Next Workout: Heavy Squats';

    await for (final msg in engine.conductDebate(mockTelemetry)) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
      }
    }

    if (mounted) {
      final verdict = await engine.synthesizeVerdict(_messages);
      setState(() {
        _finalVerdict = verdict;
        _isDebating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Board of Directors', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _isDebating ? null : _startDebate,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          if (_isDebating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(color: Colors.cyanAccent),
            ),
          if (_finalVerdict != null)
            _buildVerdictCard(_finalVerdict!),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DebateMessage msg) {
    Color agentColor;
    if (msg.speaker.id == 'agent_sleep') agentColor = Colors.indigoAccent;
    else if (msg.speaker.id == 'agent_nutrition') agentColor = Colors.greenAccent;
    else agentColor = Colors.deepOrangeAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: agentColor.withOpacity(0.2),
                child: Icon(Icons.psychology, color: agentColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                '\${msg.speaker.name} • \${msg.speaker.specialty}',
                style: TextStyle(color: agentColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: agentColor.withOpacity(0.3)),
            ),
            child: Text(
              msg.content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictCard(DailyVerdict verdict) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Chairman's Verdict",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(verdict.summary, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ...verdict.actionItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: const TextStyle(color: Colors.white))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
