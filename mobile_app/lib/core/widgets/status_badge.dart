import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';

/// Soft pill status chip — color communicates state only, never used for actions.
///
/// Labels come from the `status_*` translation keys, so the badge follows the
/// selected language. It previously hardcoded a French-only map, which left the
/// Arabic and English UIs showing French text.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    // `tr` falls back to the raw key, so an unknown status degrades to the code
    // itself rather than an empty chip.
    final label = tr(context, 'status_$status');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label == 'status_$status' ? status : label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
