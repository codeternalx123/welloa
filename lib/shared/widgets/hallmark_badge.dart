import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum BadgeSize { small, medium, large }

class HallmarkBadge extends StatelessWidget {
  final String hallmarkName;
  final double impactScore;
  final BadgeSize size;

  const HallmarkBadge({
    Key? key,
    required this.hallmarkName,
    required this.impactScore,
    this.size = BadgeSize.medium,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = AppColors.hallmarkColors[hallmarkName] ?? Colors.grey;
    IconData iconData = Icons.remove;
    Color iconColor = Colors.grey;

    if (impactScore > 0.3) {
      iconData = Icons.arrow_upward;
      iconColor = Colors.green;
    } else if (impactScore < -0.3) {
      iconData = Icons.arrow_downward;
      iconColor = Colors.red;
    }

    double fontSize = 11;
    double padding = 6;
    if (size == BadgeSize.small) {
      fontSize = 9;
      padding = 4;
    } else if (size == BadgeSize.large) {
      fontSize = 13;
      padding = 8;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding * 1.5, vertical: padding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: fontSize + 4, color: iconColor),
          const SizedBox(width: 4),
          Text(
            hallmarkName,
            style: TextStyle(fontSize: fontSize, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
