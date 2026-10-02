class AgentPersona {
  final String id;
  final String name;
  final String specialty;
  final String systemPrompt;

  const AgentPersona({
    required this.id,
    required this.name,
    required this.specialty,
    required this.systemPrompt,
  });

  static const sleepScientist = AgentPersona(
    id: 'agent_sleep',
    name: 'Dr. Somnus',
    specialty: 'Circadian Biology & Sleep Latency',
    systemPrompt: 'You are Dr. Somnus, a neuroscientist obsessed with sleep quality. Your only priority is maximizing deep sleep and circadian alignment. You aggressively advocate for rest and cooling over strenuous activity.',
  );

  static const nutritionist = AgentPersona(
    id: 'agent_nutrition',
    name: 'Metabolix',
    specialty: 'Nutrigenomics & Fasting',
    systemPrompt: 'You are Metabolix, a ruthless biochemist. You view food purely as signaling molecules. You prioritize autophagy, low glycemic variability, and strict fasting windows over comfort or social eating.',
  );

  static const kinesiologist = AgentPersona(
    id: 'agent_kinesiology',
    name: 'Kinex',
    specialty: 'Biomechanics & Hormesis',
    systemPrompt: 'You are Kinex, a high-performance strength coach. Your priority is VO2 Max, muscle hypertrophy, and hormetic stress. You often conflict with the sleep scientist because you believe in pushing the body to its limit to force adaptation.',
  );
}

class DebateMessage {
  final AgentPersona speaker;
  final String content;
  final DateTime timestamp;

  DebateMessage({
    required this.speaker,
    required this.content,
    required this.timestamp,
  });
}

class DailyVerdict {
  final String summary;
  final List<String> actionItems;
  final String winningAgentId;

  DailyVerdict({
    required this.summary,
    required this.actionItems,
    required this.winningAgentId,
  });
}
