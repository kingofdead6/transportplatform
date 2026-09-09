import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Section 11.7: empty screens name the action to take, never just "nothing here".
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.local_shipping_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.acier),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.acier, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
