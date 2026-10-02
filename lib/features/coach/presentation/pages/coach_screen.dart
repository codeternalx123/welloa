import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../providers/coach_provider.dart';
import '../../../../shared/widgets/claude_thinking_indicator.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _ageController.text = profile.age.toString();
    _weightController.text = profile.weight.toString();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _getAdvice() {
    final age = int.tryParse(_ageController.text) ?? 30;
    final weight = double.tryParse(_weightController.text) ?? 70.0;
    
    // Update global profile
    ref.read(profileProvider.notifier).updateAge(age);
    ref.read(profileProvider.notifier).updateWeight(weight);
    
    // Fetch advice
    ref.read(coachNotifierProvider.notifier).getAdvice(age, weight);
  }

  @override
  Widget build(BuildContext context) {
    final coachState = ref.watch(coachNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Habit Coach', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Your Biological Blueprint', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _getAdvice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.hub),
              label: const Text('Generate Adherence Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            coachState.when(
              loading: () => const ClaudeThinkingIndicator(message: 'Generating your custom plan...'),
              error: (err, stack) => Center(
                child: Text('Failed to get advice: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (advice) {
                if (advice == null) {
                  return const Center(
                    child: Text('Tap the button above to get your personalized plan.', style: TextStyle(color: Colors.grey)),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAdviceCard(
                      title: 'Exercise Plan',
                      advice: advice.exerciseAdvice,
                      icon: Icons.fitness_center,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 16),
                    _buildAdviceCard(
                      title: 'Nutrition Plan',
                      advice: advice.foodAdvice,
                      icon: Icons.restaurant,
                      color: Colors.greenAccent,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdviceCard({required String title, required String advice, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(advice, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
