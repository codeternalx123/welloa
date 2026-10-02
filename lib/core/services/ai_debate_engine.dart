import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/board_of_directors/domain/models/agent_persona.dart';
import '../services/claude_service.dart';

class AiDebateEngine {
  final ClaudeService claudeService;

  AiDebateEngine({required this.claudeService});

  /// Orchestrates a multi-turn debate among the board of directors over user data
  Stream<DebateMessage> conductDebate(String dailyHealthSummary) async* {
    final board = [
      AgentPersona.nutritionist,
      AgentPersona.kinesiologist,
      AgentPersona.sleepScientist,
    ];

    List<String> transcript = [];

    // Turn 1: Each agent gives their initial take based on the raw data
    for (var agent in board) {
      final prompt = '''
Here is the user's health telemetry for today:
\$dailyHealthSummary

Based on your persona:
\${agent.systemPrompt}

Give a 2-sentence initial assessment of what the user MUST do today. Do not agree with others unless forced.
''';

      final response = await _callAgent(agent, prompt, transcript);
      transcript.add('\${agent.name}: \$response');
      yield DebateMessage(speaker: agent, content: response, timestamp: DateTime.now());
    }

    // Turn 2: Rebuttal (The Sleep Scientist usually rebukes the Kinesiologist, etc.)
    for (var agent in board) {
      final prompt = '''
The board has spoken:
\${transcript.join('\\n')}

Based on your persona:
\${agent.systemPrompt}

Rebut one of the other agents directly if their advice contradicts your specialty. Keep it under 3 sentences. Be sharp.
''';

      final response = await _callAgent(agent, prompt, transcript);
      transcript.add('\${agent.name}: \$response');
      yield DebateMessage(speaker: agent, content: response, timestamp: DateTime.now());
    }
  }

  /// Synthesizes the debate into a single JSON verdict
  Future<DailyVerdict> synthesizeVerdict(List<DebateMessage> debateHistory) async {
    final transcript = debateHistory.map((m) => '\${m.speaker.name}: \${m.content}').join('\\n');
    
    final prompt = '''
You are the Chairman of the Board. Synthesize this debate into a final verdict.
Debate Transcript:
\$transcript

Return EXACTLY valid JSON matching this schema:
{
  "summary": "String, 1-2 sentences",
  "actionItems": ["String", "String"],
  "winningAgentId": "agent_sleep | agent_nutrition | agent_kinesiology"
}
''';

    try {
      final resultStr = await claudeService.generateGuidance(
        prompt,
        'You are the Chairman AI. Return only valid JSON.',
      );
      
      final json = jsonDecode(resultStr);
      return DailyVerdict(
        summary: json['summary'] ?? 'Unable to synthesize.',
        actionItems: List<String>.from(json['actionItems'] ?? []),
        winningAgentId: json['winningAgentId'] ?? 'unknown',
      );
    } catch (e) {
      debugPrint('Debate Synthesis Error: \$e');
      return DailyVerdict(
        summary: 'The board could not reach a consensus today due to an error.',
        actionItems: ['Rest and try again tomorrow.'],
        winningAgentId: 'agent_sleep',
      );
    }
  }

  Future<String> _callAgent(AgentPersona agent, String prompt, List<String> transcriptContext) async {
    try {
      // In a real implementation, we would append the transcript context to the system prompt
      final response = await claudeService.generateGuidance(
        prompt,
        agent.systemPrompt,
      );
      return response;
    } catch (e) {
      return '*Sits in silence due to network error*';
    }
  }
}
