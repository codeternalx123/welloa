import 'package:flutter/material.dart';

class EnterpriseDashboard extends StatelessWidget {
  final double enterpriseValue;

  const EnterpriseDashboard({Key? key, required this.enterpriseValue}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildB2BCard('Employer Longevity ROI', 'Estimated healthcare savings', '\$1,240', Colors.green),
            const SizedBox(width: 12),
            _buildB2BCard('Insurer Premium Red.', 'Actuarial risk reduction', '-18.5%', Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Longevity Credit Market', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Text('LC/USD', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      SizedBox(width: 8),
                      Text('\$81.43', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_drop_up, color: Colors.green),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Portfolio Value', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('\$${enterpriseValue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildHookChip('Tokenized PoRC (Coming Soon)'),
            const SizedBox(width: 8),
            _buildHookChip('DeFi Longevity Bonds (Q4)'),
          ],
        ),
      ],
    );
  }

  Widget _buildB2BCard(String title, String sub, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildHookChip(String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
