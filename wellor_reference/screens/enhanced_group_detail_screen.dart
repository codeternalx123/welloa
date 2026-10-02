import 'package:flutter/material.dart';
import '../models/enhanced_health_group.dart';

/// Minimal placeholder detail screen for enhanced groups.
class EnhancedGroupDetailScreen extends StatelessWidget {
  final EnhancedHealthGroup group;

  const EnhancedGroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(group.description),
      ),
    );
  }
}
