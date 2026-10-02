import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/sleep_provider.dart';

class ManualSleepInputScreen extends ConsumerStatefulWidget {
  const ManualSleepInputScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManualSleepInputScreen> createState() => _ManualSleepInputScreenState();
}

class _ManualSleepInputScreenState extends ConsumerState<ManualSleepInputScreen> {
  late String totalSleep;
  late String remDensity;
  late String deepSleepLatency;

  @override
  void initState() {
    super.initState();
    final currentData = ref.read(sleepDataProvider);
    totalSleep = currentData.totalSleep;
    remDensity = currentData.remDensity;
    deepSleepLatency = currentData.deepSleepLatency;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Your Sleep Data', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'Select Your Sleep Metrics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Welloa AI Engine will optimize its longevity recommendations based on these markers.',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),
            
            _buildDropdown(
              'Total Sleep Duration',
              totalSleep,
              ['Under 6 Hours', '6-7 Hours', '7-8 Hours', '8+ Hours'],
              (val) => setState(() => totalSleep = val!),
            ),
            const SizedBox(height: 24),
            
            _buildDropdown(
              'REM Density',
              remDensity,
              ['Low', 'Normal', 'High'],
              (val) => setState(() => remDensity = val!),
            ),
            const SizedBox(height: 24),
            
            _buildDropdown(
              'Deep Sleep Latency',
              deepSleepLatency,
              ['Delayed', 'Normal', 'Fast'],
              (val) => setState(() => deepSleepLatency = val!),
            ),
            
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                ref.read(sleepDataProvider.notifier).updateSleepData(remDensity, deepSleepLatency, totalSleep);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save & Optimize Longevity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1F2937),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
