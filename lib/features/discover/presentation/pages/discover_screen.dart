import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/ai_trial_provider.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCategoryHeader('AI & Simulations'),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Future Self Simulator',
            description: 'See how your habits today affect your future appearance.',
            icon: Icons.face,
            color: Colors.blueAccent,
            route: '/discover/bio-twin',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Why It Matters',
            description: 'Discover the hidden links between your choices and your health.',
            icon: Icons.auto_awesome,
            color: Colors.purpleAccent,
            route: '/discover/causal',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Aging Clock',
            description: 'Track how all your biological systems are aging together.',
            icon: Icons.access_time,
            color: Colors.orangeAccent,
            route: '/discover/aeg',
          ),
          const SizedBox(height: 24),
          _buildCategoryHeader('My Biology'),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'My DNA Insights',
            description: 'Simple insights into what foods match your genetics.',
            icon: Icons.biotech,
            color: Colors.tealAccent,
            route: '/discover/dna',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Gut Health',
            description: 'Your microbiome score and personalized tips.',
            icon: Icons.eco,
            color: Colors.greenAccent,
            route: '/discover/gut',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Blood & Hormones',
            description: 'A clean gauge of your hormonal balance.',
            icon: Icons.water_drop,
            color: Colors.redAccent,
            route: '/discover/blood',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Aging Speedometer',
            description: 'Are you aging faster or slower than normal?',
            icon: Icons.speed,
            color: Colors.yellowAccent,
            route: '/discover/speedometer',
          ),
          const SizedBox(height: 24),
          _buildCategoryHeader('My Environment'),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Health Circle',
            description: 'See how your friends affect your habits.',
            icon: Icons.group,
            color: Colors.indigoAccent,
            route: '/discover/circle',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Wearable Telemetry',
            description: 'Live biometric streaming status.',
            icon: Icons.watch,
            color: Colors.cyanAccent,
            route: '/discover/wearables',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Bio-Arbitrage',
            description: 'Optimize your health spend ROI.',
            icon: Icons.attach_money,
            color: Colors.pinkAccent,
            route: '/discover/arbitrage',
          ),
          _buildFeatureCard(
            context: context,
            ref: ref,
            title: 'Gene-Diet Fit',
            description: 'Precision nutrition based on your alleles.',
            icon: Icons.science,
            color: Colors.purpleAccent,
            route: '/discover/nutrigenomics',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1F2937),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push(route);
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
