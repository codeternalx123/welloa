import 'package:flutter/material.dart';

class GenomicsDashboardScreen extends StatelessWidget {
  const GenomicsDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Genomics & DNA Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGenomicCard(
              title: '3B Base Pair Sequence',
              subtitle: 'Whole Genome Sequencing (30x coverage)',
              status: 'Aligned & Indexed',
              color: Colors.blue,
              icon: Icons.biotech,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildGenomicCard(title: 'Methylation', subtitle: '850k CpG Sites', status: 'Active', color: Colors.green, icon: Icons.grass)),
                const SizedBox(width: 16),
                Expanded(child: _buildGenomicCard(title: 'Telomere', subtitle: 'Length Assay', status: 'Critical', color: Colors.red, icon: Icons.timer)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('CYP450 Enzyme Pathways', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildEnzymeRow('CYP1A2', 'Rapid', Colors.cyan),
            _buildEnzymeRow('CYP3A4', 'Poor', Colors.amber),
            _buildEnzymeRow('COMT', 'Slow', Colors.amber),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple)),
              child: Column(
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.purple, size: 32),
                  SizedBox(height: 8),
                  Text('Polygenic Risk Score Synthesis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Cross-referencing 1.2M SNPs against clinical databases...', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenomicCard({required String title, required String subtitle, required String status, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEnzymeRow(String enzyme, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1F2937))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(enzyme, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('$status Metabolizer', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
