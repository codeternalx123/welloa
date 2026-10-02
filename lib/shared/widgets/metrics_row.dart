import 'package:flutter/material.dart';

class MetricItem {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? trend;

  const MetricItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.trend,
  });
}

class MetricsRow extends StatelessWidget {
  final List<MetricItem> items;

  const MetricsRow({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.value,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.unit,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (item.trend != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        item.trend == 'up'
                            ? Icons.arrow_upward
                            : item.trend == 'down'
                                ? Icons.arrow_downward
                                : Icons.remove,
                        color: item.color,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
