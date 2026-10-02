import 'package:flutter/material.dart';
import '../../domain/models/tribe_member.dart';

class TribeLeaderboardPage extends StatelessWidget {
  const TribeLeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data to demonstrate the UI
    final List<TribeMember> mockLeaderboard = [
      const TribeMember(
        userId: '1',
        displayName: 'Bryan J.',
        avatarUrl: '',
        currentBioAge: 37.5,
        currentChronoAge: 46.0,
        paceOfAging: 0.69,
        streakDays: 450,
      ),
      const TribeMember(
        userId: '2',
        displayName: 'Dr. Rhonda',
        avatarUrl: '',
        currentBioAge: 35.0,
        currentChronoAge: 40.0,
        paceOfAging: 0.72,
        streakDays: 312,
      ),
      const TribeMember(
        userId: '3',
        displayName: 'David S.',
        avatarUrl: '',
        currentBioAge: 42.1,
        currentChronoAge: 55.0,
        paceOfAging: 0.75,
        streakDays: 800,
      ),
      const TribeMember(
        userId: '4',
        displayName: 'You',
        avatarUrl: '',
        currentBioAge: 28.5,
        currentChronoAge: 30.0,
        paceOfAging: 0.88,
        streakDays: 45,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Global Age Reversal League', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockLeaderboard.length,
        itemBuilder: (context, index) {
          final member = mockLeaderboard[index];
          final rank = index + 1;
          return _buildLeaderboardTile(member, rank);
        },
      ),
    );
  }

  Widget _buildLeaderboardTile(TribeMember member, int rank) {
    final isMe = member.displayName == 'You';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isMe ? const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)]) : null,
        color: isMe ? null : Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? Colors.blue.withOpacity(0.5) : Colors.white12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '\$rank.',
              style: TextStyle(
                color: rank <= 3 ? Colors.amber : Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: Colors.grey.shade800,
            child: Text(member.displayName[0], style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bio Age: \${member.currentBioAge.toStringAsFixed(1)} (- \${(member.currentChronoAge - member.currentBioAge).toStringAsFixed(1)} yrs)',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\${member.paceOfAging.toStringAsFixed(2)} PACE',
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 14),
                  const SizedBox(width: 4),
                  Text('\${member.streakDays}d', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
