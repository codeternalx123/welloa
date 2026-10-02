import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/section_header.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welloa', style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: const Text(
                      'For informational and educational purposes only. This app is not intended to diagnose, treat, cure, or prevent any disease. Always consult your physician before making health decisions.',
                      style: TextStyle(color: Colors.amber, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF00F5FF).withOpacity(0.2), const Color(0xFF1F2937)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('BIOLOGICAL AGE', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: const [
                      Text('33.2', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('yrs', style: TextStyle(color: Colors.grey, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Chronological: 38.5  |  Reversal Rate: 8.4 mo/yr', style: TextStyle(color: Colors.cyan, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatTile('Readiness', '44', 'Low', Colors.red),
                const SizedBox(width: 12),
                _buildStatTile('Network', '72.4', 'Stable', Colors.amber),
                const SizedBox(width: 12),
                _buildStatTile('Age Gap', '-5.3', 'Better', Colors.green),
              ],
            ),
            const SectionHeader(title: 'Active Engines'),
            
            
            _buildEngineCard(
              context: context,
              title: 'Genomics Analysis',
              subtitle: 'Whole Genome & Methylation',
              icon: Icons.biotech,
              route: '/genomics',
              color: Colors.blue,
            ),
_buildEngineCard(
              context: context,
              title: 'Epigenomic Diffing Engine',
              subtitle: 'DNA Methylation & DunedinPACE tracking',
              icon: Icons.biotech_outlined,
              route: '/epigenomic-diff',
              color: Colors.teal,
            ),
_buildEngineCard(
              context: context,
              title: 'Phytochemical Scanner',
              subtitle: 'Vision API → Pigment/Hallmark Mapping',
              icon: Icons.camera_alt,
              route: '/food-scan',
              color: Colors.cyan,
            ),
            _buildEngineCard(
              context: context,
              title: 'Kinematic Routine Engine',
              subtitle: 'HRV/Sleep → Dynamic Workout Recompilation',
              icon: Icons.directions_run,
              route: '/kinematic',
              color: Colors.green,
            ),
            _buildEngineCard(
              context: context,
              title: 'Bio-Digital Twin Compiler',
              subtitle: 'Adversarial Inference → Biological Age',
              icon: Icons.biotech,
              route: '/bio-twin',
              color: Colors.purple,
            ),
            _buildEngineCard(
              context: context,
              title: 'Deterministic Causal Feedback',
              subtitle: 'do-calculus → Temporal Impact Analysis',
              icon: Icons.account_tree,
              route: '/causal',
              color: Colors.amber,
            ),
            _buildEngineCard(
              context: context,
              title: 'Cross-Node AEG Graph',
              subtitle: 'Systemic Network Synthesis',
              icon: Icons.hub,
              route: '/aeg-graph',
              color: Colors.blue,
            ),
            _buildEngineCard(
              context: context,
              title: 'Nutrigenomics Insights',
              subtitle: 'DNA-Tailored Phytochemical Routine',
              icon: Icons.medication,
              route: '/nutrigenomics',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(sub, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineCard({required BuildContext context, required String title, required String subtitle, required IconData icon, required String route, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          // Wrap in try-catch to avoid crashing if route not yet implemented
          try {
            context.go(route);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Route $route not yet built')));
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
