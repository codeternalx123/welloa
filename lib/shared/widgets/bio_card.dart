import 'package:flutter/material.dart';

class BioCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;

  const BioCard({
    Key? key,
    required this.title,
    this.subtitle,
    required this.child,
    this.accentColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFF00F5FF);
    Widget card = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(width: 3, color: color),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.bold,
              color: Color(0xFFF9FAFB),
              fontSize: 15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
