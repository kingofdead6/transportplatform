import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Dense control-room stat card used across the admin dashboard/reports tabs.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.color = AppColors.bitume});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E6E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ArchivoCondensed',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.acier, fontSize: 12)),
        ],
      ),
    );
  }
}
