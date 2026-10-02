import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/dna_provider.dart';

class ManualDnaInputScreen extends ConsumerStatefulWidget {
  const ManualDnaInputScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManualDnaInputScreen> createState() => _ManualDnaInputScreenState();
}

class _ManualDnaInputScreenState extends ConsumerState<ManualDnaInputScreen> {
  late String mthfr;
  late String actn3;
  late String apoe4;
  late String fto;

  @override
  void initState() {
    super.initState();
    final currentData = ref.read(dnaDataProvider);
    mthfr = currentData.mthfr;
    actn3 = currentData.actn3;
    apoe4 = currentData.apoe4;
    fto = currentData.fto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Your DNA', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'Select Your Genetic Variants',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Welloa AI Engine will instantly restructure your gamified advice based on these markers.',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),
            
            _buildDropdown(
              'Methylation (MTHFR)',
              mthfr,
              ['Impaired', 'Normal'],
              (val) => setState(() => mthfr = val!),
            ),
            const SizedBox(height: 24),
            
            _buildDropdown(
              'Muscle Fiber (ACTN3)',
              actn3,
              ['Sprinter', 'Endurance', 'Mixed'],
              (val) => setState(() => actn3 = val!),
            ),
            const SizedBox(height: 24),
            
            _buildDropdown(
              'Fat Metabolism (APOE4)',
              apoe4,
              ['Variant Found', 'Not Found'],
              (val) => setState(() => apoe4 = val!),
            ),
            const SizedBox(height: 24),
            
            _buildDropdown(
              'Fasting Response (FTO)',
              fto,
              ['High Responder', 'Normal'],
              (val) => setState(() => fto = val!),
            ),
            
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                ref.read(dnaDataProvider.notifier).updateDnaData(mthfr, actn3, apoe4, fto);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save & Analyze', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
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
