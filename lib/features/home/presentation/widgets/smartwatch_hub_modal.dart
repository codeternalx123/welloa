import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/unicorn_glass_card.dart';
import '../../../../core/providers/health_provider.dart';

class SmartwatchHubModal extends ConsumerWidget {
  const SmartwatchHubModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Smartwatch Integration',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Welloa uses Health Connect as a central hub. Ensure your wearable\'s companion app is installed and synced with Health Connect.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildBrandChip('Apple Watch', Icons.apple),
              _buildBrandChip('Garmin', Icons.watch),
              _buildBrandChip('Fitbit', Icons.watch_later),
              _buildBrandChip('Samsung Galaxy', Icons.watch_sharp),
              _buildBrandChip('Oura Ring', Icons.circle_outlined),
            ],
          ),
          const SizedBox(height: 32),
          UnicornGlassCard(
            glowColor: Colors.indigoAccent,
            padding: const EdgeInsets.all(20),
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigoAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    ref.read(healthDataProvider.notifier).syncHealthData();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.sync, color: Colors.white),
                  label: const Text('Connect via Health Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    ref.read(healthServiceProvider).installHealthConnect();
                  },
                  icon: const Icon(Icons.download, color: Colors.cyanAccent),
                  label: const Text('Download Health Connect', style: TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBrandChip(String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
